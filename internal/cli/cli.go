package cli

import (
	"fmt"
	"io"

	"github.com/someTrickyCase/ma2_plugins/internal/buildinfo"
)

const (
	ExitOK    = 0
	ExitUsage = 2
	usage     = "usage: ma2kit version"
)

func Run(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return showUsage(stderr, "")
	}

	switch args[0] {
	case "version":
		_, _ = fmt.Fprintln(stdout, "ma2kit", buildinfo.Current())

		return ExitOK
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
