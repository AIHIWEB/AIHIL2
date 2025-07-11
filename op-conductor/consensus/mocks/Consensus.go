// Code generated by mockery v2.46.0. DO NOT EDIT.

package mocks

import (
	consensus "github.com/ethereum-AIHI/AIHI/op-conductor/consensus"
	eth "github.com/ethereum-AIHI/AIHI/op-service/eth"

	mock "github.com/stretchr/testify/mock"
)

// Consensus is an autogenerated mock type for the Consensus type
type Consensus struct {
	mock.Mock
}

type Consensus_Expecter struct {
	mock *mock.Mock
}

func (_m *Consensus) EXPECT() *Consensus_Expecter {
	return &Consensus_Expecter{mock: &_m.Mock}
}

// AddNonVoter provides a mock function with given fields: id, addr, version
func (_m *Consensus) AddNonVoter(id string, addr string, version uint64) error {
	ret := _m.Called(id, addr, version)

	if len(ret) == 0 {
		panic("no return value specified for AddNonVoter")
	}

	var r0 error
	if rf, ok := ret.Get(0).(func(string, string, uint64) error); ok {
		r0 = rf(id, addr, version)
	} else {
		r0 = ret.Error(0)
	}

	return r0
}

// Consensus_AddNonVoter_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'AddNonVoter'
type Consensus_AddNonVoter_Call struct {
	*mock.Call
}

// AddNonVoter is a helper method to define mock.On call
//   - id string
//   - addr string
//   - version uint64
func (_e *Consensus_Expecter) AddNonVoter(id interface{}, addr interface{}, version interface{}) *Consensus_AddNonVoter_Call {
	return &Consensus_AddNonVoter_Call{Call: _e.mock.On("AddNonVoter", id, addr, version)}
}

func (_c *Consensus_AddNonVoter_Call) Run(run func(id string, addr string, version uint64)) *Consensus_AddNonVoter_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(string), args[1].(string), args[2].(uint64))
	})
	return _c
}

func (_c *Consensus_AddNonVoter_Call) Return(_a0 error) *Consensus_AddNonVoter_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Consensus_AddNonVoter_Call) RunAndReturn(run func(string, string, uint64) error) *Consensus_AddNonVoter_Call {
	_c.Call.Return(run)
	return _c
}

// AddVoter provides a mock function with given fields: id, addr, version
func (_m *Consensus) AddVoter(id string, addr string, version uint64) error {
	ret := _m.Called(id, addr, version)

	if len(ret) == 0 {
		panic("no return value specified for AddVoter")
	}

	var r0 error
	if rf, ok := ret.Get(0).(func(string, string, uint64) error); ok {
		r0 = rf(id, addr, version)
	} else {
		r0 = ret.Error(0)
	}

	return r0
}

// Consensus_AddVoter_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'AddVoter'
type Consensus_AddVoter_Call struct {
	*mock.Call
}

// AddVoter is a helper method to define mock.On call
//   - id string
//   - addr string
//   - version uint64
func (_e *Consensus_Expecter) AddVoter(id interface{}, addr interface{}, version interface{}) *Consensus_AddVoter_Call {
	return &Consensus_AddVoter_Call{Call: _e.mock.On("AddVoter", id, addr, version)}
}

func (_c *Consensus_AddVoter_Call) Run(run func(id string, addr string, version uint64)) *Consensus_AddVoter_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(string), args[1].(string), args[2].(uint64))
	})
	return _c
}

func (_c *Consensus_AddVoter_Call) Return(_a0 error) *Consensus_AddVoter_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Consensus_AddVoter_Call) RunAndReturn(run func(string, string, uint64) error) *Consensus_AddVoter_Call {
	_c.Call.Return(run)
	return _c
}

// Addr provides a mock function with given fields:
func (_m *Consensus) Addr() string {
	ret := _m.Called()

	if len(ret) == 0 {
		panic("no return value specified for Addr")
	}

	var r0 string
	if rf, ok := ret.Get(0).(func() string); ok {
		r0 = rf()
	} else {
		r0 = ret.Get(0).(string)
	}

	return r0
}

// Consensus_Addr_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'Addr'
type Consensus_Addr_Call struct {
	*mock.Call
}

// Addr is a helper method to define mock.On call
func (_e *Consensus_Expecter) Addr() *Consensus_Addr_Call {
	return &Consensus_Addr_Call{Call: _e.mock.On("Addr")}
}

