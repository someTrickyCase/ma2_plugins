package cli

import (
	"fmt"
	"io"
	"path/filepath"

	"github.com/someTrickyCase/ma2_plugins/internal/scaffold"
)

func runNew(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return showUsage(stderr, "new needs a plugin name")
	}

	result, err := scaffold.New(".", args[0])
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	for _, path := range result.Files {
		_, _ = fmt.Fprintln(stdout, filepath.ToSlash(path))
	}

	_, _ = fmt.Fprintln(stdout, "")
	_, _ = fmt.Fprintf(
		stdout, "Plugin %q is ready, slot %d\n", result.Title, result.Slot)

	next := "Next: task check, then .\\install.ps1 -Plugin " + result.Name
	_, _ = fmt.Fprintln(stdout, next)

	return ExitOK
}
