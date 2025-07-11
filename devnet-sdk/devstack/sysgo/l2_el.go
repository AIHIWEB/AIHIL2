package sysgo

import (
	"github.com/ethereum/go-ethereum/eth/ethconfig"
	gn "github.com/ethereum/go-ethereum/node"

	"github.com/ethereum-AIHI/AIHI/devnet-sdk/devstack/shim"
	"github.com/ethereum-AIHI/AIHI/devnet-sdk/devstack/stack"
	"github.com/ethereum-AIHI/AIHI/devnet-sdk/devstack/stack/match"
	"github.com/ethereum-AIHI/AIHI/op-e2e/e2eutils/geth"
	"github.com/ethereum-AIHI/AIHI/op-service/client"
)

type L2ELNode struct {
	id      stack.L2ELNodeID
	authRPC string
	userRPC string
}

func (n *L2ELNode) hydrate(system stack.ExtensibleSystem) {
	require := system.T().Require()
	rpcCl, err := client.NewRPC(system.T().Ctx(), system.Logger(), n.userRPC, client.WithLazyDial())
	require.NoError(err)
	system.T().Cleanup(rpcCl.Close)

	sysL2EL := shim.NewL2ELNode(shim.L2ELNodeConfig{
		ELNodeConfig: shim.ELNodeConfig{
			CommonConfig: shim.NewCommonConfig(system.T()),
			Client:       rpcCl,
			ChainID:      n.id.ChainID,
		},
		ID: n.id,
	})
	sysL2EL.SetLabel(match.LabelVendor, string(match.OpGeth))
	l2Net := system.L2Network(stack.L2NetworkID(n.id.ChainID))
	l2Net.(stack.ExtensibleL2Network).AddL2ELNode(sysL2EL)
}

func WithL2ELNode(id stack.L2ELNodeID, supervisorID *stack.SupervisorID) stack.Option {
	return func(o stack.Orchestrator) {
		orch := o.(*Orchestrator)
		require := o.P().Require()

		l2Net, ok := orch.l2Nets.Get(id.ChainID)
		require.True(ok, "L2 network required")

		jwtPath, _ := orch.writeDefaultJWT()

		useInterop := l2Net.genesis.Config.InteropTime != nil

		supervisorRPC := ""
		if useInterop {
			require.NotNil(supervisorID, "supervisor is required for interop")
			sup, ok := orch.supervisors.Get(*supervisorID)
			require.True(ok, "supervisor is required for interop")
			supervisorRPC = sup.userRPC
		}
		logger := o.P().Logger().New("id", id)

		l2Geth, err := geth.InitL2(id.String(), l2Net.genesis, jwtPath,
			func(ethCfg *ethconfig.Config, nodeCfg *gn.Config) error {
				ethCfg.InteropMessageRPC = supervisorRPC
				ethCfg.InteropMempoolFiltering = true // TODO option
				return nil
			})
		require.NoError(err)
		require.NoError(l2Geth.Node.Start())

		orch.p.Cleanup(func() {
			logger.Info("Closing op-geth", "id", id)
			closeErr := l2Geth.Close()
			logger.Info("Closed op-geth", "id", id, "err", closeErr)
		})

		l2EL := &L2ELNode{
			id:      id,
			authRPC: l2Geth.AuthRPC().RPC(),
			userRPC: l2Geth.UserRPC().RPC(),
		}
		require.True(orch.l2ELs.SetIfMissing(id, l2EL), "must be unique L2 EL node")
	}
}