func (_c *Consensus_Addr_Call) Run(run func()) *Consensus_Addr_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run()
	})
	return _c
}

func (_c *Consensus_Addr_Call) Return(_a0 string) *Consensus_Addr_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Consensus_Addr_Call) RunAndReturn(run func() string) *Consensus_Addr_Call {
	_c.Call.Return(run)
	return _c
}

// ClusterMembership provides a mock function with given fields:
func (_m *Consensus) ClusterMembership() (*consensus.ClusterMembership, error) {
	ret := _m.Called()

	if len(ret) == 0 {
		panic("no return value specified for ClusterMembership")
	}

	var r0 *consensus.ClusterMembership
	var r1 error
	if rf, ok := ret.Get(0).(func() (*consensus.ClusterMembership, error)); ok {
		return rf()
	}
	if rf, ok := ret.Get(0).(func() *consensus.ClusterMembership); ok {
		r0 = rf()
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).(*consensus.ClusterMembership)
		}
	}

	if rf, ok := ret.Get(1).(func() error); ok {
		r1 = rf()
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// Consensus_ClusterMembership_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'ClusterMembership'
type Consensus_ClusterMembership_Call struct {
	*mock.Call
}

// ClusterMembership is a helper method to define mock.On call
func (_e *Consensus_Expecter) ClusterMembership() *Consensus_ClusterMembership_Call {
	return &Consensus_ClusterMembership_Call{Call: _e.mock.On("ClusterMembership")}
}

func (_c *Consensus_ClusterMembership_Call) Run(run func()) *Consensus_ClusterMembership_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run()
	})
	return _c
}

func (_c *Consensus_ClusterMembership_Call) Return(_a0 *consensus.ClusterMembership, _a1 error) *Consensus_ClusterMembership_Call {
	_c.Call.Return(_a0, _a1)
	return _c
}

func (_c *Consensus_ClusterMembership_Call) RunAndReturn(run func() (*consensus.ClusterMembership, error)) *Consensus_ClusterMembership_Call {
	_c.Call.Return(run)
	return _c
}

// CommitUnsafePayload provides a mock function with given fields: payload
func (_m *Consensus) CommitUnsafePayload(payload *eth.ExecutionPayloadEnvelope) error {
	ret := _m.Called(payload)

	if len(ret) == 0 {
		panic("no return value specified for CommitUnsafePayload")
	}

	var r0 error
	if rf, ok := ret.Get(0).(func(*eth.ExecutionPayloadEnvelope) error); ok {
		r0 = rf(payload)
	} else {
		r0 = ret.Error(0)
	}

	return r0
}

// Consensus_CommitUnsafePayload_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'CommitUnsafePayload'
type Consensus_CommitUnsafePayload_Call struct {
	*mock.Call
}

// CommitUnsafePayload is a helper method to define mock.On call
//   - payload *eth.ExecutionPayloadEnvelope
func (_e *Consensus_Expecter) CommitUnsafePayload(payload interface{}) *Consensus_CommitUnsafePayload_Call {
	return &Consensus_CommitUnsafePayload_Call{Call: _e.mock.On("CommitUnsafePayload", payload)}
}

func (_c *Consensus_CommitUnsafePayload_Call) Run(run func(payload *eth.ExecutionPayloadEnvelope)) *Consensus_CommitUnsafePayload_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(*eth.ExecutionPayloadEnvelope))
	})
	return _c
}

func (_c *Consensus_CommitUnsafePayload_Call) Return(_a0 error) *Consensus_CommitUnsafePayload_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Consensus_CommitUnsafePayload_Call) RunAndReturn(run func(*eth.ExecutionPayloadEnvelope) error) *Consensus_CommitUnsafePayload_Call {
	_c.Call.Return(run)
	return _c
}

// DemoteVoter provides a mock function with given fields: id, version
func (_m *Consensus) DemoteVoter(id string, version uint64) error {
	ret := _m.Called(id, version)

	if len(ret) == 0 {
		panic("no return value specified for DemoteVoter")
	}

	var r0 error
	if rf, ok := ret.Get(0).(func(string, uint64) error); ok {
		r0 = rf(id, version)
	} else {
		r0 = ret.Error(0)
	}

	return r0
}

// Consensus_DemoteVoter_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'DemoteVoter'
type Consensus_DemoteVoter_Call struct {
	*mock.Call
}

