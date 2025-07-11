package challenger

import (
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/ethereum-AIHI/AIHI/op-service/crypto"
	"github.com/ethereum-AIHI/AIHI/op-supervisor/supervisor/backend/depset"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/stretchr/testify/require"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/log"

	challenger "github.com/ethereum-AIHI/AIHI/op-challenger"
	"github.com/ethereum-AIHI/AIHI/op-challenger/config"
	"github.com/ethereum-AIHI/AIHI/op-challenger/game/fault/types"
	"github.com/ethereum-AIHI/AIHI/op-e2e/e2eutils/wait"
	"github.com/ethereum-AIHI/AIHI/op-node/rollup"
	"github.com/ethereum-AIHI/AIHI/op-service/cliapp"
	"github.com/ethereum-AIHI/AIHI/op-service/endpoint"
	"github.com/ethereum-AIHI/AIHI/op-service/metrics"
	"github.com/ethereum-AIHI/AIHI/op-service/testlog"
)

type PrestateVariant string

const (
	STCannonVariant PrestateVariant = ""
	MTCannonVariant PrestateVariant = "mt64"
	InteropVariant  PrestateVariant = "interop"
)

type EndpointProvider interface {
	NodeEndpoint(name string) endpoint.RPC
	L2NodeEndpoints() []endpoint.RPC
	RollupEndpoint(name string) endpoint.RPC
	L1BeaconEndpoint() endpoint.RestHTTP
	SupervisorEndpoint() endpoint.RPC
	IsSupersystem() bool
}

type System interface {
	RollupCfgs() []*rollup.Config
	L2Geneses() []*core.Genesis
	PrestateVariant() PrestateVariant
}
type Helper struct {
	log     log.Logger
	t       *testing.T
	require *require.Assertions
	dir     string
	chl     cliapp.Lifecycle
	metrics *CapturingMetrics
}

func NewHelper(log log.Logger, t *testing.T, require *require.Assertions, dir string, chl cliapp.Lifecycle, m *CapturingMetrics) *Helper {
	return &Helper{
		log:     log,
		t:       t,
		require: require,
		dir:     dir,
		chl:     chl,
		metrics: m,
	}
}

type Option func(c *config.Config)

func WithFactoryAddress(addr common.Address) Option {
	return func(c *config.Config) {
		c.GameFactoryAddress = addr
	}
}

func WithGameAddress(addr common.Address) Option {
	return func(c *config.Config) {
		c.GameAllowlist = append(c.GameAllowlist, addr)
	}
}

func WithPrivKey(key *ecdsa.PrivateKey) Option {
	return func(c *config.Config) {
		c.TxMgrConfig.PrivateKey = crypto.EncodePrivKeyToString(key)
	}
}

func WithPollInterval(pollInterval time.Duration) Option {
	return func(c *config.Config) {
		c.PollInterval = pollInterval
	}
}

func WithValidPrestateRequired() Option {
	return func(c *config.Config) {
		c.AllowInvalidPrestate = false
	}
}

func WithInvalidCannonPrestate() Option {
	return func(c *config.Config) {
		c.CannonAbsolutePreState = "/tmp/not-a-real-prestate.foo"
	}
}

func WithDepset(t *testing.T, ds *depset.StaticConfigDependencySet) Option {
	return func(c *config.Config) {
		b, err := ds.MarshalJSON()
		require.NoError(t, err)
		path := filepath.Join(t.TempDir(), "challenger-depset.json")
		require.NoError(t, os.WriteFile(path, b, 0o644))
		c.Cannon.DepsetConfigPath = path
	}
}

// FindMonorepoRoot finds the relative path to the monorepo root
// Different tests might be nested in subdirectories of the op-e2e dir.
func FindMonorepoRoot(t *testing.T) string {
	path := "./"
	// Only search up 5 directories
	// Avoids infinite recursion if the root isn't found for some reason
	for i := 0; i < 5; i++ {
		_, err := os.Stat(path + "op-e2e")
		if errors.Is(err, os.ErrNotExist) {
			path = path + "../"
			continue
		}
		require.NoErrorf(t, err, "Failed to stat %v even though it existed", path)
		return path
	}
	t.Fatalf("Could not find monorepo root, trying up to %v", path)
	return ""
}

