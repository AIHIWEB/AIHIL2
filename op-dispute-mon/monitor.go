package monitor

import (
	"context"

	"github.com/ethereum/go-ethereum/log"

	"github.com/ethereum-AIHI/AIHI/op-dispute-mon/config"
	"github.com/ethereum-AIHI/AIHI/op-dispute-mon/mon"
	"github.com/ethereum-AIHI/AIHI/op-service/cliapp"
)

func Main(ctx context.Context, logger log.Logger, cfg *config.Config) (cliapp.Lifecycle, error) {
	if err := cfg.Check(); err != nil {
		return nil, err
	}
	return mon.NewService(ctx, logger, cfg)
}
