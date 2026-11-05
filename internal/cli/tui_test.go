package cli_test

import (
	"path/filepath"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/cli"
)

const tuiCmd = "tui"

func TestTuiFailsWithoutPlugins(t *testing.T) {
	root := t.TempDir()
	t.Chdir(root)

	got := run(tuiCmd)

	expectCode(t, got, cli.ExitUsage)
	expectStderr(t, got, "no plugins found")
}

func TestTuiFailsWithoutAMaFolder(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root)
	t.Chdir(root)

	got := run(tuiCmd, maRootFlag, filepath.Join(root, emptyFolder))

	expectCode(t, got, cli.ExitUsage)
	expectStderr(t, got, "no MA2 version folder")
}

func TestTuiFailsOnAnUnknownFlag(t *testing.T) {
	t.Parallel()

	got := run(tuiCmd, "--nope")

	expectCode(t, got, cli.ExitUsage)
}

func TestUsageListsTheTuiCommand(t *testing.T) {
	t.Parallel()

	got := run()

	expectStderr(t, got, "tui")
}
