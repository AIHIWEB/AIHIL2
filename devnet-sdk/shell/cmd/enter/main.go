package main

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/ethereum-AIHI/AIHI/devnet-sdk/shell/env"
	"github.com/urfave/cli/v2"
)

func run(ctx *cli.Context) error {
	devnetURL := ctx.String("devnet")
	chainName := ctx.String("chain")
	nodeIndex := ctx.Int("node-index")

	devnetEnv, err := env.LoadDevnetFromURL(devnetURL)
	if err != nil {
		return err
	}

	chain, err := devnetEnv.GetChain(chainName)
	if err != nil {
		return err
	}

	chainEnv, err := chain.GetEnv(
		env.WithCastIntegration(true, nodeIndex),
	)
	if err != nil {
		return err
	}

	if motd := chainEnv.GetMotd(); motd != "" {
		fmt.Println(motd)
	}

	// Get current environment and append chain-specific vars
	env := chainEnv.ApplyToEnv(os.Environ())

	// Get current shell
	shell := os.Getenv("SHELL")
	if shell == "" {
		shell = "/bin/sh"
	}

	// Execute new shell
	cmd := exec.Command(shell)
	cmd.Env = env
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("error executing shell: %w", err)
	}

	return nil
}

func main() {
	app := &cli.App{
		Name:  "enter",
		Usage: "Enter a shell with devnet environment variables set",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:     "devnet",
				Usage:    "URL to devnet JSON file",
				EnvVars:  []string{env.EnvURLVar},
				Required: true,
			},
			&cli.StringFlag{
				Name:     "chain",
				Usage:    "Name of the chain to connect to",
				EnvVars:  []string{env.ChainNameVar},
				Required: true,
			},
			&cli.IntFlag{
				Name:     "node-index",
				Usage:    "Index of the node to connect to (default: 0)",
				EnvVars:  []string{env.NodeIndexVar},
				Required: false,
				Value:    0,
			},
		},
		Action: run,
	}

	if err := app.Run(os.Args); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