// DemoteVoter is a helper method to define mock.On call
//   - id string
//   - version uint64
func (_e *Consensus_Expecter) DemoteVoter(id interface{}, version interface{}) *Consensus_DemoteVoter_Call {
	return &Consensus_DemoteVoter_Call{Call: _e.mock.On("DemoteVoter", id, version)}
}

func (_c *Consensus_DemoteVoter_Call) Run(run func(id string, version uint64)) *Consensus_DemoteVoter_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(string), args[1].(uint64))
	})
	return _c
}

func (_c *Consensus_DemoteVoter_Call) Return(_a0 error) *Consensus_DemoteVoter_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Consensus_DemoteVoter_Call) RunAndReturn(run func(string, uint64) error) *Consensus_DemoteVoter_Call {
	_c.Call.Return(run)
	return _c
}

// LatestUnsafePayload provides a mock function with given fields:
func (_m *Consensus) LatestUnsafePayload() (*eth.ExecutionPayloadEnvelope, error) {
	ret := _m.Called()

	if len(ret) == 0 {
		panic("no return value specified for LatestUnsafePayload")
	}

	var r0 *eth.ExecutionPayloadEnvelope
	var r1 error
	if rf, ok := ret.Get(0).(func() (*eth.ExecutionPayloadEnvelope, error)); ok {
		return rf()
	}
	if rf, ok := ret.Get(0).(func() *eth.ExecutionPayloadEnvelope); ok {
		r0 = rf()
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).(*eth.ExecutionPayloadEnvelope)
		}
	}

	if rf, ok := ret.Get(1).(func() error); ok {
		r1 = rf()
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// Consensus_LatestUnsafePayload_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'LatestUnsafePayload'
type Consensus_LatestUnsafePayload_Call struct {
	*mock.Call
}

// LatestUnsafePayload is a helper method to define mock.On call
func (_e *Consensus_Expecter) LatestUnsafePayload() *Consensus_LatestUnsafePayload_Call {
	return &Consensus_LatestUnsafePayload_Call{Call: _e.mock.On("LatestUnsafePayload")}
}

func (_c *Consensus_LatestUnsafePayload_Call) Run(run func()) *Consensus_LatestUnsafePayload_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run()
	})
	return _c
}

func (_c *Consensus_LatestUnsafePayload_Call) Return(_a0 *eth.ExecutionPayloadEnvelope, _a1 error) *Consensus_LatestUnsafePayload_Call {
	_c.Call.Return(_a0, _a1)
	return _c
}

func (_c *Consensus_LatestUnsafePayload_Call) RunAndReturn(run func() (*eth.ExecutionPayloadEnvelope, error)) *Consensus_LatestUnsafePayload_Call {
	_c.Call.Return(run)
	return _c
}

// Leader provides a mock function with given fields:
func (_m *Consensus) Leader() bool {
	ret := _m.Called()

	if len(ret) == 0 {
		panic("no return value specified for Leader")
	}

	var r0 bool
	if rf, ok := ret.Get(0).(func() bool); ok {
		r0 = rf()
	} else {
		r0 = ret.Get(0).(bool)
	}

	return r0
}

// Consensus_Leader_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'Leader'
type Consensus_Leader_Call struct {
	*mock.Call
}

// Leader is a helper method to define mock.On call
func (_e *Consensus_Expecter) Leader() *Consensus_Leader_Call {
	return &Consensus_Leader_Call{Call: _e.mock.On("Leader")}
}

func (_c *Consensus_Leader_Call) Run(run func()) *Consensus_Leader_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run()
	})
	return _c
}

func (_c *Consensus_Leader_Call) Return(_a0 bool) *Consensus_Leader_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Consensus_Leader_Call) RunAndReturn(run func() bool) *Consensus_Leader_Call {
	_c.Call.Return(run)
	return _c
}

// LeaderCh provides a mock function with given fields:
func (_m *Consensus) LeaderCh() <-chan bool {
	ret := _m.Called()

	if len(ret) == 0 {
		panic("no return value specified for LeaderCh")
	}

	var r0 <-chan bool
	if rf, ok := ret.Get(0).(func() <-chan bool); ok {
		r0 = rf()
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).(<-chan bool)
		}
	}

	return r0
}

// Consensus_LeaderCh_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'LeaderCh'
type Consensus_LeaderCh_Call struct {
	*mock.Call
}

