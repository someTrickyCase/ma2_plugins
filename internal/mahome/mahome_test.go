package mahome_test

import (
	"os"
	"path/filepath"
	"slices"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/mahome"
)

const (
	folderPrefix = "gma2_V_"
	pluginsName  = "plugins"
	dirMode      = 0o750
	oldVersion   = "3.2.0"
	midVersion   = "3.9.60"
	newVersion   = "3.10.0"
	badVersion   = "beta"
	majorPart    = 3
	minorPart    = 9
	patchPart    = 60
)

func writeVersion(t *testing.T, root string, version string) string {
	t.Helper()

	folder := filepath.Join(root, folderPrefix+version, pluginsName)

	err := os.MkdirAll(folder, dirMode)
	if err != nil {
		t.Fatalf("cannot create %q: %v", folder, err)
	}

	return folder
}

func writeVersions(t *testing.T, root string, versions ...string) {
	t.Helper()

	for _, version := range versions {
		writeVersion(t, root, version)
	}
}

func TestParseVersionReadsTheParts(t *testing.T) {
	t.Parallel()

	got, err := mahome.ParseVersion(midVersion)
	if err != nil {
		t.Fatalf("ParseVersion() error = %v", err)
	}

	want := []int{majorPart, minorPart, patchPart}

	if got.Text != midVersion {
		t.Errorf("Text = %q, want %q", got.Text, midVersion)
	}

	if !slices.Equal(got.Parts, want) {
		t.Errorf("Parts = %v, want %v", got.Parts, want)
	}
}

func TestParseVersionFailsOnRubbish(t *testing.T) {
	t.Parallel()

	_, err := mahome.ParseVersion(badVersion)
	if err == nil {
		t.Error("ParseVersion() error = nil, want an error")
	}
}

func TestVersionsSortByNumberNotByText(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	writeVersions(t, root, midVersion, newVersion, oldVersion)

	got, err := mahome.Versions(root)
	if err != nil {
		t.Fatalf("Versions() error = %v", err)
	}

	want := []string{oldVersion, midVersion, newVersion}

	if len(got) != len(want) {
		t.Fatalf("Versions() = %d versions, want %d", len(got), len(want))
	}

	for index, version := range got {
		if version.Text != want[index] {
			t.Errorf(
				"version %d = %q, want %q", index, version.Text, want[index])
		}
	}
}

func TestVersionsSkipFoldersThatAreNotVersions(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	writeVersions(t, root, midVersion)

	other := filepath.Join(root, folderPrefix+badVersion)

	err := os.MkdirAll(other, dirMode)
	if err != nil {
		t.Fatalf("cannot create %q: %v", other, err)
	}

	got, err := mahome.Versions(root)
	if err != nil {
		t.Fatalf("Versions() error = %v", err)
	}

	if len(got) != 1 {
		t.Fatalf("Versions() = %d versions, want 1", len(got))
	}
}

func TestNewestTakesTheHighestNumber(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	writeVersions(t, root, midVersion, newVersion)

	got, err := mahome.Newest(root)
	if err != nil {
		t.Fatalf("Newest() error = %v", err)
	}

	if got.Text != newVersion {
		t.Errorf("Newest() = %q, want %q", got.Text, newVersion)
	}
}

func TestNewestFailsWithoutAnyVersion(t *testing.T) {
	t.Parallel()

	_, err := mahome.Newest(t.TempDir())
	if err == nil {
		t.Error("Newest() error = nil, want an error")
	}
}

func TestPickTakesTheWantedVersion(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	writeVersions(t, root, midVersion, newVersion)

	got, err := mahome.Pick(root, midVersion)
	if err != nil {
		t.Fatalf("Pick() error = %v", err)
	}

	if got.Text != midVersion {
		t.Errorf("Pick() = %q, want %q", got.Text, midVersion)
	}
}

func TestPickTakesTheNewestWithoutAWantedVersion(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	writeVersions(t, root, midVersion, newVersion)

	got, err := mahome.Pick(root, "")
	if err != nil {
		t.Fatalf("Pick() error = %v", err)
	}

	if got.Text != newVersion {
		t.Errorf("Pick() = %q, want %q", got.Text, newVersion)
	}
}

func TestPickFailsOnAMissingVersion(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	writeVersions(t, root, midVersion)

	_, err := mahome.Pick(root, newVersion)
	if err == nil {
		t.Error("Pick() error = nil, want an error")
	}
}

func TestPluginsFolderIsInsideTheVersionFolder(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	writeVersions(t, root, midVersion)

	version, err := mahome.ParseVersion(midVersion)
	if err != nil {
		t.Fatalf("ParseVersion() error = %v", err)
	}

	got := mahome.PluginsFolder(root, version)

	want := filepath.Join(root, folderPrefix+midVersion, pluginsName)

	if got != want {
		t.Errorf("PluginsFolder() = %q, want %q", got, want)
	}
}
