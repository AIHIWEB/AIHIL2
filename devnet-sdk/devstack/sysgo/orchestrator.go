package sysgo

import (
	"os"
	"path/filepath"
	"sync"

	"github.com/stretchr/testify/require"

	"github.com/ethereum-AIHI/AIHI/devnet-sdk/devstack/devtest"
	"github.com/ethereum-AIHI/AIHI/devnet-sdk/devstack/stack"
	"github.com/ethereum-AIHI/AIHI/op-chain-ops/devkeys"
	"github.com/ethereum-AIHI/AIHI/op-service/clock"
	"github.com/ethereum-AIHI/AIHI/op-service/eth"
	"github.com/ethereum-AIHI/AIHI/op-service/locks"
	"github.com/ethereum/go-ethereum/common/hexutil"
)

type Orchestrator struct {
	p devtest.P

	keys devkeys.Keys

	// nil if no time travel is supported
	timeTravelClock *clock.AdvancingClock

	superchains locks.RWMap[stack.SuperchainID, *Superchain]
	clusters    locks.RWMap[stack.ClusterID, *Cluster]
	l1Nets      locks.RWMap[eth.ChainID, *L1Network]
	l2Nets      locks.RWMap[eth.ChainID, *L2Network]
	l1ELs       locks.RWMap[stack.L1ELNodeID, *L1ELNode]
	l1CLs       locks.RWMap[stack.L1CLNodeID, *L1CLNode]
	l2ELs       locks.RWMap[stack.L2ELNodeID, *L2ELNode]
	l2CLs       locks.RWMap[stack.L2CLNodeID, *L2CLNode]
	supervisors locks.RWMap[stack.SupervisorID, *Supervisor]
	batchers    locks.RWMap[stack.L2BatcherID, *L2Batcher]
	//challengers locks.RWMap[stack.L2ChallengerID, *L2Challenger] // TODO(#15057): op-challenger support
	proposers locks.RWMap[stack.L2ProposerID, *L2Proposer]

	controlPlane *ControlPlane

	jwtPath     string
	jwtSecret   [32]byte
	jwtPathOnce sync.Once
}

func (o *Orchestrator) ControlPlane() stack.ControlPlane {
	return o.controlPlane
}

var _ stack.Orchestrator = (*Orchestrator)(nil)

func NewOrchestrator(p devtest.P) *Orchestrator {
	o := &Orchestrator{p: p}
	o.controlPlane = &ControlPlane{o: o}
	return o
}

func (o *Orchestrator) P() devtest.P {
	return o.p
}

func (o *Orchestrator) writeDefaultJWT() (jwtPath string, secret [32]byte) {
	o.jwtPathOnce.Do(func() {
		// Sadly the geth node config cannot load JWT secret from memory, it has to be a file
		o.jwtPath = filepath.Join(o.p.TempDir(), "jwt_secret")
		o.jwtSecret = [32]byte{123}
		err := os.WriteFile(o.jwtPath, []byte(hexutil.Encode(o.jwtSecret[:])), 0o600)
		require.NoError(o.p, err, "failed to prepare jwt file")
	})
	return o.jwtPath, o.jwtSecret
}

func (o *Orchestrator) Hydrate(sys stack.ExtensibleSystem) {
	o.superchains.Range(rangeHydrateFn[stack.SuperchainID, *Superchain](sys))
	o.clusters.Range(rangeHydrateFn[stack.ClusterID, *Cluster](sys))
	o.l1Nets.Range(rangeHydrateFn[eth.ChainID, *L1Network](sys))
	o.l2Nets.Range(rangeHydrateFn[eth.ChainID, *L2Network](sys))
	o.l1ELs.Range(rangeHydrateFn[stack.L1ELNodeID, *L1ELNode](sys))
	o.l1CLs.Range(rangeHydrateFn[stack.L1CLNodeID, *L1CLNode](sys))
	o.l2ELs.Range(rangeHydrateFn[stack.L2ELNodeID, *L2ELNode](sys))
	o.l2CLs.Range(rangeHydrateFn[stack.L2CLNodeID, *L2CLNode](sys))
	o.supervisors.Range(rangeHydrateFn[stack.SupervisorID, *Supervisor](sys))
	o.batchers.Range(rangeHydrateFn[stack.L2BatcherID, *L2Batcher](sys))
	o.proposers.Range(rangeHydrateFn[stack.L2ProposerID, *L2Proposer](sys))
}

type hydrator interface {
	hydrate(system stack.ExtensibleSystem)
}

func rangeHydrateFn[I any, H hydrator](sys stack.ExtensibleSystem) func(id I, v H) bool {
	return func(id I, v H) bool {
		v.hydrate(sys)
		return true
	}
}
