package services

import (
	"context"

	rollupNode "github.com/ethereum-AIHI/AIHI/op-node/node"
	"github.com/ethereum-AIHI/AIHI/op-node/p2p"
	"github.com/ethereum-AIHI/AIHI/op-service/endpoint"
)

// EthInstance is either an in process Geth or external process exposing its
// endpoints over the network
type EthInstance interface {
	UserRPC() endpoint.RPC
	AuthRPC() endpoint.RPC
	Close() error
}

type RollupNode interface {
	UserRPC() endpoint.RPC
	Stop(ctx context.Context) error
	Stopped() bool
	RuntimeConfig() rollupNode.ReadonlyRuntimeConfig
	P2P() p2p.Node
}
