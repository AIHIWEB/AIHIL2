package config

import (
	"context"

	"github.com/ethereum-AIHI/AIHI/op-test-sequencer/sequencer/backend/work"
	"github.com/ethereum-AIHI/AIHI/op-test-sequencer/sequencer/backend/work/publishers/nooppublisher"
	"github.com/ethereum-AIHI/AIHI/op-test-sequencer/sequencer/seqtypes"
)

type PublisherEntry struct {
	Noop *nooppublisher.Config `yaml:"noop,omitempty"`
}

func (b *PublisherEntry) Start(ctx context.Context, id seqtypes.PublisherID, opts *work.ServiceOpts) (work.Publisher, error) {
	switch {
	case b.Noop != nil:
		return b.Noop.Start(ctx, id, opts)
	default:
		return nil, seqtypes.ErrUnknownKind
	}
}
