package dsl

import (
	"math/big"

	"github.com/ethereum-AIHI/AIHI/op-chain-ops/devkeys"
	"github.com/ethereum-AIHI/AIHI/op-e2e/actions/helpers"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/require"
)

type DSLUser struct {
	t     helpers.Testing
	index uint64
	keys  devkeys.Keys
}

func (u *DSLUser) TransactOpts(chainID *big.Int) (*bind.TransactOpts, common.Address) {
	privKey, err := u.keys.Secret(devkeys.ChainUserKeys(chainID)(u.index))
	require.NoError(u.t, err)
	opts, err := bind.NewKeyedTransactorWithChainID(privKey, chainID)
	require.NoError(u.t, err)
	opts.GasTipCap = big.NewInt(params.GWei)

	return opts, crypto.PubkeyToAddress(privKey.PublicKey)
}
