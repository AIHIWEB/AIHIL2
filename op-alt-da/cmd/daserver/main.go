package main

import (
	"context"
	"os"

	"github.com/ethereum/go-ethereum/log"
	"github.com/urfave/cli/v2"

	opservice "github.com/ethereum-AIHI/AIHI/op-service"
	"github.com/ethereum-AIHI/AIHI/op-service/cliapp"
	"github.com/ethereum-AIHI/AIHI/op-service/ctxinterrupt"
	oplog "github.com/ethereum-AIHI/AIHI/op-service/log"
)

var Version = "v0.0.0"

func main() {
	oplog.SetupDefaults()

	app := cli.NewApp()
	app.Flags = cliapp.ProtectFlags(Flags)
	app.Version = opservice.FormatVersion(Version, "", "", "")
	app.Name = "da-server"
	app.Usage = "AltDA Storage Service"
	app.Description = "Service for storing AltDA inputs"
	app.Action = StartDAServer

	ctx := ctxinterrupt.WithSignalWaiterMain(context.Background())
	err := app.RunContext(ctx, os.Args)
	if err != nil {
		log.Crit("Application failed", "message", err)
	}

}
