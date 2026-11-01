package manifest_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/manifest"
)

const (
	pluginDir   = "plugins"
	fileName    = "plugin.json"
	fileMode    = 0o600
	dirMode     = 0o750
	readError   = "Read() error = %v"
	pluginName  = "Channel to Fixture"
	slotNumber  = 101
	pluginCount = 2
)

const sampleText = `{
  "name": "Channel to Fixture",
  "file": "k-channel-to-fixture",
  "version": "0.2.0",
  "slot": 101
}
`

func write(t *testing.T, path string, text string) {
	t.Helper()

	err := os.MkdirAll(filepath.Dir(path), dirMode)
	if err != nil {
		t.Fatalf("cannot create the folder for %q: %v", path, err)
	}

	err = os.WriteFile(path, []byte(text), fileMode)
	if err != nil {
		t.Fatalf("cannot write %q: %v", path, err)
	}
}

func pluginPath(root string, name string) string {
	return filepath.Join(root, pluginDir, name, fileName)
}

func TestReadReadsTheManifest(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	path := pluginPath(root, "channel-to-fixture")
	write(t, path, sampleText)

	got, err := manifest.Read(path)
	if err != nil {
		t.Fatalf(readError, err)
	}

	want := manifest.Manifest{
		Name:    pluginName,
		File:    "k-channel-to-fixture",
		Version: "0.2.0",
		Slot:    slotNumber,
	}

	if got != want {
		t.Errorf("Read() = %+v, want %+v", got, want)
	}
}

func TestReadFailsOnAMissingFile(t *testing.T) {
	t.Parallel()

	_, err := manifest.Read(pluginPath(t.TempDir(), "nothing"))
	if err == nil {
		t.Error("Read() error = nil, want an error")
	}
}

func TestReadFailsOnBrokenJson(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	path := pluginPath(root, "broken")
	write(t, path, "{name = }")

	_, err := manifest.Read(path)
	if err == nil {
		t.Error("Read() error = nil, want an error")
	}
}

func writePlugin(t *testing.T, root string, name string) {
	t.Helper()

	folder := filepath.Join(root, pluginDir, name)

	err := os.MkdirAll(folder, dirMode)
	if err != nil {
		t.Fatalf("cannot create the folder: %v", err)
	}

	write(t, pluginPath(root, name), sampleText)
}

func TestReadAllReadsEveryPlugin(t *testing.T) {
	t.Parallel()

	root := t.TempDir()

	for _, name := range []string{"one", "two"} {
		writePlugin(t, root, name)
	}

	got, err := manifest.ReadAll(root)
	if err != nil {
		t.Fatalf(readError, err)
	}

	if len(got) != pluginCount {
		t.Fatalf("ReadAll() = %d manifests, want %d", len(got), pluginCount)
	}

	for _, one := range got {
		if one.Name != pluginName {
			t.Errorf("Name = %q, want %q", one.Name, pluginName)
		}
	}
}

func TestFormatWritesTheJson(t *testing.T) {
	t.Parallel()

	got, err := manifest.Format(manifest.Manifest{
		Name:    pluginName,
		File:    "k-channel-to-fixture",
		Version: "0.2.0",
		Slot:    slotNumber,
	})
	if err != nil {
		t.Fatalf("Format() error = %v", err)
	}

	if string(got) != sampleText {
		t.Errorf("Format() =\n%s\nwant\n%s", got, sampleText)
	}
}
