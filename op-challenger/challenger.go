package op_challenger

import (
	"context"

	"github.com/ethereum-AIHI/AIHI/op-challenger/metrics"
	"github.com/ethereum/go-ethereum/log"

	"github.com/ethereum-AIHI/AIHI/op-challenger/config"
	"github.com/ethereum-AIHI/AIHI/op-challenger/game"
	"github.com/ethereum-AIHI/AIHI/op-service/cliapp"
)

// Main is the programmatic entry-point for running op-challenger with a given configuration.
func Main(ctx context.Context, logger log.Logger, cfg *config.Config, m metrics.Metricer) (cliapp.Lifecycle, error) {
	if err := cfg.Check(); err != nil {
		return nil, err
	}
	return game.NewService(ctx, logger, cfg, m)
}
