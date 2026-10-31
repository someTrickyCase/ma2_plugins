package readfile

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
)

func Read(path string) ([]byte, error) {
	folder := filepath.Dir(path)
	name := filepath.Base(path)

	data, err := fs.ReadFile(os.DirFS(folder), name)
	if err != nil {
		return nil, fmt.Errorf("cannot read %q: %w", path, err)
	}

	return data, nil
}
