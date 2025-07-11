package confdepth

import (
	"context"

	"github.com/ethereum/go-ethereum"

	"github.com/ethereum-AIHI/AIHI/op-node/rollup/derive"
	"github.com/ethereum-AIHI/AIHI/op-service/eth"
)

// confDepth is an util that wraps the L1 input fetcher used in the pipeline,
// and hides the part of the L1 chain with insufficient confirmations.
//
// At 0 depth the l1 head is completely ignored.
type confDepth struct {
	// everything fetched by hash is trusted already, so we implement those by embedding the fetcher
	derive.L1Fetcher
	l1Head func() eth.L1BlockRef
	depth  uint64
}

func NewConfDepth(depth uint64, l1Head func() eth.L1BlockRef, fetcher derive.L1Fetcher) *confDepth {
	return &confDepth{L1Fetcher: fetcher, l1Head: l1Head, depth: depth}
}

// L1BlockRefByNumber is used for L1 traversal and for finding a safe common point between the L2 engine and L1 chain.
// Any block numbers that are within confirmation depth of the L1 head are mocked to be "not found",
// effectively hiding the uncertain part of the L1 chain.
func (c *confDepth) L1BlockRefByNumber(ctx context.Context, num uint64) (eth.L1BlockRef, error) {
	// Don't apply the conf depth if l1Head is empty (as it is during the startup case before the l1State is initialized).
	l1Head := c.l1Head()
	if l1Head == (eth.L1BlockRef{}) {
		return c.L1Fetcher.L1BlockRefByNumber(ctx, num)
	}
	if num == 0 || c.depth == 0 || num+c.depth <= l1Head.Number {
		return c.L1Fetcher.L1BlockRefByNumber(ctx, num)
	}
	return eth.L1BlockRef{}, ethereum.NotFound
}

var _ derive.L1Fetcher = (*confDepth)(nil)
