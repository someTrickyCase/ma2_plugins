package cli_test

import (
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/cli"
)

const newCommand = "new"

func TestNewCreatesThePluginFiles(t *testing.T) {
	root := t.TempDir()
	t.Chdir(root)

	got := run(newCommand, "my-plugin")

	expectCode(t, got, cli.ExitOK)
	expectStdoutContains(t, got, "plugins/my-plugin/plugin.lua")
	expectStdoutContains(t, got, "plugins/my-plugin/main.lua")
	expectStdoutContains(t, got, "test/plugins/my-plugin/main.test.lua")
	expectStdoutContains(t, got, "My Plugin")
}

func TestNewWithoutANameShowsUsage(t *testing.T) {
	t.Parallel()

	got := run(newCommand)

	expectCode(t, got, cli.ExitUsage)
	expectStderr(t, got, "new needs a plugin name")
}

func TestNewRefusesABadName(t *testing.T) {
	t.Parallel()

	got := run(newCommand, "My Plugin")

	expectCode(t, got, cli.ExitUsage)
	expectStderr(t, got, "not a plugin name")
}
