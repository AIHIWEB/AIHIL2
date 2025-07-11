package main

import (
	"context"
	"os"

	"github.com/ethereum-AIHI/AIHI/op-service/ctxinterrupt"

	opservice "github.com/ethereum-AIHI/AIHI/op-service"
	"github.com/urfave/cli/v2"

	"github.com/ethereum-AIHI/AIHI/op-proposer/flags"
	"github.com/ethereum-AIHI/AIHI/op-proposer/metrics"
	"github.com/ethereum-AIHI/AIHI/op-proposer/proposer"
	"github.com/ethereum-AIHI/AIHI/op-service/cliapp"
	oplog "github.com/ethereum-AIHI/AIHI/op-service/log"
	"github.com/ethereum-AIHI/AIHI/op-service/metrics/doc"
	"github.com/ethereum/go-ethereum/log"
)

var (
	Version   = "v0.0.0"
	GitCommit = ""
	GitDate   = ""
)

func main() {
	oplog.SetupDefaults()

	app := cli.NewApp()
	app.Flags = cliapp.ProtectFlags(flags.Flags)
	app.Version = opservice.FormatVersion(Version, GitCommit, GitDate, "")
	app.Name = "op-proposer"
	app.Usage = "L2 Output Submitter"
	app.Description = "Service for generating and proposing L2 Outputs"
	app.Action = cliapp.LifecycleCmd(proposer.Main(Version))
	app.Commands = []*cli.Command{
		{
			Name:        "doc",
			Subcommands: doc.NewSubcommands(metrics.NewMetrics("default")),
		},
	}

	ctx := ctxinterrupt.WithSignalWaiterMain(context.Background())
	err := app.RunContext(ctx, os.Args)
	if err != nil {
		log.Crit("Application failed", "message", err)
	}
}
