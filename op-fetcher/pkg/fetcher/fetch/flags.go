package fetch

import (
	oplog "github.com/ethereum-AIHI/AIHI/op-service/log"
	"github.com/urfave/cli/v2"
)

const EnvVarPrefix = "OP_FETCHER"

var GlobalFlags = append([]cli.Flag{}, oplog.CLIFlags(EnvVarPrefix)...)

var (
	L1RPCURLFlag = &cli.StringFlag{
		Name:     "l1-rpc-url",
		Usage:    "L1 RPC URL",
		Required: true,
	}
	SystemConfigProxyFlag = &cli.StringFlag{
		Name:     "system-config",
		Usage:    "contract address for SystemConfigProxy",
		Required: true,
	}
	L1StandardBridgeProxyFlag = &cli.StringFlag{
		Name:     "l1-standard-bridge",
		Usage:    "contract address for L1StandardBridgeProxy",
		Required: true,
	}
	OutputFileFlag = &cli.StringFlag{
		Name:     "output-file",
		Usage:    "file to write output json",
		Required: true,
	}
)

var FetchChainInfoFlags = []cli.Flag{
	L1RPCURLFlag,
	OutputFileFlag,
	SystemConfigProxyFlag,
	L1StandardBridgeProxyFlag,
}
