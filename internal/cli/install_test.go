package cli_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/cli"
)

const (
	installCmd  = "install"
	maRootFlag  = "--ma-root"
	atFlag      = "--at"
	versionFlag = "--ma-version"
	dryFlag     = "--dry-run"
	maFolder    = "ma"
	pluginsName = "plugins"
	versionHead = "gma2_V_"
	oldVersion  = "3.9.60"
	newVersion  = "3.10.0"
	emptyFolder = "empty"
)

func maPluginsFolder(maRoot string, version string) string {
	return filepath.Join(maRoot, versionHead+version, pluginsName)
}

func writeMaVersion(t *testing.T, root string, version string) string {
	t.Helper()

	folder := maPluginsFolder(root, version)

	err := os.MkdirAll(folder, dirMode)
	if err != nil {
		t.Fatalf("cannot create %q: %v", folder, err)
	}

	return folder
}

func maRootWith(t *testing.T, root string, versions ...string) string {
	t.Helper()

	maRoot := filepath.Join(root, maFolder)

	for _, version := range versions {
		writeMaVersion(t, maRoot, version)
	}

	return maRoot
}

func installedFiles(folder string) []string {
	found := []string{}

	entries, err := os.ReadDir(folder)
	if err != nil {
		return found
	}

	for _, entry := range entries {
		found = append(found, entry.Name())
	}

	return found
}

func TestInstallCopiesIntoTheNewestVersion(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root)
	t.Chdir(root)

	maRoot := maRootWith(t, root, oldVersion, newVersion)

	got := run(installCmd, answerPlugin, maRootFlag, maRoot)

	expectCode(t, got, cli.ExitOK)

	target := maPluginsFolder(maRoot, newVersion)

	for _, name := range []string{answerLua, answerXML} {
		_, err := os.Stat(filepath.Join(target, name))
		if err != nil {
			t.Errorf("missing %q: %v", name, err)
		}
	}

	older := maPluginsFolder(maRoot, oldVersion)

	if len(installedFiles(older)) != 0 {
		t.Error("the older version has files, want nothing")
	}
}

func TestInstallTakesTheGivenVersion(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root)
	t.Chdir(root)

	maRoot := maRootWith(t, root, oldVersion, newVersion)

	got := run(
		installCmd, answerPlugin, maRootFlag, maRoot, versionFlag, oldVersion)

	expectCode(t, got, cli.ExitOK)

	target := maPluginsFolder(maRoot, oldVersion)

	_, err := os.Stat(filepath.Join(target, answerLua))
	if err != nil {
		t.Errorf("missing the built file: %v", err)
	}
}

func TestInstallCopiesNothingOnADryRun(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root)
	t.Chdir(root)

	maRoot := maRootWith(t, root, oldVersion)

	got := run(installCmd, answerPlugin, maRootFlag, maRoot, dryFlag)

	expectCode(t, got, cli.ExitOK)

	target := maPluginsFolder(maRoot, oldVersion)

	if len(installedFiles(target)) != 0 {
		t.Error("the folder has files, want nothing")
	}

	expectStdoutContains(t, got, "Dry run")
}

func TestInstallPrintsTheMa2Commands(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root)
	t.Chdir(root)

	maRoot := maRootWith(t, root, oldVersion)

	got := run(installCmd, answerPlugin, maRootFlag, maRoot)

	expectCode(t, got, cli.ExitOK)
	expectStdoutContains(t, got, "Delete Plugin 101")
	expectStdoutContains(t, got, `Import "`+answerXML+`" At Plugin 101`)
	expectStdoutContains(t, got, "Plugin 101")
}

func TestInstallTakesTheGivenSlot(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root)
	t.Chdir(root)

	maRoot := maRootWith(t, root, oldVersion)

	got := run(installCmd, answerPlugin, maRootFlag, maRoot, atFlag, "5")

	expectCode(t, got, cli.ExitOK)
	expectStdoutContains(t, got, "Plugin 5")
}

func TestInstallFailsWithoutAMaFolder(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root)
	t.Chdir(root)

	got := run(
		installCmd, answerPlugin, maRootFlag, filepath.Join(root, emptyFolder))

	expectCode(t, got, cli.ExitUsage)
	expectStderr(t, got, "no MA2 version folder")
}

func TestInstallFailsOnAnUnknownPlugin(t *testing.T) {
	root := t.TempDir()
	t.Chdir(root)

	maRoot := maRootWith(t, root, oldVersion)

	got := run(installCmd, "nothing", maRootFlag, maRoot)

	expectCode(t, got, cli.ExitUsage)
	expectStderr(t, got, "missing file")
}

func TestInstallFailsOnBrokenRules(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root)
	t.Chdir(root)

	path := filepath.Join(root, pluginDir, answerPlugin, "main.lua")

	err := os.WriteFile(path, []byte("-- a comment\nreturn 1\n"), fileMode)
	if err != nil {
		t.Fatalf("cannot write the entry point: %v", err)
	}

	maRoot := maRootWith(t, root, oldVersion)

	got := run(installCmd, answerPlugin, maRootFlag, maRoot)

	expectCode(t, got, cli.ExitViolations)
	expectStderr(t, got, "code rules")

	target := maPluginsFolder(maRoot, oldVersion)

	if len(installedFiles(target)) != 0 {
		t.Error("the folder has files, want nothing")
	}
}

func TestInstallNeedsAPluginName(t *testing.T) {
	t.Parallel()

	got := run(installCmd)

	expectCode(t, got, cli.ExitUsage)
	expectStderr(t, got, "install needs a plugin name")
}

func TestInstallFailsOnAnUnknownFlag(t *testing.T) {
	t.Parallel()

	got := run(installCmd, answerPlugin, "--nope")

	expectCode(t, got, cli.ExitUsage)
}

func TestUsageListsTheInstallCommand(t *testing.T) {
	t.Parallel()

	got := run()

	expectStderr(t, got, "install <plugin-name>")
}
