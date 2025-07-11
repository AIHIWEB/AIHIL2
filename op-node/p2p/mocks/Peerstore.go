// Code generated by mockery v2.46.0. DO NOT EDIT.

package mocks

import (
	mock "github.com/stretchr/testify/mock"

	peer "github.com/libp2p/go-libp2p/core/peer"

	store "github.com/ethereum-AIHI/AIHI/op-node/p2p/store"
)

// Peerstore is an autogenerated mock type for the Peerstore type
type Peerstore struct {
	mock.Mock
}

// PeerInfo provides a mock function with given fields: _a0
func (_m *Peerstore) PeerInfo(_a0 peer.ID) peer.AddrInfo {
	ret := _m.Called(_a0)

	if len(ret) == 0 {
		panic("no return value specified for PeerInfo")
	}

	var r0 peer.AddrInfo
	if rf, ok := ret.Get(0).(func(peer.ID) peer.AddrInfo); ok {
		r0 = rf(_a0)
	} else {
		r0 = ret.Get(0).(peer.AddrInfo)
	}

	return r0
}

// Peers provides a mock function with given fields:
func (_m *Peerstore) Peers() peer.IDSlice {
	ret := _m.Called()

	if len(ret) == 0 {
		panic("no return value specified for Peers")
	}

	var r0 peer.IDSlice
	if rf, ok := ret.Get(0).(func() peer.IDSlice); ok {
		r0 = rf()
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).(peer.IDSlice)
		}
	}

	return r0
}

// SetScore provides a mock function with given fields: id, diff
func (_m *Peerstore) SetScore(id peer.ID, diff store.ScoreDiff) (store.PeerScores, error) {
	ret := _m.Called(id, diff)

	if len(ret) == 0 {
		panic("no return value specified for SetScore")
	}

	var r0 store.PeerScores
	var r1 error
	if rf, ok := ret.Get(0).(func(peer.ID, store.ScoreDiff) (store.PeerScores, error)); ok {
		return rf(id, diff)
	}
	if rf, ok := ret.Get(0).(func(peer.ID, store.ScoreDiff) store.PeerScores); ok {
		r0 = rf(id, diff)
	} else {
		r0 = ret.Get(0).(store.PeerScores)
	}

	if rf, ok := ret.Get(1).(func(peer.ID, store.ScoreDiff) error); ok {
		r1 = rf(id, diff)
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// NewPeerstore creates a new instance of Peerstore. It also registers a testing interface on the mock and a cleanup function to assert the mocks expectations.
// The first argument is typically a *testing.T value.
func NewPeerstore(t interface {
	mock.TestingT
	Cleanup(func())
}) *Peerstore {
	mock := &Peerstore{}
	mock.Mock.Test(t)

	t.Cleanup(func() { mock.AssertExpectations(t) })

	return mock
}
