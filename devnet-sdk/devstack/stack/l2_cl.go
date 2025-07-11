package stack

import (
	"github.com/ethereum-AIHI/AIHI/op-service/apis"
)

// L2CLNodeID identifies a L2CLNode by name and chainID, is type-safe, and can be value-copied and used as map key.
type L2CLNodeID idWithChain

const L2CLNodeKind Kind = "L2CLNode"

func (id L2CLNodeID) String() string {
	return idWithChain(id).string(L2CLNodeKind)
}

func (id L2CLNodeID) MarshalText() ([]byte, error) {
	return idWithChain(id).marshalText(L2CLNodeKind)
}

func (id *L2CLNodeID) UnmarshalText(data []byte) error {
	return (*idWithChain)(id).unmarshalText(L2CLNodeKind, data)
}

func SortL2CLNodeIDs(ids []L2CLNodeID) []L2CLNodeID {
	return copyAndSort(ids, func(a, b L2CLNodeID) bool {
		return lessIDWithChain(idWithChain(a), idWithChain(b))
	})
}

func SortL2CLNodes(elems []L2CLNode) []L2CLNode {
	return copyAndSort(elems, func(a, b L2CLNode) bool {
		return lessIDWithChain(idWithChain(a.ID()), idWithChain(b.ID()))
	})
}

var _ L2CLMatcher = L2CLNodeID{}

func (id L2CLNodeID) Match(elems []L2CLNode) []L2CLNode {
	return findByID(id, elems)
}

// L2CLNode is a L2 ethereum consensus-layer node
type L2CLNode interface {
	Common
	ID() L2CLNodeID

	RollupAPI() apis.RollupClient

	// ELs returns the engine(s) that this L2CLNode is connected to.
	// This may be empty, if the L2CL is not connected to any.
	ELs() []L2ELNode
}

type LinkableL2CLNode interface {
	// Links the nodes. Does not make any backend changes, just registers the EL as connected to this CL.
	LinkEL(el L2ELNode)
}
