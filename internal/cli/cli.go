package cli

import (
	"fmt"
	"io"

	"github.com/someTrickyCase/ma2_plugins/internal/buildinfo"
)

const (
	ExitOK         = 0
	ExitViolations = 1
	ExitUsage      = 2
	usage          = `usage: ma2kit <command> [args]

commands:
  version
  check-rules <file>...
  new <plugin-name>`
)

func Run(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return showUsage(stderr, "")
	}

	switch args[0] {
	case "version":
		_, _ = fmt.Fprintln(stdout, "ma2kit", buildinfo.Current())

		return ExitOK
	case "check-rules":
		return runCheckRules(args[1:], stdout, stderr)
	case "new":
		return runNew(args[1:], stdout, stderr)
	default:
		return showUsage(stderr, fmt.Sprintf("unknown command %q", args[0]))
	}
}

func showUsage(stderr io.Writer, problem string) int {
	if problem != "" {
		_, _ = fmt.Fprintln(stderr, problem)
	}

	_, _ = fmt.Fprintln(stderr, usage)

	return ExitUsage
}
