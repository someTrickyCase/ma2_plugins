package packageout_test

import (
	"os"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/packageout"
)

const (
	fileMode = 0o600
	dirMode  = 0o750
	newData  = "new"
	oldName  = "obsolete"
)

func assertExists(t *testing.T, path string) {
	t.Helper()

	_, err := os.Stat(path)
	if err != nil {
		t.Fatalf("expected %s: %v", path, err)
	}
}

func assertMissing(t *testing.T, path string) {
	t.Helper()

	_, err := os.Stat(path)
	if !os.IsNotExist(err) {
		t.Fatalf("unexpected %s: %v", path, err)
	}
}

func write(t *testing.T, path string, data string) {
	t.Helper()

	err := os.WriteFile(path, []byte(data), fileMode)
	if err != nil {
		t.Fatal(err)
	}
}

func TestPromoteReplacesOnlyCompletePackage(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	target := filepath.Join(root, "dist", "bundle")

	err := os.MkdirAll(target, dirMode)
	if err != nil {
		t.Fatal(err)
	}

	write(t, filepath.Join(target, oldName), "old")

	err = packageout.Prepare(root)
	if err != nil {
		t.Fatal(err)
	}

	stage := filepath.Join(root, "dist", "bundle-stage")
	manifestText := `{"plugins":[{"name":"Answer",` +
		`"file":"k-answer","version":"1","slot":1}]}`
	write(t, filepath.Join(stage, "plugins.json"), manifestText)
	write(t, filepath.Join(stage, "k-answer.lua"), newData)
	write(t, filepath.Join(stage, "k-answer.xml"), newData)

	err = packageout.Promote(root)
	if err == nil {
		t.Fatal("incomplete package was promoted")
	}

	assertExists(t, filepath.Join(target, oldName))

	installer := "install"
	if runtime.GOOS == "windows" {
		installer += ".exe"
	}

	write(t, filepath.Join(stage, installer), newData)

	err = packageout.Promote(root)
	if err != nil {
		t.Fatal(err)
	}

	assertMissing(t, filepath.Join(target, oldName))
	assertExists(t, filepath.Join(target, "k-answer.lua"))
}
