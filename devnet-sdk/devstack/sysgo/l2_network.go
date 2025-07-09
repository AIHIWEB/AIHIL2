package sysgo

import (
	"github.com/ethereum/go-ethereum/core"

	"github.com/ethereum-AIHI/AIHI/devnet-sdk/devstack/shim"
	"github.com/ethereum-AIHI/AIHI/devnet-sdk/devstack/stack"
	"github.com/ethereum-AIHI/AIHI/op-chain-ops/devkeys"
	"github.com/ethereum-AIHI/AIHI/op-node/rollup"
	"github.com/ethereum-AIHI/AIHI/op-service/eth"
)

type L2Network struct {
	id         stack.L2NetworkID
	l1ChainID  eth.ChainID
	genesis    *core.Genesis
	rollupCfg  *rollup.Config
	deployment *L2Deployment
	keys       devkeys.Keys
}

func (c *L2Network) hydrate(system stack.ExtensibleSystem) {
	l1Net := system.L1Network(stack.L1NetworkID(c.l1ChainID))
	sysL2Net := shim.NewL2Network(shim.L2NetworkConfig{
		NetworkConfig: shim.NetworkConfig{
			CommonConfig: shim.NewCommonConfig(system.T()),
			ChainConfig:  c.genesis.Config,
		},
		ID:           c.id,
		RollupConfig: c.rollupCfg,
		Deployment:   c.deployment,
		Keys:         shim.NewKeyring(c.keys, system.T().Require()),
		Superchain:   nil,
		L1:           l1Net,
		Cluster:      nil,
	})
	system.AddL2Network(sysL2Net)
}
