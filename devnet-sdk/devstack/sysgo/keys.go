package sysgo

import (
	"github.com/ethereum-AIHI/AIHI/devnet-sdk/devstack/stack"
	"github.com/ethereum-AIHI/AIHI/op-chain-ops/devkeys"
)

func WithMnemonicKeys(mnemonic string) stack.Option {
	return func(o stack.Orchestrator) {
		orch := o.(*Orchestrator)
		require := o.P().Require()
		hd, err := devkeys.NewMnemonicDevKeys(mnemonic)
		require.NoError(err)
		orch.keys = hd
	}
}
