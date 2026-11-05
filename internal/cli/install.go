package cli

import (
	"errors"
	"flag"
	"fmt"
	"io"

	"github.com/someTrickyCase/ma2_plugins/internal/install"
	"github.com/someTrickyCase/ma2_plugins/internal/mahome"
)

type request struct {
	folders []string
	folder  string
	slot    int
	dryRun  bool
	stdout  io.Writer
	stderr  io.Writer
}

func runInstall(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return showUsage(stderr, "install needs a plugin name")
	}

	flags := flag.NewFlagSet("install", flag.ContinueOnError)
	flags.SetOutput(stderr)

	slot := flags.Int("at", 0, "plugin pool slot")
	maVersion := flags.String("ma-version", "", "MA2 version to install into")
	maRoot := flags.String("ma-root", mahome.DefaultRoot, "MA2 data folder")
	dryRun := flags.Bool("dry-run", false, "copy nothing")

	err := flags.Parse(args[1:])
	if err != nil {
		return ExitUsage
	}

	version, err := mahome.Pick(*maRoot, *maVersion)
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	one := request{
		folders: []string{args[0]},
		folder:  mahome.PluginsFolder(*maRoot, version),
		slot:    *slot,
		dryRun:  *dryRun,
		stdout:  stdout,
		stderr:  stderr,
	}

	return one.run()
}

func (one request) run() int {
	results, err := install.All(install.Batch{
		Root:   ".",
		Folder: one.folder,
		Slot:   one.slot,
		DryRun: one.dryRun,
		Stamp:  stampOf("", ""),
	}, one.folders)
	if err != nil {
		return installFailed(one.stderr, err)
	}

	printTarget(one.stdout, target{folder: one.folder, dryRun: one.dryRun})

	for _, result := range results {
		printCommands(one.stdout, result)
	}

	return ExitOK
}

func installFailed(stderr io.Writer, err error) int {
	if errors.Is(err, install.ErrRules) {
		_, _ = fmt.Fprintln(stderr, err.Error())

		return ExitViolations
	}

	return showUsage(stderr, err.Error())
}

type target struct {
	folder string
	dryRun bool
}

func printTarget(stdout io.Writer, one target) {
	if one.dryRun {
		_, _ = fmt.Fprintf(
			stdout, "Dry run: nothing was copied to %s\n", one.folder)
	} else {
		_, _ = fmt.Fprintf(stdout, "Installed to %s\n", one.folder)
	}
}

func printCommands(stdout io.Writer, result install.Result) {
	for _, path := range result.Files {
		_, _ = fmt.Fprintln(stdout, path)
	}

	_, _ = fmt.Fprintln(stdout, "")

	for _, line := range result.Instructions {
		_, _ = fmt.Fprintln(stdout, line)
	}
}
