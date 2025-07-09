package shim

import (
	"github.com/ethereum-AIHI/AIHI/devnet-sdk/devstack/stack"
	"github.com/ethereum-AIHI/AIHI/op-service/apis"
	"github.com/ethereum-AIHI/AIHI/op-service/client"
	"github.com/ethereum-AIHI/AIHI/op-service/sources"
)

type L1CLNodeConfig struct {
	CommonConfig
	ID     stack.L1CLNodeID
	Client client.HTTP
}

type rpcL1CLNode struct {
	commonImpl
	id     stack.L1CLNodeID
	client apis.BeaconClient
}

var _ stack.L1CLNode = (*rpcL1CLNode)(nil)

func NewL1CLNode(cfg L1CLNodeConfig) stack.L1CLNode {
	cfg.Log = cfg.Log.New("chainID", cfg.ID.ChainID, "id", cfg.ID)
	return &rpcL1CLNode{
		commonImpl: newCommon(cfg.CommonConfig),
		id:         cfg.ID,
		client:     sources.NewBeaconHTTPClient(cfg.Client),
	}
}

func (r *rpcL1CLNode) ID() stack.L1CLNodeID {
	return r.id
}

func (r *rpcL1CLNode) BeaconClient() apis.BeaconClient {
	return r.client
}