// LeaderCh is a helper method to define mock.On call
func (_e *Consensus_Expecter) LeaderCh() *Consensus_LeaderCh_Call {
	return &Consensus_LeaderCh_Call{Call: _e.mock.On("LeaderCh")}
}

func (_c *Consensus_LeaderCh_Call) Run(run func()) *Consensus_LeaderCh_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run()
	})
	return _c
}

func (_c *Consensus_LeaderCh_Call) Return(_a0 <-chan bool) *Consensus_LeaderCh_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Consensus_LeaderCh_Call) RunAndReturn(run func() <-chan bool) *Consensus_LeaderCh_Call {
	_c.Call.Return(run)
	return _c
}

// LeaderWithID provides a mock function with given fields:
func (_m *Consensus) LeaderWithID() *consensus.ServerInfo {
	ret := _m.Called()

	if len(ret) == 0 {
		panic("no return value specified for LeaderWithID")
	}

	var r0 *consensus.ServerInfo
	if rf, ok := ret.Get(0).(func() *consensus.ServerInfo); ok {
		r0 = rf()
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).(*consensus.ServerInfo)
		}
	}

	return r0
}

// Consensus_LeaderWithID_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'LeaderWithID'
type Consensus_LeaderWithID_Call struct {
	*mock.Call
}

// LeaderWithID is a helper method to define mock.On call
func (_e *Consensus_Expecter) LeaderWithID() *Consensus_LeaderWithID_Call {
	return &Consensus_LeaderWithID_Call{Call: _e.mock.On("LeaderWithID")}
}

func (_c *Consensus_LeaderWithID_Call) Run(run func()) *Consensus_LeaderWithID_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run()
	})
	return _c
}

func (_c *Consensus_LeaderWithID_Call) Return(_a0 *consensus.ServerInfo) *Consensus_LeaderWithID_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Consensus_LeaderWithID_Call) RunAndReturn(run func() *consensus.ServerInfo) *Consensus_LeaderWithID_Call {
	_c.Call.Return(run)
	return _c
}

// RemoveServer provides a mock function with given fields: id, version
func (_m *Consensus) RemoveServer(id string, version uint64) error {
	ret := _m.Called(id, version)

	if len(ret) == 0 {
		panic("no return value specified for RemoveServer")
	}

	var r0 error
	if rf, ok := ret.Get(0).(func(string, uint64) error); ok {
		r0 = rf(id, version)
	} else {
		r0 = ret.Error(0)
	}

	return r0
}

// Consensus_RemoveServer_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'RemoveServer'
type Consensus_RemoveServer_Call struct {
	*mock.Call
}

// RemoveServer is a helper method to define mock.On call
//   - id string
//   - version uint64
func (_e *Consensus_Expecter) RemoveServer(id interface{}, version interface{}) *Consensus_RemoveServer_Call {
	return &Consensus_RemoveServer_Call{Call: _e.mock.On("RemoveServer", id, version)}
}

func (_c *Consensus_RemoveServer_Call) Run(run func(id string, version uint64)) *Consensus_RemoveServer_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(string), args[1].(uint64))
	})
	return _c
}

func (_c *Consensus_RemoveServer_Call) Return(_a0 error) *Consensus_RemoveServer_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Consensus_RemoveServer_Call) RunAndReturn(run func(string, uint64) error) *Consensus_RemoveServer_Call {
	_c.Call.Return(run)
	return _c
}

// ServerID provides a mock function with given fields:
func (_m *Consensus) ServerID() string {
	ret := _m.Called()

	if len(ret) == 0 {
		panic("no return value specified for ServerID")
	}

	var r0 string
	if rf, ok := ret.Get(0).(func() string); ok {
		r0 = rf()
	} else {
		r0 = ret.Get(0).(string)
	}

	return r0
}

// Consensus_ServerID_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'ServerID'
type Consensus_ServerID_Call struct {
	*mock.Call
}

// ServerID is a helper method to define mock.On call
func (_e *Consensus_Expecter) ServerID() *Consensus_ServerID_Call {
	return &Consensus_ServerID_Call{Call: _e.mock.On("ServerID")}
}

func (_c *Consensus_ServerID_Call) Run(run func()) *Consensus_ServerID_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run()
	})
	return _c
}