func applyCannonConfig(c *config.Config, t *testing.T, rollupCfgs []*rollup.Config, l2Geneses []*core.Genesis, prestateVariant PrestateVariant) {
	require := require.New(t)
	root := FindMonorepoRoot(t)
	c.Cannon.VmBin = root + "cannon/bin/cannon"
	c.Cannon.Server = root + "op-program/bin/op-program"
	t.Logf("Using absolute prestate variant %v", prestateVariant)
	if prestateVariant != "" {
		c.CannonAbsolutePreState = root + "op-program/bin/prestate-" + string(prestateVariant) + ".bin.gz"
	} else {
		c.CannonAbsolutePreState = root + "op-program/bin/prestate.bin.gz"
	}
	c.Cannon.SnapshotFreq = 10_000_000

	for _, l2Genesis := range l2Geneses {
		genesisBytes, err := json.Marshal(l2Genesis)
		require.NoError(err, "marshall l2 genesis config")
		genesisFile := filepath.Join(c.Datadir, fmt.Sprintf("l2-genesis-%v.json", l2Genesis.Config.ChainID))
		require.NoError(os.WriteFile(genesisFile, genesisBytes, 0o644))
		c.Cannon.L2GenesisPaths = append(c.Cannon.L2GenesisPaths, genesisFile)
	}

	for _, rollupCfg := range rollupCfgs {
		rollupBytes, err := json.Marshal(rollupCfg)
		require.NoError(err, "marshall rollup config")
		rollupFile := filepath.Join(c.Datadir, fmt.Sprintf("rollup-%v.json", rollupCfg.L2ChainID))
		require.NoError(os.WriteFile(rollupFile, rollupBytes, 0o644))
		c.Cannon.RollupConfigPaths = append(c.Cannon.RollupConfigPaths, rollupFile)
	}
}

func WithCannon(t *testing.T, system System) Option {
	return func(c *config.Config) {
		c.TraceTypes = append(c.TraceTypes, types.TraceTypeCannon)
		applyCannonConfig(c, t, system.RollupCfgs(), system.L2Geneses(), system.PrestateVariant())
	}
}

func WithPermissioned(t *testing.T, system System) Option {
	return func(c *config.Config) {
		c.TraceTypes = append(c.TraceTypes, types.TraceTypePermissioned)
		applyCannonConfig(c, t, system.RollupCfgs(), system.L2Geneses(), system.PrestateVariant())
	}
}

func WithSuperCannon(t *testing.T, system System) Option {
	return func(c *config.Config) {
		c.TraceTypes = append(c.TraceTypes, types.TraceTypeSuperCannon)
		applyCannonConfig(c, t, system.RollupCfgs(), system.L2Geneses(), system.PrestateVariant())
	}
}

func WithSuperPermissioned(t *testing.T, system System) Option {
	return func(c *config.Config) {
		c.TraceTypes = append(c.TraceTypes, types.TraceTypeSuperPermissioned)
		applyCannonConfig(c, t, system.RollupCfgs(), system.L2Geneses(), system.PrestateVariant())
	}
}

func WithAlphabet() Option {
	return func(c *config.Config) {
		c.TraceTypes = append(c.TraceTypes, types.TraceTypeAlphabet)
	}
}

func WithFastGames() Option {
	return func(c *config.Config) {
		c.TraceTypes = append(c.TraceTypes, types.TraceTypeFast)
	}
}

func NewChallenger(t *testing.T, ctx context.Context, sys EndpointProvider, name string, options ...Option) *Helper {
	log := testlog.Logger(t, log.LevelDebug).New("role", name)
	log.Info("Creating challenger")
	cfg := NewChallengerConfig(t, sys, "sequencer", options...)
	cfg.MetricsConfig.Enabled = false // Don't start the metrics server
	m := NewCapturingMetrics()
	chl, err := challenger.Main(ctx, log, cfg, m)
	require.NoError(t, err, "must init challenger")
	require.NoError(t, chl.Start(ctx), "must start challenger")

	return NewHelper(log, t, require.New(t), cfg.Datadir, chl, m)
}

