package faultproofs

import (
	"crypto/ecdsa"
	"testing"

	"github.com/ethereum-AIHI/AIHI/op-e2e/config"
	"github.com/ethereum-AIHI/AIHI/op-e2e/system/e2esys"
	"github.com/ethereum-AIHI/AIHI/op-e2e/system/helpers"

	batcherFlags "github.com/ethereum-AIHI/AIHI/op-batcher/flags"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/stretchr/testify/require"
)

type faultDisputeConfig struct {
	sysOpts      []e2esys.SystemConfigOpt
	cfgModifiers []func(cfg *e2esys.SystemConfig)
}

type faultDisputeConfigOpts func(cfg *faultDisputeConfig)

func WithBatcherStopped() faultDisputeConfigOpts {
	return func(fdc *faultDisputeConfig) {
		fdc.cfgModifiers = append(fdc.cfgModifiers, func(cfg *e2esys.SystemConfig) {
			cfg.DisableBatcher = true
		})
	}
}

func WithBlobBatches() faultDisputeConfigOpts {
	return func(fdc *faultDisputeConfig) {
		fdc.cfgModifiers = append(fdc.cfgModifiers, func(cfg *e2esys.SystemConfig) {
			cfg.DataAvailabilityType = batcherFlags.BlobsType

			genesisActivation := hexutil.Uint64(0)
			cfg.DeployConfig.L1CancunTimeOffset = &genesisActivation
			cfg.DeployConfig.L2GenesisDeltaTimeOffset = &genesisActivation
			cfg.DeployConfig.L2GenesisEcotoneTimeOffset = &genesisActivation
		})
	}
}

func WithLatestFork() faultDisputeConfigOpts {
	return func(fdc *faultDisputeConfig) {
		fdc.cfgModifiers = append(fdc.cfgModifiers, func(cfg *e2esys.SystemConfig) {
			genesisActivation := hexutil.Uint64(0)
			cfg.DeployConfig.L1CancunTimeOffset = &genesisActivation
			cfg.DeployConfig.L1PragueTimeOffset = &genesisActivation
			cfg.DeployConfig.L2GenesisDeltaTimeOffset = &genesisActivation
			cfg.DeployConfig.L2GenesisEcotoneTimeOffset = &genesisActivation
			cfg.DeployConfig.L2GenesisFjordTimeOffset = &genesisActivation
			cfg.DeployConfig.L2GenesisGraniteTimeOffset = &genesisActivation
			cfg.DeployConfig.L2GenesisHoloceneTimeOffset = &genesisActivation
			cfg.DeployConfig.L2GenesisIsthmusTimeOffset = &genesisActivation
		})
	}
}

func WithEcotone() faultDisputeConfigOpts {
	return func(fdc *faultDisputeConfig) {
		fdc.cfgModifiers = append(fdc.cfgModifiers, func(cfg *e2esys.SystemConfig) {
			genesisActivation := hexutil.Uint64(0)
			cfg.DeployConfig.L1CancunTimeOffset = &genesisActivation
			cfg.DeployConfig.L2GenesisDeltaTimeOffset = &genesisActivation
			cfg.DeployConfig.L2GenesisEcotoneTimeOffset = &genesisActivation
		})
	}
}

func WithSequencerWindowSize(size uint64) faultDisputeConfigOpts {
	return func(fdc *faultDisputeConfig) {
		fdc.cfgModifiers = append(fdc.cfgModifiers, func(cfg *e2esys.SystemConfig) {
			cfg.DeployConfig.SequencerWindowSize = size
		})
	}
}

func WithAllocType(allocType config.AllocType) faultDisputeConfigOpts {
	return func(fdc *faultDisputeConfig) {
		fdc.sysOpts = append(fdc.sysOpts, e2esys.WithAllocType(allocType))
	}
}

func StartFaultDisputeSystem(t *testing.T, opts ...faultDisputeConfigOpts) (*e2esys.System, *ethclient.Client) {
	fdc := new(faultDisputeConfig)
	for _, opt := range opts {
		opt(fdc)
	}

	cfg := e2esys.DefaultSystemConfig(t, fdc.sysOpts...)
	delete(cfg.Nodes, "verifier")
	cfg.Nodes["sequencer"].SafeDBPath = t.TempDir()
	cfg.DeployConfig.SequencerWindowSize = 30
	cfg.DeployConfig.FinalizationPeriodSeconds = 2
	cfg.SupportL1TimeTravel = true
	// Disable proposer creating fast games automatically - required games are manually created
	cfg.DisableProposer = true
	for _, opt := range fdc.cfgModifiers {
		opt(&cfg)
	}

	sys, err := cfg.Start(t)
	require.Nil(t, err, "Error starting up system")
	return sys, sys.NodeClient("l1")
}

func SendKZGPointEvaluationTx(t *testing.T, sys *e2esys.System, l2Node string, privateKey *ecdsa.PrivateKey) *types.Receipt {
	return helpers.SendL2Tx(t, sys.Cfg, sys.NodeClient(l2Node), privateKey, func(opts *helpers.TxOpts) {
		precompile := common.BytesToAddress([]byte{0x0a})
		opts.Gas = 100_000
		opts.ToAddr = &precompile
		opts.Data = common.FromHex("01e798154708fe7789429634053cbf9f99b619f9f084048927333fce637f549b564c0a11a0f704f4fc3e8acfe0f8245f0ad1347b378fbf96e206da11a5d3630624d25032e67a7e6a4910df5834b8fe70e6bcfeeac0352434196bdf4b2485d5a18f59a8d2a1a625a17f3fea0fe5eb8c896db3764f3185481bc22f91b4aaffcca25f26936857bc3a7c2539ea8ec3a952b7873033e038326e87ed3e1276fd140253fa08e9fc25fb2d9a98527fc22a2c9612fbeafdad446cbc7bcdbdcd780af2c16a")
	})
}
