package cli

import (
	"flag"
	"io"

	"github.com/someTrickyCase/ma2_plugins/internal/mahome"
	"github.com/someTrickyCase/ma2_plugins/internal/manifest"
	"github.com/someTrickyCase/ma2_plugins/internal/tui"
)

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

	items := itemsOf(entries)

	versions, err := mahome.Versions(*maRoot)
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	selection, err := tui.Run(stdout, items, versions)
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	one := request{
		folders: []string{},
		folder:  mahome.PluginsFolder(*maRoot, selection.Version),
		slot:    0,
		dryRun:  *dryRun,
		stdout:  stdout,
		stderr:  stderr,
	}

	return installSelection(one, selection.Items)
}

func installSelection(one request, items []tui.Item) int {
	err := tui.ValidateItems(items)
	if err != nil {
		return showUsage(one.stderr, err.Error())
	}

	for _, item := range items {
		one.folders = []string{item.Key}
		one.slot = item.Slot

		code := one.run()
		if code != ExitOK {
			return code
		}
	}

	return ExitOK
}

func itemsOf(entries []manifest.Entry) []tui.Item {
	items := make([]tui.Item, 0, len(entries))

	for _, entry := range entries {
		items = append(items, tui.Item{
			Key:     entry.Folder,
			Name:    entry.Manifest.Name,
			Version: entry.Manifest.Version,
			Slot:    entry.Manifest.Slot,
		})
	}

	return items
}
