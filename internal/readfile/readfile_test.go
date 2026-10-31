package readfile_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/readfile"
)

const (
	content  = "hello"
	fileName = "a.txt"
	fileMode = 0o600
)

func TestReadReturnsTheContent(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	path := filepath.Join(dir, fileName)

	err := os.WriteFile(path, []byte(content), fileMode)
	if err != nil {
		t.Fatalf("cannot write %q: %v", path, err)
	}

	got, err := readfile.Read(path)
	if err != nil {
		t.Fatalf("Read() error = %v", err)
	}

	if string(got) != content {
		t.Errorf("Read() = %q, want %q", got, content)
	}
}

func TestReadFailsOnAMissingFile(t *testing.T) {
	t.Parallel()

	path := filepath.Join(t.TempDir(), fileName)

	_, err := readfile.Read(path)
	if err == nil {
		t.Error("Read() error = nil, want an error")
	}
}
