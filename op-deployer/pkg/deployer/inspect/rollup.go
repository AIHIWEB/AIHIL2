package inspect

import (
	"fmt"

	"github.com/ethereum-AIHI/AIHI/op-deployer/pkg/deployer/pipeline"

	"github.com/ethereum-AIHI/AIHI/op-service/ioutil"
	"github.com/ethereum-AIHI/AIHI/op-service/jsonutil"
	"github.com/urfave/cli/v2"
)

func RollupCLI(cliCtx *cli.Context) error {
	cfg, err := readConfig(cliCtx)
	if err != nil {
		return err
	}

	globalState, err := pipeline.ReadState(cfg.Workdir)
	if err != nil {
		return fmt.Errorf("failed to read intent: %w", err)
	}

	_, rollupConfig, err := pipeline.RenderGenesisAndRollup(globalState, cfg.ChainID, nil)
	if err != nil {
		return fmt.Errorf("failed to generate rollup config: %w", err)
	}

	if rollupConfig.HoloceneTime == nil {
		rollupConfig.Genesis.SystemConfig.MarshalPreHolocene = true
	}

	if err := jsonutil.WriteJSON(rollupConfig, ioutil.ToStdOutOrFileOrNoop(cfg.Outfile, 0o666)); err != nil {
		return fmt.Errorf("failed to write rollup config: %w", err)
	}

	return nil
}
