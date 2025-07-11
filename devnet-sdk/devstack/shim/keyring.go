package shim

import (
	"crypto/ecdsa"

	"github.com/stretchr/testify/require"

	"github.com/ethereum/go-ethereum/common"

	"github.com/ethereum-AIHI/AIHI/devnet-sdk/devstack/stack"
	"github.com/ethereum-AIHI/AIHI/op-chain-ops/devkeys"
)

type keyringImpl struct {
	keys    devkeys.Keys
	require *require.Assertions
}

var _ stack.Keys = (*keyringImpl)(nil)

func NewKeyring(keys devkeys.Keys, req *require.Assertions) stack.Keys {
	return &keyringImpl{
		keys:    keys,
		require: req,
	}
}

func (k *keyringImpl) Secret(key devkeys.Key) *ecdsa.PrivateKey {
	pk, err := k.keys.Secret(key)
	k.require.NoError(err)
	return pk
}

func (k *keyringImpl) Address(key devkeys.Key) common.Address {
	addr, err := k.keys.Address(key)
	k.require.NoError(err)
	return addr
}