func NewChallengerConfig(t *testing.T, sys EndpointProvider, l2NodeName string, options ...Option) *config.Config {
	// Use the NewConfig method to ensure we pick up any defaults that are set.
	l1Endpoint := sys.NodeEndpoint("l1").RPC()
	l1Beacon := sys.L1BeaconEndpoint().RestHTTP()
	var cfg config.Config
	if sys.IsSupersystem() {
		var l2Endpoints []string
		for _, l2Node := range sys.L2NodeEndpoints() {
			l2Endpoints = append(l2Endpoints, l2Node.RPC())
		}
		cfg = config.NewInteropConfig(common.Address{}, l1Endpoint, l1Beacon, sys.SupervisorEndpoint().RPC(), l2Endpoints, t.TempDir())
	} else {
		cfg = config.NewConfig(common.Address{}, l1Endpoint, l1Beacon, sys.RollupEndpoint(l2NodeName).RPC(), sys.NodeEndpoint(l2NodeName).RPC(), t.TempDir())
	}
	cfg.Cannon.L2Custom = true
	// The devnet can't set the absolute prestate output root because the contracts are deployed in L1 genesis
	// before the L2 genesis is known.
	cfg.AllowInvalidPrestate = true
	cfg.TxMgrConfig.NumConfirmations = 1
	cfg.TxMgrConfig.ReceiptQueryInterval = 1 * time.Second
	if cfg.MaxConcurrency > 4 {
		// Limit concurrency to something more reasonable when there are also multiple tests executing in parallel
		cfg.MaxConcurrency = 4
	}
	cfg.MetricsConfig = metrics.CLIConfig{
		Enabled:    true,
		ListenAddr: "127.0.0.1",
		ListenPort: 0, // Find any available port (avoids conflicts)
	}
	for _, option := range options {
		option(&cfg)
	}
	require.NotEmpty(t, cfg.TxMgrConfig.PrivateKey, "Missing private key for TxMgrConfig")
	require.NoError(t, cfg.Check(), "op-challenger config should be valid")

	if cfg.Cannon.VmBin != "" {
		_, err := os.Stat(cfg.Cannon.VmBin)
		require.NoError(t, err, "cannon should be built. Make sure you've run make cannon-prestate")
	}
	if cfg.Cannon.Server != "" {
		_, err := os.Stat(cfg.Cannon.Server)
		require.NoError(t, err, "op-program should be built. Make sure you've run make cannon-prestate")
	}
	if cfg.CannonAbsolutePreState != "" {
		_, err := os.Stat(cfg.CannonAbsolutePreState)
		require.NoError(t, err, "cannon pre-state should be built. Make sure you've run make cannon-prestate")
	}
	if cfg.PollInterval == 0 {
		cfg.PollInterval = time.Second
	}

	return &cfg
}

func (h *Helper) Close() error {
	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()
	return h.chl.Stop(ctx)
}

type GameAddr interface {
	Addr() common.Address
}

func (h *Helper) VerifyGameDataExists(games ...GameAddr) {
	for _, game := range games {
		addr := game.Addr()
		h.require.DirExistsf(h.gameDataDir(addr), "should have data for game %v", addr)
	}
}

func (h *Helper) WaitForGameDataDeletion(ctx context.Context, games ...GameAddr) {
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	err := wait.For(ctx, time.Second, func() (bool, error) {
		for _, game := range games {
			addr := game.Addr()
			dir := h.gameDataDir(addr)
			_, err := os.Stat(dir)
			if errors.Is(err, os.ErrNotExist) {
				// This game has been successfully deleted
				continue
			}
			if err != nil {
				return false, fmt.Errorf("failed to check dir %v is deleted: %w", dir, err)
			}
			h.t.Logf("Game data directory %v not yet deleted", dir)
			return false, nil
		}
		return true, nil
	})
	h.require.NoErrorf(err, "should have deleted game data directories")
}

func (h *Helper) gameDataDir(addr common.Address) string {
	return filepath.Join(h.dir, "game-"+addr.Hex())
}

func (h *Helper) WaitL1HeadActedOn(ctx context.Context, client *ethclient.Client) {
	l1Head, err := client.BlockNumber(ctx)
	h.require.NoError(err)
	h.WaitForHighestActedL1Block(ctx, l1Head)
}

func (h *Helper) WaitForHighestActedL1Block(ctx context.Context, head uint64) {
	timedCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	var actual uint64
	err := wait.For(timedCtx, time.Second, func() (bool, error) {
		actual = h.metrics.HighestActedL1Block.Load()
		h.log.Info("Waiting for highest acted L1 block", "target", head, "actual", actual)
		return actual >= head, nil
	})
	h.require.NoErrorf(err, "Highest acted L1 block did not reach %v, was: %v", head, actual)
}
