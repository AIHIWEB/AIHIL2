package stack

import (
	"github.com/ethereum-AIHI/AIHI/op-service/apis"
)

// L1CLNodeID identifies a L1CLNode by name and chainID, is type-safe, and can be value-copied and used as map key.
type L1CLNodeID idWithChain

const L1CLNodeKind Kind = "L1CLNode"

func (id L1CLNodeID) String() string {
	return idWithChain(id).string(L1CLNodeKind)
}

func (id L1CLNodeID) MarshalText() ([]byte, error) {
	return idWithChain(id).marshalText(L1CLNodeKind)
}

func (id *L1CLNodeID) UnmarshalText(data []byte) error {
	return (*idWithChain)(id).unmarshalText(L1CLNodeKind, data)
}

func SortL1CLNodeIDs(ids []L1CLNodeID) []L1CLNodeID {
	return copyAndSort(ids, func(a, b L1CLNodeID) bool {
		return lessIDWithChain(idWithChain(a), idWithChain(b))
	})
}

func SortL1CLNodes(elems []L1CLNode) []L1CLNode {
	return copyAndSort(elems, func(a, b L1CLNode) bool {
		return lessIDWithChain(idWithChain(a.ID()), idWithChain(b.ID()))
	})
}

var _ L1CLMatcher = L1CLNodeID{}

func (id L1CLNodeID) Match(elems []L1CLNode) []L1CLNode {
	return findByID(id, elems)
}

// L1CLNode is a L1 ethereum consensus-layer node, aka Beacon node.
// This node may not be a full beacon node, and instead run a mock L1 consensus node.
type L1CLNode interface {
	Common
	ID() L1CLNodeID

	BeaconClient() apis.BeaconClient
}
