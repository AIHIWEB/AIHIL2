package broadcaster

import (
	"context"

	"github.com/ethereum-AIHI/AIHI/op-chain-ops/script"
)

type discardBroadcaster struct {
}

func NoopBroadcaster() Broadcaster {
	return &discardBroadcaster{}
}

func (d *discardBroadcaster) Broadcast(ctx context.Context) ([]BroadcastResult, error) {
	return nil, nil
}

func (d *discardBroadcaster) Hook(bcast script.Broadcast) {}
