package stack

// L2ELNodeID identifies a L2ELNode by name and chainID, is type-safe, and can be value-copied and used as map key.
type L2ELNodeID idWithChain

const L2ELNodeKind Kind = "L2ELNode"

func (id L2ELNodeID) String() string {
	return idWithChain(id).string(L2ELNodeKind)
}

func (id L2ELNodeID) MarshalText() ([]byte, error) {
	return idWithChain(id).marshalText(L2ELNodeKind)
}

func (id *L2ELNodeID) UnmarshalText(data []byte) error {
	return (*idWithChain)(id).unmarshalText(L2ELNodeKind, data)
}

func SortL2ELNodeIDs(ids []L2ELNodeID) []L2ELNodeID {
	return copyAndSort(ids, func(a, b L2ELNodeID) bool {
		return lessIDWithChain(idWithChain(a), idWithChain(b))
	})
}

func SortL2ELNodes(elems []L2ELNode) []L2ELNode {
	return copyAndSort(elems, func(a, b L2ELNode) bool {
		return lessIDWithChain(idWithChain(a.ID()), idWithChain(b.ID()))
	})
}

var _ L2ELMatcher = L2ELNodeID{}

func (id L2ELNodeID) Match(elems []L2ELNode) []L2ELNode {
	return findByID(id, elems)
}

// L2ELNode is a L2 ethereum execution-layer node
type L2ELNode interface {
	ID() L2ELNodeID

	ELNode
}
