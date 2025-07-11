package shim

import (
	"github.com/ethereum-AIHI/AIHI/devnet-sdk/devstack/devtest"
	"github.com/ethereum-AIHI/AIHI/devnet-sdk/devstack/stack"
	"github.com/ethereum-AIHI/AIHI/op-service/eth"
	"github.com/ethereum-AIHI/AIHI/op-service/locks"
)

// SystemConfig sets up a System.
// It is intentially very minimal, the system is expected to be extended after creation, using Option functions
type SystemConfig struct {
	CommonConfig
}

type presetSystem struct {
	commonImpl

	superchains locks.RWMap[stack.SuperchainID, stack.Superchain]
	clusters    locks.RWMap[stack.ClusterID, stack.Cluster]

	// tracks L1 networks by L1NetworkID (a typed eth.ChainID)
	l1Networks locks.RWMap[stack.L1NetworkID, stack.L1Network]
	// tracks L2 networks by L2NetworkID (a typed eth.ChainID)
	l2Networks locks.RWMap[stack.L2NetworkID, stack.L2Network]

	// tracks all networks, and ensures there are no networks with the same eth.ChainID
	networks locks.RWMap[eth.ChainID, stack.Network]

	supervisors locks.RWMap[stack.SupervisorID, stack.Supervisor]
}

var _ stack.ExtensibleSystem = (*presetSystem)(nil)

// NewSystem creates a new empty System
func NewSystem(t devtest.T) stack.ExtensibleSystem {
	return &presetSystem{
		commonImpl: newCommon(NewCommonConfig(t)),
	}
}

func (p *presetSystem) Superchain(m stack.SuperchainMatcher) stack.Superchain {
	v, ok := findMatch(m, p.superchains.Get, p.Superchains)
	p.require().True(ok, "must find superchain %s", m)
	return v
}

func (p *presetSystem) AddSuperchain(v stack.Superchain) {
	p.require().True(p.superchains.SetIfMissing(v.ID(), v), "superchain %s must not already exist", v.ID())
}

func (p *presetSystem) Cluster(m stack.ClusterMatcher) stack.Cluster {
	v, ok := findMatch(m, p.clusters.Get, p.Clusters)
	p.require().True(ok, "must find cluster %s", m)
	return v
}

func (p *presetSystem) AddCluster(v stack.Cluster) {
	p.require().True(p.clusters.SetIfMissing(v.ID(), v), "cluster %s must not already exist", v.ID())
}

func (p *presetSystem) L1Network(m stack.L1NetworkMatcher) stack.L1Network {
	v, ok := findMatch(m, p.l1Networks.Get, p.L1Networks)
	p.require().True(ok, "must find l1 network %s", m)
	return v
}

func (p *presetSystem) AddL1Network(v stack.L1Network) {
	id := v.ID()
	p.require().True(p.networks.SetIfMissing(id.ChainID(), v), "chain with id %s must not already exist", id.ChainID())
	p.require().True(p.l1Networks.SetIfMissing(id, v), "L1 chain %s must not already exist", id)
}

func (p *presetSystem) L2Network(m stack.L2NetworkMatcher) stack.L2Network {
	v, ok := findMatch(m, p.l2Networks.Get, p.L2Networks)
	p.require().True(ok, "must find l2 network %s", m)
	return v
}

func (p *presetSystem) AddL2Network(v stack.L2Network) {
	id := v.ID()
	p.require().True(p.networks.SetIfMissing(id.ChainID(), v), "chain with id %s must not already exist", id.ChainID())
	p.require().True(p.l2Networks.SetIfMissing(id, v), "L2 chain %s must not already exist", id)
}

func (p *presetSystem) Supervisor(m stack.SupervisorMatcher) stack.Supervisor {
	v, ok := findMatch(m, p.supervisors.Get, p.Supervisors)
	p.require().True(ok, "must find supervisor %s", m)
	return v
}

func (p *presetSystem) AddSupervisor(v stack.Supervisor) {
	p.require().True(p.supervisors.SetIfMissing(v.ID(), v), "supervisor %s must not already exist", v.ID())
}

func (p *presetSystem) SuperchainIDs() []stack.SuperchainID {
	return stack.SortSuperchainIDs(p.superchains.Keys())
}

func (p *presetSystem) Superchains() []stack.Superchain {
	return stack.SortSuperchains(p.superchains.Values())
}

func (p *presetSystem) ClusterIDs() []stack.ClusterID {
	return stack.SortClusterIDs(p.clusters.Keys())
}

func (p *presetSystem) Clusters() []stack.Cluster {
	return stack.SortClusters(p.clusters.Values())
}

func (p *presetSystem) L1NetworkIDs() []stack.L1NetworkID {
	return stack.SortL1NetworkIDs(p.l1Networks.Keys())
}

func (p *presetSystem) L1Networks() []stack.L1Network {
	return stack.SortL1Networks(p.l1Networks.Values())
}

func (p *presetSystem) L2NetworkIDs() []stack.L2NetworkID {
	return stack.SortL2NetworkIDs(p.l2Networks.Keys())
}

func (p *presetSystem) L2Networks() []stack.L2Network {
	return stack.SortL2Networks(p.l2Networks.Values())
}

func (p *presetSystem) SupervisorIDs() []stack.SupervisorID {
	return stack.SortSupervisorIDs(p.supervisors.Keys())
}

func (p *presetSystem) Supervisors() []stack.Supervisor {
	return stack.SortSupervisors(p.supervisors.Values())
}
