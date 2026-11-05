package cli

import (
	"errors"
	"flag"
	"fmt"
	"io"

	"github.com/someTrickyCase/ma2_plugins/internal/bundle"
	"github.com/someTrickyCase/ma2_plugins/internal/install"
	"github.com/someTrickyCase/ma2_plugins/internal/mahome"
)

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

	plugin, err := bundle.Collect(
		args[0], bundle.FileReader("."), stampOf("", ""))
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	version, err := mahome.Pick(*maRoot, *maVersion)
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	result, err := install.Do(install.Request{
		Plugin: plugin,
		Slot:   *slot,
		Folder: mahome.PluginsFolder(*maRoot, version),
		DryRun: *dryRun,
	})
	if err != nil {
		return installFailed(stderr, err)
	}

	printInstall(stdout, result)

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

func printInstall(stdout io.Writer, result install.Result) {
	printTarget(stdout, target{folder: result.Folder, dryRun: result.DryRun})
	printCommands(stdout, result)
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
