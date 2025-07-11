package interfaces

import (
	"context"
	"encoding/json"
	"io"

	"github.com/ethereum-AIHI/AIHI/kurtosis-devnet/pkg/kurtosis/sources/deployer"
	"github.com/ethereum-AIHI/AIHI/kurtosis-devnet/pkg/kurtosis/sources/inspect"
	"github.com/ethereum-AIHI/AIHI/kurtosis-devnet/pkg/kurtosis/sources/jwt"
	"github.com/ethereum-AIHI/AIHI/kurtosis-devnet/pkg/kurtosis/sources/spec"
)

type EnclaveSpecifier interface {
	EnclaveSpec(io.Reader) (*spec.EnclaveSpec, error)
}

type EnclaveInspecter interface {
	EnclaveInspect(context.Context, string) (*inspect.InspectData, error)
}

type EnclaveObserver interface {
	EnclaveObserve(context.Context, string) (*deployer.DeployerData, error)
}

type JWTExtractor interface {
	ExtractData(context.Context, string) (*jwt.Data, error)
}

type DepsetExtractor interface {
	ExtractData(context.Context, string) (json.RawMessage, error)
}
