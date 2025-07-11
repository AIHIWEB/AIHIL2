package contracts

import (
	"context"
	"fmt"

	"github.com/ethereum-AIHI/AIHI/op-challenger/game/fault/contracts/metrics"
	"github.com/ethereum-AIHI/AIHI/op-challenger/game/fault/types"
	gameTypes "github.com/ethereum-AIHI/AIHI/op-challenger/game/types"
	"github.com/ethereum-AIHI/AIHI/op-service/sources/batching"
	"github.com/ethereum-AIHI/AIHI/op-service/sources/batching/rpcblock"
	"github.com/ethereum-AIHI/AIHI/op-service/txmgr"
	"github.com/ethereum-AIHI/AIHI/packages/contracts-bedrock/snapshots"
	"github.com/ethereum/go-ethereum/common"
)

var (
	methodL2SequenceNumber       = "l2SequenceNumber"
	methodStartingSequenceNumber = "startingSequenceNumber"
)

type SuperFaultDisputeGameContractLatest struct {
	FaultDisputeGameContractLatest
}

func NewSuperFaultDisputeGameContract(ctx context.Context, metrics metrics.ContractMetricer, addr common.Address, caller *batching.MultiCaller) (FaultDisputeGameContract, error) {
	contractAbi := snapshots.LoadSuperFaultDisputeGameABI()
	return &SuperFaultDisputeGameContractLatest{
		FaultDisputeGameContractLatest: FaultDisputeGameContractLatest{
			metrics:     metrics,
			multiCaller: caller,
			contract:    batching.NewBoundContract(contractAbi, addr),
		},
	}, nil
}

// GetGameMetadata returns the game's L1 head, L2 block number, root claim, status, max clock duration, and is l2 block number challenged.
func (f *SuperFaultDisputeGameContractLatest) GetGameMetadata(ctx context.Context, block rpcblock.Block) (GameMetadata, error) {
	defer f.metrics.StartContractRequest("GetGameMetadata")()
	results, err := f.multiCaller.Call(ctx, block,
		f.contract.Call(methodL1Head),
		f.contract.Call(methodL2SequenceNumber),
		f.contract.Call(methodRootClaim),
		f.contract.Call(methodStatus),
		f.contract.Call(methodMaxClockDuration),
	)
	if err != nil {
		return GameMetadata{}, fmt.Errorf("failed to retrieve game metadata: %w", err)
	}
	if len(results) != 5 {
		return GameMetadata{}, fmt.Errorf("expected 5 results but got %v", len(results))
	}
	l1Head := results[0].GetHash(0)
	l2Timestamp := results[1].GetBigInt(0).Uint64()
	rootClaim := results[2].GetHash(0)
	status, err := gameTypes.GameStatusFromUint8(results[3].GetUint8(0))
	if err != nil {
		return GameMetadata{}, fmt.Errorf("failed to convert game status: %w", err)
	}
	duration := results[4].GetUint64(0)
	return GameMetadata{
		L1Head:           l1Head,
		L2SequenceNum:    l2Timestamp,
		RootClaim:        rootClaim,
		Status:           status,
		MaxClockDuration: duration,
	}, nil
}

func (f *SuperFaultDisputeGameContractLatest) IsL2BlockNumberChallenged(ctx context.Context, block rpcblock.Block) (bool, error) {
	return false, nil
}

func (f *SuperFaultDisputeGameContractLatest) ChallengeL2BlockNumberTx(challenge *types.InvalidL2BlockNumberChallenge) (txmgr.TxCandidate, error) {
	return txmgr.TxCandidate{}, ErrChallengeL2BlockNotSupported
}

// GetGameRange returns the timestamps of the absolute pre-state and the proposed super root
func (f *SuperFaultDisputeGameContractLatest) GetGameRange(ctx context.Context) (prestateBlock uint64, poststateBlock uint64, retErr error) {
	defer f.metrics.StartContractRequest("GetGameRange")()
	results, err := f.multiCaller.Call(ctx, rpcblock.Latest,
		f.contract.Call(methodStartingSequenceNumber),
		f.contract.Call(methodL2SequenceNumber))
	if err != nil {
		retErr = fmt.Errorf("failed to retrieve game range: %w", err)
		return
	}
	if len(results) != 2 {
		retErr = fmt.Errorf("expected 2 results but got %v", len(results))
		return
	}
	prestateBlock = results[0].GetBigInt(0).Uint64()
	poststateBlock = results[1].GetBigInt(0).Uint64()
	return
}
