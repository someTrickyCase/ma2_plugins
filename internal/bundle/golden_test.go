package bundle_test

import (
	"path/filepath"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/bundle"
	"github.com/someTrickyCase/ma2_plugins/internal/readfile"
	"github.com/someTrickyCase/ma2_plugins/internal/rules"
)

const (
	repoRoot     = "../.."
	bundleFolder = "test/bundles"
)

func readGolden(t *testing.T, name string) string {
	t.Helper()

	path := filepath.Join(repoRoot, bundleFolder, name)

	data, err := readfile.Read(path)
	if err != nil {
		t.Fatalf("cannot read %q: %v", path, err)
	}

	return string(data)
}

func TestGoldenBundles(t *testing.T) {
	t.Parallel()

	cases := []struct {
		plugin string
		file   string
	}{
		{"channel-to-fixture", "k-channel-to-fixture"},
		{"fixture-to-channel", "k-fixture-to-channel"},
		{"sequence-cleanup", "k-sequence-cleanup"},
		{"sequence-position-presets", "k-sequence-position-presets"},
	}

	for _, testCase := range cases {
		t.Run(testCase.plugin, func(t *testing.T) {
			t.Parallel()

			checkGolden(t, testCase.plugin, testCase.file)
		})
	}
}

func checkGolden(t *testing.T, plugin string, file string) {
	t.Helper()

	read := bundle.FileReader(repoRoot)

	built, err := bundle.Collect(plugin, read, fixedStamp())
	if err != nil {
		t.Fatalf(collectError, err)
	}

	gotLua := bundle.Lua(built)
	wantLua := readGolden(t, file+".lua")

	if gotLua != wantLua {
		t.Errorf("Lua() differs from %s.lua", file)
	}

	gotXML := bundle.XML(built)
	wantXML := readGolden(t, file+".xml")

	if gotXML != wantXML {
		t.Errorf("XML() differs from %s.xml", file)
	}

	violations := rules.Find(gotLua, rules.Lua)
	if len(violations) > 0 {
		t.Errorf("the bundle breaks the code rules: %v", violations)
	}
}
