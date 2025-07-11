package nooppublisher

import (
	"context"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/ethereum/go-ethereum/log"

	"github.com/ethereum-AIHI/AIHI/op-service/testlog"
	"github.com/ethereum-AIHI/AIHI/op-test-sequencer/metrics"
	"github.com/ethereum-AIHI/AIHI/op-test-sequencer/sequencer/backend/work"
	"github.com/ethereum-AIHI/AIHI/op-test-sequencer/sequencer/seqtypes"
)

func TestConfig(t *testing.T) {
	logger := testlog.Logger(t, log.LevelInfo)
	cfg := &Config{}
	id := seqtypes.PublisherID("test")
	ensemble := &work.Ensemble{}
	opts := &work.ServiceOpts{
		StartOpts: &work.StartOpts{
			Log:     logger,
			Metrics: &metrics.NoopMetrics{},
		},
		Services: ensemble,
	}
	publisher, err := cfg.Start(context.Background(), id, opts)
	require.NoError(t, err)
	require.Equal(t, id, publisher.ID())
}
