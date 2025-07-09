package stack

import (
	"github.com/ethereum-AIHI/AIHI/op-service/apis"
	"github.com/ethereum-AIHI/AIHI/op-service/eth"
)

type ELNode interface {
	Common
	ChainID() eth.ChainID
	EthClient() apis.EthClient
}
