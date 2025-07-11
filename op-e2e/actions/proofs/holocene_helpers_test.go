package proofs

import (
	actionsHelpers "github.com/ethereum-AIHI/AIHI/op-e2e/actions/helpers"
	"github.com/ethereum-AIHI/AIHI/op-service/eth"
	"github.com/ethereum-AIHI/AIHI/op-service/testlog"
	"github.com/stretchr/testify/require"
)

type logExpectations struct {
	role   string
	filter string
	num    int
}
type expectations struct {
	safeHead uint64
	logs     []logExpectations
}
type holoceneExpectations struct {
	preHolocene, holocene expectations
}

func (h holoceneExpectations) RequireExpectedProgressAndLogs(t actionsHelpers.StatefulTesting, actualSafeHead eth.L2BlockRef, isHolocene bool, engine *actionsHelpers.L2Engine, logs *testlog.CapturingHandler) {
	t.Helper()

	var exp expectations
	if isHolocene {
		exp = h.holocene
	} else {
		exp = h.preHolocene
	}

	require.Equal(t, exp.safeHead, actualSafeHead.Number, "safe head: wrong number")
	expectedHash := engine.L2Chain().GetHeaderByNumber(exp.safeHead).Hash()
	require.Equal(t, expectedHash, actualSafeHead.Hash, "safe head: wrong hash")

	for _, l := range exp.logs {
		t.Helper()
		recs := logs.FindLogs(testlog.NewMessageContainsFilter(l.filter), testlog.NewAttributesFilter("role", l.role))
		require.Len(t, recs, l.num, "searching for %d instances of %q in logs from role %s", l.num, l.filter, l.role)
	}
}

func sequencerOnce(filter string) []logExpectations {
	return []logExpectations{{filter: filter, role: "sequencer", num: 1}}
}