func (_c *Consensus_ServerID_Call) Return(_a0 string) *Consensus_ServerID_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Consensus_ServerID_Call) RunAndReturn(run func() string) *Consensus_ServerID_Call {
	_c.Call.Return(run)
	return _c
}

// Shutdown provides a mock function with given fields:
func (_m *Consensus) Shutdown() error {
	ret := _m.Called()

	if len(ret) == 0 {
		panic("no return value specified for Shutdown")
	}

	var r0 error
	if rf, ok := ret.Get(0).(func() error); ok {
		r0 = rf()
	} else {
		r0 = ret.Error(0)
	}

	return r0
}

// Consensus_Shutdown_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'Shutdown'
type Consensus_Shutdown_Call struct {
	*mock.Call
}

// Shutdown is a helper method to define mock.On call
func (_e *Consensus_Expecter) Shutdown() *Consensus_Shutdown_Call {
	return &Consensus_Shutdown_Call{Call: _e.mock.On("Shutdown")}
}

func (_c *Consensus_Shutdown_Call) Run(run func()) *Consensus_Shutdown_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run()
	})
	return _c
}

func (_c *Consensus_Shutdown_Call) Return(_a0 error) *Consensus_Shutdown_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Consensus_Shutdown_Call) RunAndReturn(run func() error) *Consensus_Shutdown_Call {
	_c.Call.Return(run)
	return _c
}

// TransferLeader provides a mock function with given fields:
func (_m *Consensus) TransferLeader() error {
	ret := _m.Called()

	if len(ret) == 0 {
		panic("no return value specified for TransferLeader")
	}

	var r0 error
	if rf, ok := ret.Get(0).(func() error); ok {
		r0 = rf()
	} else {
		r0 = ret.Error(0)
	}

	return r0
}

// Consensus_TransferLeader_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'TransferLeader'
type Consensus_TransferLeader_Call struct {
	*mock.Call
}

// TransferLeader is a helper method to define mock.On call
func (_e *Consensus_Expecter) TransferLeader() *Consensus_TransferLeader_Call {
	return &Consensus_TransferLeader_Call{Call: _e.mock.On("TransferLeader")}
}

func (_c *Consensus_TransferLeader_Call) Run(run func()) *Consensus_TransferLeader_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run()
	})
	return _c
}

func (_c *Consensus_TransferLeader_Call) Return(_a0 error) *Consensus_TransferLeader_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Consensus_TransferLeader_Call) RunAndReturn(run func() error) *Consensus_TransferLeader_Call {
	_c.Call.Return(run)
	return _c
}

// TransferLeaderTo provides a mock function with given fields: id, addr
func (_m *Consensus) TransferLeaderTo(id string, addr string) error {
	ret := _m.Called(id, addr)

	if len(ret) == 0 {
		panic("no return value specified for TransferLeaderTo")
	}

	var r0 error
	if rf, ok := ret.Get(0).(func(string, string) error); ok {
		r0 = rf(id, addr)
	} else {
		r0 = ret.Error(0)
	}

	return r0
}

// Consensus_TransferLeaderTo_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'TransferLeaderTo'
type Consensus_TransferLeaderTo_Call struct {
	*mock.Call
}

// TransferLeaderTo is a helper method to define mock.On call
//   - id string
//   - addr string
func (_e *Consensus_Expecter) TransferLeaderTo(id interface{}, addr interface{}) *Consensus_TransferLeaderTo_Call {
	return &Consensus_TransferLeaderTo_Call{Call: _e.mock.On("TransferLeaderTo", id, addr)}
}

func (_c *Consensus_TransferLeaderTo_Call) Run(run func(id string, addr string)) *Consensus_TransferLeaderTo_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(string), args[1].(string))
	})
	return _c
}

func (_c *Consensus_TransferLeaderTo_Call) Return(_a0 error) *Consensus_TransferLeaderTo_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Consensus_TransferLeaderTo_Call) RunAndReturn(run func(string, string) error) *Consensus_TransferLeaderTo_Call {
	_c.Call.Return(run)
	return _c
}

// NewConsensus creates a new instance of Consensus. It also registers a testing interface on the mock and a cleanup function to assert the mocks expectations.
// The first argument is typically a *testing.T value.
func NewConsensus(t interface {
	mock.TestingT
	Cleanup(func())
}) *Consensus {
	mock := &Consensus{}
	mock.Mock.Test(t)

	t.Cleanup(func() { mock.AssertExpectations(t) })

	return mock
}
