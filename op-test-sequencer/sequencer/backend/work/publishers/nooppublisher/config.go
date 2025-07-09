package nooppublisher

import (
	"context"

	"github.com/ethereum-AIHI/AIHI/op-test-sequencer/sequencer/backend/work"
	"github.com/ethereum-AIHI/AIHI/op-test-sequencer/sequencer/seqtypes"
)

type Config struct {
}

func (c *Config) Start(ctx context.Context, id seqtypes.PublisherID, opts *work.ServiceOpts) (work.Publisher, error) {
	return &Publisher{
		id:  id,
		log: opts.Log,
	}, nil
}
