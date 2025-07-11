package batcher

import (
	"testing"

	"github.com/ethereum-AIHI/AIHI/op-e2e/actions/helpers"
	"github.com/stretchr/testify/require"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"

	batcherFlags "github.com/ethereum-AIHI/AIHI/op-batcher/flags"
	"github.com/ethereum-AIHI/AIHI/op-e2e/e2eutils"
	"github.com/ethereum-AIHI/AIHI/op-node/rollup/sync"
	"github.com/ethereum-AIHI/AIHI/op-service/testlog"
)

func setupEIP4844Test(t helpers.Testing, log log.Logger) (*e2eutils.SetupData, *e2eutils.DeployParams, *helpers.L1Miner, *helpers.L2Sequencer, *helpers.L2Engine, *helpers.L2Verifier, *helpers.L2Engine) {
	dp := e2eutils.MakeDeployParams(t, helpers.DefaultRollupTestParams())
	genesisActivation := hexutil.Uint64(0)
	dp.DeployConfig.L1CancunTimeOffset = &genesisActivation
	dp.DeployConfig.L2GenesisCanyonTimeOffset = &genesisActivation
	dp.DeployConfig.L2GenesisDeltaTimeOffset = &genesisActivation
	dp.DeployConfig.L2GenesisEcotoneTimeOffset = &genesisActivation

	sd := e2eutils.Setup(t, dp, helpers.DefaultAlloc)
	miner, seqEngine, sequencer := helpers.SetupSequencerTest(t, sd, log)
	miner.ActL1SetFeeRecipient(common.Address{'A'})
	sequencer.ActL2PipelineFull(t)
	verifEngine, verifier := helpers.SetupVerifier(t, sd, log, miner.L1Client(t, sd.RollupCfg), miner.BlobStore(), &sync.Config{})
	return sd, dp, miner, sequencer, seqEngine, verifier, verifEngine
}

func setupBatcher(t helpers.Testing, log log.Logger, sd *e2eutils.SetupData, dp *e2eutils.DeployParams, miner *helpers.L1Miner,
	sequencer *helpers.L2Sequencer, engine *helpers.L2Engine, daType batcherFlags.DataAvailabilityType,
) *helpers.L2Batcher {
	return helpers.NewL2Batcher(log, sd.RollupCfg, &helpers.BatcherCfg{
		MinL1TxSize:          0,
		MaxL1TxSize:          128_000,
		BatcherKey:           dp.Secrets.Batcher,
		DataAvailabilityType: daType,
	}, sequencer.RollupClient(), miner.EthClient(), engine.EthClient(), engine.EngineClient(t, sd.RollupCfg))
}

func TestEIP4844DataAvailability(gt *testing.T) {
	t := helpers.NewDefaultTesting(gt)

	log := testlog.Logger(t, log.LevelDebug)
	sd, dp, miner, sequencer, seqEngine, verifier, _ := setupEIP4844Test(t, log)

	batcher := setupBatcher(t, log, sd, dp, miner, sequencer, seqEngine, batcherFlags.BlobsType)

	sequencer.ActL2PipelineFull(t)
	verifier.ActL2PipelineFull(t)

	// build empty L1 block
	miner.ActEmptyBlock(t)
	// finalize it, so the L1 geth blob pool doesn't log errors about missing finality
	miner.ActL1SafeNext(t)
	miner.ActL1FinalizeNext(t)

	// Create L2 blocks, and reference the L1 head as origin
	sequencer.ActL1HeadSignal(t)
	sequencer.ActBuildToL1Head(t)

	// submit all new L2 blocks
	batcher.ActSubmitAll(t)
	batchTx := batcher.LastSubmitted
	require.Equal(t, uint8(types.BlobTxType), batchTx.Type(), "batch tx must be blob-tx")

	// new L1 block with L2 batch
	miner.ActL1StartBlock(12)(t)
	miner.ActL1IncludeTxByHash(batchTx.Hash())(t)
	miner.ActL1EndBlock(t)

	// verifier picks up the L2 chain that was submitted
	verifier.ActL1HeadSignal(t)
	verifier.ActL2PipelineFull(t)
	require.Equal(t, verifier.L2Safe(), sequencer.L2Unsafe(), "verifier syncs from sequencer via L1")
	require.NotEqual(t, sequencer.L2Safe(), sequencer.L2Unsafe(), "sequencer has not processed L1 yet")
}

