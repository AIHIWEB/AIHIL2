package stack

// L1ELNodeID identifies a L1ELNode by name and chainID, is type-safe, and can be value-copied and used as map key.
type L1ELNodeID idWithChain

const L1ELNodeKind Kind = "L1ELNode"

func (id L1ELNodeID) String() string {
	return idWithChain(id).string(L1ELNodeKind)
}

func (id L1ELNodeID) MarshalText() ([]byte, error) {
	return idWithChain(id).marshalText(L1ELNodeKind)
}

func (id *L1ELNodeID) UnmarshalText(data []byte) error {
	return (*idWithChain)(id).unmarshalText(L1ELNodeKind, data)
}

func SortL1ELNodeIDs(ids []L1ELNodeID) []L1ELNodeID {
	return copyAndSort(ids, func(a, b L1ELNodeID) bool {
		return lessIDWithChain(idWithChain(a), idWithChain(b))
	})
}

func SortL1ELNodes(elems []L1ELNode) []L1ELNode {
	return copyAndSort(elems, func(a, b L1ELNode) bool {
		return lessIDWithChain(idWithChain(a.ID()), idWithChain(b.ID()))
	})
}

var _ L1ELMatcher = L1ELNodeID{}

func (id L1ELNodeID) Match(elems []L1ELNode) []L1ELNode {
	return findByID(id, elems)
}

// L1ELNode is a L1 ethereum execution-layer node
type L1ELNode interface {
	ID() L1ELNodeID

	ELNode
}
