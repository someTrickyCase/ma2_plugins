package setup

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/someTrickyCase/ma2_plugins/internal/box"
	"github.com/someTrickyCase/ma2_plugins/internal/mahome"
	"github.com/someTrickyCase/ma2_plugins/internal/manifest"
	"github.com/someTrickyCase/ma2_plugins/internal/tui"
)

var errNoVersion = errors.New("no MA2 version folder found")

type Picker func(
	output io.Writer,
	items []tui.Item,
	versions []mahome.Version,
) (tui.Selection, error)

func Run(
	args []string,
	stdout, stderr io.Writer,
	pick Picker,
) int {
	flags := flag.NewFlagSet("setup", flag.ContinueOnError)
	flags.SetOutput(stderr)

	boxFolder := flags.String("box", "", "folder with the plugins")
	maRoot := flags.String("ma-root", mahome.DefaultRoot, "MA2 data folder")
	all := flags.Bool("all", false, "install every plugin, no questions")

	err := flags.Parse(args)
	if err != nil {
		return 1
	}

	folder := *boxFolder
	if folder == "" {
		folder, err = folderOf()
		if err != nil {
			return fail(stderr, err)
		}
	}

	one, err := box.Read(folder)
	if err != nil {
		return fail(stderr, err)
	}

	installed := Setup{
		Box:    one,
		Root:   *maRoot,
		Out:    stdout,
		Err:    stderr,
		Picker: pick,
	}

	if *all {
		return installed.InstallAll()
	}

	return installed.Install()
}

type Setup struct {
	Box    box.Box
	Root   string
	Out    io.Writer
	Err    io.Writer
	Picker Picker
}

func (one Setup) InstallAll() int {
	versions, err := mahome.Versions(one.Root)
	if err != nil {
		return fail(one.Err, err)
	}

	if len(versions) == 0 {
		return fail(one.Err, errNoVersion)
	}

	return one.copySelected(versions[len(versions)-1], one.Box.Plugins)
}

func (one Setup) Install() int {
	versions, err := mahome.Versions(one.Root)
	if err != nil {
		return fail(one.Err, err)
	}

	selection, err := one.Picker(one.Out, itemsOf(one.Box.Plugins), versions)
	if err != nil {
		return fail(one.Err, err)
	}

	plugins := pickedOf(one.Box, selection.Items)

	err = tui.ValidateItems(selection.Items)
	if err != nil {
		return fail(one.Err, err)
	}

	return one.copySelected(selection.Version, plugins)
}

func (one Setup) copySelected(
	version mahome.Version,
	plugins []manifest.Manifest,
) int {
	err := tui.ValidateItems(itemsOf(plugins))
	if err != nil {
		return fail(one.Err, err)
	}

	target := mahome.PluginsFolder(one.Root, version)

	lines, err := box.Commands(plugins)
	if err != nil {
		return fail(one.Err, err)
	}

	err = one.Box.Copy(target, plugins)
	if err != nil {
		return fail(one.Err, err)
	}

	_, _ = fmt.Fprintf(one.Out, "Installed to %s\n\n", target)

	for _, line := range lines {
		_, _ = fmt.Fprintln(one.Out, line)
	}

	return 0
}

func itemsOf(plugins []manifest.Manifest) []tui.Item {
	items := make([]tui.Item, 0, len(plugins))

	for _, plugin := range plugins {
		items = append(items, tui.Item{
			Key:     plugin.File,
			Name:    plugin.Name,
			Version: plugin.Version,
			Slot:    plugin.Slot,
		})
	}

	return items
}

func pickedOf(one box.Box, items []tui.Item) []manifest.Manifest {
	picked := []manifest.Manifest{}

	for _, item := range items {
		for _, plugin := range one.Plugins {
			if plugin.File == item.Key {
				plugin.Slot = item.Slot
				picked = append(picked, plugin)
			}
		}
	}

	return picked
}

func folderOf() (string, error) {
	exe, err := os.Executable()
	if err != nil {
		return "", fmt.Errorf("cannot find the installer: %w", err)
	}

	return filepath.Dir(exe), nil
}

func fail(stderr io.Writer, err error) int {
	_, _ = fmt.Fprintln(stderr, err.Error())

	return 1
}
