package scaffold_test

import (
	"os"
	"path/filepath"
	"strconv"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/readfile"
	"github.com/someTrickyCase/ma2_plugins/internal/scaffold"
)

const (
	manifestName = "plugin.lua"
	pluginName   = "my-plugin"
	pluginTitle  = "My Plugin"
	pluginDir    = "plugins"
	newErrorText = "New() error = %v"
	firstSlot    = 101
	secondSlot   = firstSlot + 1
	thirdSlot    = firstSlot + 2
	dirMode      = 0o750
	fileMode     = 0o600
)

func readFile(t *testing.T, path string) string {
	t.Helper()

	text, err := readfile.Read(path)
	if err != nil {
		t.Fatalf("cannot read %q: %v", path, err)
	}

	return string(text)
}

func writeManifest(t *testing.T, root string, name string, slot int) {
	t.Helper()

	folder := filepath.Join(root, pluginDir, name)

	err := os.MkdirAll(folder, dirMode)
	if err != nil {
		t.Fatalf("cannot create %q: %v", folder, err)
	}

	path := filepath.Join(folder, manifestName)
	text := "return {\n  name = \"x\",\n  slot = " +
		strconv.Itoa(slot) + ",\n}\n"

	err = os.WriteFile(path, []byte(text), fileMode)
	if err != nil {
		t.Fatalf("cannot write %q: %v", path, err)
	}
}

func expectFiles(t *testing.T, root string, name string) {
	t.Helper()

	paths := []string{
		filepath.Join(root, pluginDir, name, manifestName),
		filepath.Join(root, pluginDir, name, "main.lua"),
		filepath.Join(root, "test", pluginDir, name, "main.test.lua"),
	}

	for _, path := range paths {
		_, err := os.Stat(path)
		if err != nil {
			t.Errorf("missing %q: %v", path, err)
		}
	}
}

func TestNewCreatesTheThreeFiles(t *testing.T) {
	t.Parallel()

	root := t.TempDir()

	got, err := scaffold.New(root, pluginName)
	if err != nil {
		t.Fatalf(newErrorText, err)
	}

	if got.Name != pluginName {
		t.Errorf("Name = %q, want %q", got.Name, pluginName)
	}

	if got.Title != pluginTitle {
		t.Errorf("Title = %q, want %q", got.Title, pluginTitle)
	}

	expectFiles(t, root, pluginName)
}

func TestNewWritesTheManifest(t *testing.T) {
	t.Parallel()

	root := t.TempDir()

	_, err := scaffold.New(root, pluginName)
	if err != nil {
		t.Fatalf(newErrorText, err)
	}

	path := filepath.Join(root, pluginDir, pluginName, manifestName)
	want := "return {\n" +
		"  name = \"My Plugin\",\n" +
		"  file = \"k-my-plugin\",\n" +
		"  version = \"0.1.0\",\n" +
		"  slot = 101,\n" +
		"}\n"

	if got := readFile(t, path); got != want {
		t.Errorf("plugin.lua =\n%s\nwant\n%s", got, want)
	}
}

func TestNewPicksTheFirstFreeSlot(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	writeManifest(t, root, "one", firstSlot)
	writeManifest(t, root, "two", secondSlot)

	got, err := scaffold.New(root, "three")
	if err != nil {
		t.Fatalf(newErrorText, err)
	}

	if got.Slot != thirdSlot {
		t.Errorf("Slot = %d, want %d", got.Slot, thirdSlot)
	}
}

func TestNewRefusesAnExistingPlugin(t *testing.T) {
	t.Parallel()

	root := t.TempDir()

	_, err := scaffold.New(root, pluginName)
	if err != nil {
		t.Fatalf(newErrorText, err)
	}

	_, err = scaffold.New(root, pluginName)
	if err == nil {
		t.Error("New() error = nil, want an error")
	}
}

func TestNewRefusesABadName(t *testing.T) {
	t.Parallel()

	cases := []struct {
		name string
		bad  string
	}{
		{"upper case", "MyPlugin"},
		{"underscore", "my_plugin"},
		{"starts with a digit", "1plugin"},
		{"ends with a dash", "plugin-"},
		{"empty", ""},
	}

	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			t.Parallel()

			_, err := scaffold.New(t.TempDir(), testCase.bad)
			if err == nil {
				t.Errorf("New(%q) error = nil, want an error", testCase.bad)
			}
		})
	}
}
