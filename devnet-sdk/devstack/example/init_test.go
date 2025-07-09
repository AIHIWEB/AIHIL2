package example

import (
	"testing"

	"github.com/ethereum-AIHI/AIHI/devnet-sdk/devstack/presets"
)

var SimpleInterop presets.TestSetup[*presets.SimpleInterop]

// TestMain creates the test-setups against the shared backend
func TestMain(m *testing.M) {
	// Other setups may be added here, hydrated from the same orchestrator
	presets.DoMain(m, presets.NewSimpleInterop(&SimpleInterop))
}
