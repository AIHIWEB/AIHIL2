package sysgo

import (
	"context"
	"sync"

	"github.com/ethereum-AIHI/AIHI/devnet-sdk/devstack/devtest"
	"github.com/ethereum/go-ethereum/log"

	"github.com/ethereum-AIHI/AIHI/devnet-sdk/devstack/shim"
	"github.com/ethereum-AIHI/AIHI/devnet-sdk/devstack/stack"
	"github.com/ethereum-AIHI/AIHI/op-service/client"
	oplog "github.com/ethereum-AIHI/AIHI/op-service/log"
	"github.com/ethereum-AIHI/AIHI/op-service/metrics"
	"github.com/ethereum-AIHI/AIHI/op-service/oppprof"
	"github.com/ethereum-AIHI/AIHI/op-service/retry"
	oprpc "github.com/ethereum-AIHI/AIHI/op-service/rpc"
	"github.com/ethereum-AIHI/AIHI/op-service/sources"
	supervisorConfig "github.com/ethereum-AIHI/AIHI/op-supervisor/config"
	"github.com/ethereum-AIHI/AIHI/op-supervisor/supervisor"
	"github.com/ethereum-AIHI/AIHI/op-supervisor/supervisor/backend/syncnode"
)

type Supervisor struct {
	mu sync.Mutex

	id      stack.SupervisorID
	userRPC string

	cfg    *supervisorConfig.Config
	p      devtest.P
	logger log.Logger

	service *supervisor.SupervisorService
}

var _ stack.Lifecycle = (*Supervisor)(nil)

func (s *Supervisor) hydrate(sys stack.ExtensibleSystem) {
	tlog := sys.Logger().New("id", s.id)
	supClient, err := client.NewRPC(sys.T().Ctx(), tlog, s.userRPC, client.WithLazyDial())
	sys.T().Require().NoError(err)
	sys.T().Cleanup(supClient.Close)

	sys.AddSupervisor(shim.NewSupervisor(shim.SupervisorConfig{
		CommonConfig: shim.NewCommonConfig(sys.T()),
		ID:           s.id,
		Client:       supClient,
	}))
}

func (s *Supervisor) rememberPort() {
	port, err := s.service.Port()
	s.p.Require().NoError(err)
	s.cfg.RPC.ListenPort = port
}

func (s *Supervisor) Start() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.service != nil {
		s.logger.Warn("Supervisor already started")
		return
	}
	super, err := supervisor.SupervisorFromConfig(context.Background(), s.cfg, s.logger)
	s.p.Require().NoError(err)

	s.service = super
	s.logger.Info("Starting supervisor")
	err = super.Start(context.Background())
	s.p.Require().NoError(err, "supervisor failed to start")
	s.logger.Info("Started supervisor")

	s.userRPC = super.RPC()

	s.rememberPort()
}

func (s *Supervisor) Stop() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.service == nil {
		s.logger.Warn("Supervisor already stopped")
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel() // force-quit
	s.logger.Info("Closing supervisor")
	closeErr := s.service.Stop(ctx)
	s.logger.Info("Closed supervisor", "err", closeErr)

	s.service = nil
}

func WithSupervisor(supervisorID stack.SupervisorID, clusterID stack.ClusterID, l1ELID stack.L1ELNodeID) stack.Option {
	return func(o stack.Orchestrator) {
		orch := o.(*Orchestrator)
		require := orch.P().Require()

		l1EL, ok := orch.l1ELs.Get(l1ELID)
		require.True(ok, "need L1 EL node to connect supervisor to")

		cluster, ok := orch.clusters.Get(clusterID)
		require.True(ok, "need cluster to determine dependency set")

		cfg := &supervisorConfig.Config{
			MetricsConfig: metrics.CLIConfig{
				Enabled: false,
			},
			PprofConfig: oppprof.CLIConfig{
				ListenEnabled: false,
			},
			LogConfig: oplog.CLIConfig{ // ignored, logger overrides this
				Level:  log.LevelDebug,
				Format: oplog.FormatText,
			},
			RPC: oprpc.CLIConfig{
				ListenAddr: "127.0.0.1",
				// When supervisor starts, store its RPC port here
				// given by the os, to reclaim when restart.
				ListenPort:  0,
				EnableAdmin: true,
			},
			SyncSources: &syncnode.CLISyncNodes{}, // no sync-sources
			L1RPC:       l1EL.userRPC,
			// Note: datadir is created here,
			// persistent across stop/start, for the duration of the package execution.
			Datadir:               orch.p.TempDir(),
			Version:               "dev",
			DependencySetSource:   cluster.depset,
			MockRun:               false,
			SynchronousProcessors: false,
			DatadirSyncEndpoint:   "",
		}

		plog := orch.P().Logger().New("id", supervisorID)

		supervisorNode := &Supervisor{
			id:      supervisorID,
			userRPC: "", // set on start
			cfg:     cfg,
			p:       o.P(),
			logger:  plog,
			service: nil, // set on start
		}
		orch.supervisors.Set(supervisorID, supervisorNode)
		supervisorNode.Start()
		orch.p.Cleanup(supervisorNode.Stop)
	}
}

func WithManagedBySupervisor(l2CLID stack.L2CLNodeID, supervisorID stack.SupervisorID) stack.Option {
	return func(o stack.Orchestrator) {
		orch := o.(*Orchestrator)
		require := orch.P().Require()

		l2CL, ok := orch.l2CLs.Get(l2CLID)
		require.True(ok, "looking for L2 CL node to connect to supervisor")
		interopEndpoint, secret := l2CL.opNode.InteropRPC()

		s, ok := orch.supervisors.Get(supervisorID)
		require.True(ok, "looking for supervisor")

		ctx := o.P().Ctx()
		rpcClient, err := client.NewRPC(ctx, o.P().Logger(), s.userRPC, client.WithLazyDial())
		o.P().Require().NoError(err)
		supClient := sources.NewSupervisorClient(rpcClient)

		err = retry.Do0(ctx, 10, retry.Exponential(), func() error {
			return supClient.AddL2RPC(ctx, interopEndpoint, secret)
		})
		require.NoError(err, "must connect CL node %s to supervisor %s", l2CLID, supervisorID)
	}
}
