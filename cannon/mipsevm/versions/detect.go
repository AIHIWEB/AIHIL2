package versions

import (
	"fmt"
	"io"

	"github.com/ethereum-AIHI/AIHI/op-service/ioutil"
	"github.com/ethereum-AIHI/AIHI/op-service/serialize"
)

func DetectVersion(path string) (StateVersion, error) {
	if !serialize.IsBinaryFile(path) {
		return VersionSingleThreaded, nil
	}

	var f io.ReadCloser
	f, err := ioutil.OpenDecompressed(path)
	if err != nil {
		return 0, fmt.Errorf("failed to open file %q: %w", path, err)
	}
	defer f.Close()

	var ver StateVersion
	bin := serialize.NewBinaryReader(f)
	if err := bin.ReadUInt(&ver); err != nil {
		return 0, err
	}

	if !IsValidStateVersion(ver) {
		return 0, fmt.Errorf("%w: %d", ErrUnknownVersion, ver)
	}
	return ver, nil
}
