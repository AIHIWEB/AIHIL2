package stack

import (
	"github.com/ethereum-AIHI/AIHI/op-service/apis"
)

// SupervisorID identifies a Supervisor by name and chainID, is type-safe, and can be value-copied and used as map key.
type SupervisorID genericID

const SupervisorKind Kind = "Supervisor"

func (id SupervisorID) String() string {
	return genericID(id).string(SupervisorKind)
}

func (id SupervisorID) MarshalText() ([]byte, error) {
	return genericID(id).marshalText(SupervisorKind)
}

func (id *SupervisorID) UnmarshalText(data []byte) error {
	return (*genericID)(id).unmarshalText(SupervisorKind, data)
}

func SortSupervisorIDs(ids []SupervisorID) []SupervisorID {
	return copyAndSortCmp(ids)
}

func SortSupervisors(elems []Supervisor) []Supervisor {
	return copyAndSort(elems, lessElemOrdered[SupervisorID, Supervisor])
}

var _ SupervisorMatcher = SupervisorID("")

func (id SupervisorID) Match(elems []Supervisor) []Supervisor {
	return findByID(id, elems)
}

// Supervisor is an interop service, used to cross-verify messages between chains.
type Supervisor interface {
	Common
	ID() SupervisorID

	AdminAPI() apis.SupervisorAdminAPI
	QueryAPI() apis.SupervisorQueryAPI
}
