package interop

import (
	"os"

	oplog "github.com/ethereum-AIHI/AIHI/op-service/log"
	"github.com/ethereum/go-ethereum/log"
)

func init() {
	oplog.SetGlobalLogHandler(log.NewTerminalHandlerWithLevel(os.Stderr, log.LevelDebug, true))
}
