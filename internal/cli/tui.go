package cli

import (
	"flag"
	"io"

	"github.com/someTrickyCase/ma2_plugins/internal/bundle"
	"github.com/someTrickyCase/ma2_plugins/internal/install"
	"github.com/someTrickyCase/ma2_plugins/internal/mahome"
	"github.com/someTrickyCase/ma2_plugins/internal/manifest"
	"github.com/someTrickyCase/ma2_plugins/internal/tui"
)

type picker struct {
	root   string
	dryRun bool
	stdout io.Writer
	stderr io.Writer
}

func runTUI(args []string, stdout, stderr io.Writer) int {
	flags := flag.NewFlagSet("tui", flag.ContinueOnError)
	flags.SetOutput(stderr)

	maRoot := flags.String("ma-root", mahome.DefaultRoot, "MA2 data folder")
	dryRun := flags.Bool("dry-run", false, "copy nothing")

	err := flags.Parse(args)
	if err != nil {
		return ExitUsage
	}

	entries, err := manifest.ReadEntries(".")
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	if len(entries) == 0 {
		return showUsage(stderr, "no plugins found")
	}

	versions, err := mahome.Versions(*maRoot)
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	selection, err := tui.Run(stdout, entries, versions)
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	one := picker{
		root:   *maRoot,
		dryRun: *dryRun,
		stdout: stdout,
		stderr: stderr,
	}

	return one.install(selection)
}

func (one picker) install(selection tui.Selection) int {
	folder := mahome.PluginsFolder(one.root, selection.Version)

	printTarget(one.stdout, target{folder: folder, dryRun: one.dryRun})

	for _, entry := range selection.Plugins {
		plugin, err := bundle.Collect(
			entry.Folder, bundle.FileReader("."), stampOf("", ""))
		if err != nil {
			return showUsage(one.stderr, err.Error())
		}

		result, err := install.Do(install.Request{
			Plugin: plugin,
			Slot:   0,
			Folder: folder,
			DryRun: one.dryRun,
		})
		if err != nil {
			return showUsage(one.stderr, err.Error())
		}

		printCommands(one.stdout, result)
	}

	return ExitOK
}
