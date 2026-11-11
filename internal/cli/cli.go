package cli

import (
	"fmt"
	"io"

	"github.com/someTrickyCase/ma2_plugins/internal/buildinfo"
	"github.com/someTrickyCase/ma2_plugins/internal/packageout"
)

const (
	ExitOK         = 0
	ExitViolations = 1
	ExitUsage      = 2
	usage          = `usage: ma2kit <command> [args]

commands:
  version
  check-rules <file>...
  new <plugin-name>
  bundle <plugin-name> [flags]
  manifest [flags]
  install <plugin-name> [flags]
  tui
  package-stage
  package-promote`
)

func Run(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return showUsage(stderr, "")
	}

	switch args[0] {
	case "check-rules":
		return runCheckRules(args[1:], stdout, stderr)
	case "new":
		return runNew(args[1:], stdout, stderr)
	case "bundle":
		return runBundle(args[1:], stdout, stderr)
	case "manifest":
		return runManifest(args[1:], stdout, stderr)
	case "install":
		return runInstall(args[1:], stdout, stderr)
	case "tui":
		return runTUI(args[1:], stdout, stderr)
	default:
		return runOther(args, stdout, stderr)
	}
}

func runOther(args []string, stdout, stderr io.Writer) int {
	switch args[0] {
	case "version":
		_, _ = fmt.Fprintln(stdout, "ma2kit", buildinfo.Current())

		return ExitOK
	case "package-stage":
		return packageCommand(args[1:], stderr, packageout.Prepare)
	case "package-promote":
		return packageCommand(args[1:], stderr, packageout.Promote)
	default:
		return showUsage(stderr, fmt.Sprintf("unknown command %q", args[0]))
	}
}

func packageCommand(
	args []string, stderr io.Writer, action func(string) error,
) int {
	if len(args) != 0 {
		return showUsage(stderr, "package command takes no arguments")
	}

	err := action(".")
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	return ExitOK
}

func showUsage(stderr io.Writer, problem string) int {
	if problem != "" {
		_, _ = fmt.Fprintln(stderr, problem)
	}

	_, _ = fmt.Fprintln(stderr, usage)

	return ExitUsage
}