func TestEIP4844MultiBlobs(gt *testing.T) {
	t := helpers.NewDefaultTesting(gt)
	// Feel free to bump to Prague when updating this test's L1 config to activate Prague

	log := testlog.Logger(t, log.LevelDebug)
	sd, dp, miner, sequencer, seqEngine, verifier, _ := setupEIP4844Test(t, log)
	// We could use eip4844.MaxBlobsPerBlock(sd.L1Cfg.Config, sd.L1Cfg.Timestamp) here, but
	// we don't have the L1 chain config available in the action test batcher. So we just
	// stick to Cancun max blobs for now, which is sufficient for this test.
	maxBlobsPerBlock := params.DefaultCancunBlobConfig.Max

	batcher := setupBatcher(t, log, sd, dp, miner, sequencer, seqEngine, batcherFlags.BlobsType)

	sequencer.ActL2PipelineFull(t)
	verifier.ActL2PipelineFull(t)

	// build empty L1 block
	miner.ActEmptyBlock(t)
	// finalize it, so the L1 geth blob pool doesn't log errors about missing finality
	miner.ActL1SafeNext(t)
	miner.ActL1FinalizeNext(t)

	// Create L2 blocks, and reference the L1 head as origin
	sequencer.ActL1HeadSignal(t)
	sequencer.ActBuildToL1Head(t)

	// submit all new L2 blocks
	batcher.ActSubmitAllMultiBlobs(t, maxBlobsPerBlock)
	batchTx := batcher.LastSubmitted
	require.Equal(t, uint8(types.BlobTxType), batchTx.Type(), "batch tx must be blob-tx")
	require.Len(t, batchTx.BlobTxSidecar().Blobs, maxBlobsPerBlock)

	// new L1 block with L2 batch
	miner.ActL1StartBlock(12)(t)
	miner.ActL1IncludeTxByHash(batchTx.Hash())(t)
	miner.ActL1EndBlock(t)

	// verifier picks up the L2 chain that was submitted
	verifier.ActL1HeadSignal(t)
	verifier.ActL2PipelineFull(t)
	require.Equal(t, verifier.L2Safe(), sequencer.L2Unsafe(), "verifier syncs from sequencer via L1")
	require.NotEqual(t, sequencer.L2Safe(), sequencer.L2Unsafe(), "sequencer has not processed L1 yet")
}

func TestEIP4844DataAvailabilitySwitch(gt *testing.T) {
	t := helpers.NewDefaultTesting(gt)

	log := testlog.Logger(t, log.LevelDebug)
	sd, dp, miner, sequencer, seqEngine, verifier, _ := setupEIP4844Test(t, log)

	oldBatcher := setupBatcher(t, log, sd, dp, miner, sequencer, seqEngine, batcherFlags.CalldataType)

	sequencer.ActL2PipelineFull(t)
	verifier.ActL2PipelineFull(t)

	// build empty L1 block
	miner.ActEmptyBlock(t)
	// finalize it, so the L1 geth blob pool doesn't log errors about missing finality
	miner.ActL1SafeNext(t)
	miner.ActL1FinalizeNext(t)

	// Create L2 blocks, and reference the L1 head as origin
	sequencer.ActL1HeadSignal(t)
	sequencer.ActBuildToL1Head(t)

	// submit all new L2 blocks, with legacy calldata DA
	oldBatcher.ActSubmitAll(t)
	batchTx := oldBatcher.LastSubmitted
	require.Equal(t, uint8(types.DynamicFeeTxType), batchTx.Type(), "batch tx must be eip1559 tx")

	// new L1 block with L2 batch
	miner.ActL1StartBlock(12)(t)
	miner.ActL1IncludeTxByHash(batchTx.Hash())(t)
	miner.ActL1EndBlock(t)

	// verifier picks up the L2 chain that was submitted
	verifier.ActL1HeadSignal(t)
	verifier.ActL2PipelineFull(t)
	require.Equal(t, verifier.L2Safe(), sequencer.L2Unsafe(), "verifier syncs from sequencer via L1")
	require.NotEqual(t, sequencer.L2Safe(), sequencer.L2Unsafe(), "sequencer has not processed L1 yet")

	newBatcher := setupBatcher(t, log, sd, dp, miner, sequencer, seqEngine, batcherFlags.BlobsType)

	// build empty L1 block
	miner.ActEmptyBlock(t)

	// Create L2 blocks, and reference the L1 head as origin
	sequencer.ActL1HeadSignal(t)
	sequencer.ActBuildToL1Head(t)

	// submit all new L2 blocks, now with Blobs DA!
	newBatcher.ActSubmitAll(t)
	batchTx = newBatcher.LastSubmitted

	// new L1 block with L2 batch
	miner.ActL1StartBlock(12)(t)
	miner.ActL1IncludeTxByHash(batchTx.Hash())(t)
	miner.ActL1EndBlock(t)

	require.Equal(t, uint8(types.BlobTxType), batchTx.Type(), "batch tx must be blob-tx")

	// verifier picks up the L2 chain that was submitted
	verifier.ActL1HeadSignal(t)
	verifier.ActL2PipelineFull(t)
	require.Equal(t, verifier.L2Safe(), sequencer.L2Unsafe(), "verifier syncs from sequencer via L1")
	require.NotEqual(t, sequencer.L2Safe(), sequencer.L2Unsafe(), "sequencer has not processed L1 yet")
}
