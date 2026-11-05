package native

import (
	"errors"
	"fmt"
	"io"

	"github.com/lxn/walk"

	"github.com/someTrickyCase/ma2_plugins/internal/mahome"
	"github.com/someTrickyCase/ma2_plugins/internal/tui"
)

type picker struct {
	window    *walk.Dialog
	rows      []pluginRow
	version   *walk.ComboBox
	items     []tui.Item
	versions  []mahome.Version
	selection tui.Selection
	accepted  bool
}

func Pick(
	_ io.Writer, items []tui.Item, versions []mahome.Version,
) (tui.Selection, error) {
	if len(items) == 0 || len(versions) == 0 {
		return tui.Selection{}, errSelection
	}

	window, err := dialog("MA2 plugin installer")
	if err != nil {
		return tui.Selection{}, err
	}
	defer window.Dispose()

	one := picker{
		window: window, rows: []pluginRow{}, version: nil, items: items,
		versions: versions,
		selection: tui.Selection{
			Items: nil, Version: mahome.Version{Text: "", Parts: nil},
		},
		accepted: false,
	}

	err = one.build()
	if err != nil {
		return tui.Selection{}, err
	}

	window.Run()

	if !one.accepted {
		return tui.Selection{}, tui.ErrCancelled
	}

	return one.selection, nil
}

func (one *picker) build() error {
	err := label(one.window,
		"Choose plugins and their MA2 pool slots for this installation.")
	if err != nil {
		return err
	}

	for _, item := range one.items {
		row, rowErr := newRow(one.window, item)
		if rowErr != nil {
			return rowErr
		}

		one.rows = append(one.rows, row)
	}

	err = one.buildVersions()
	if err != nil {
		return err
	}

	return one.buildButtons()
}

func (one *picker) buildVersions() error {
	err := label(one.window, "Install into MA2 version:")
	if err != nil {
		return err
	}

	one.version, err = walk.NewDropDownBox(one.window)
	if err != nil {
		return fmt.Errorf("create version selector: %w", err)
	}

	names := make([]string, 0, len(one.versions))
	for _, version := range one.versions {
		names = append(names, version.Text)
	}

	err = errors.Join(one.version.SetModel(names),
		one.version.SetCurrentIndex(len(names)-1))
	if err != nil {
		return fmt.Errorf("set MA2 versions: %w", err)
	}

	return nil
}

func (one *picker) buildButtons() error {
	install, err := button(one.window, "Install", one.accept)
	if err != nil {
		return err
	}

	cancel, err := button(one.window, "Cancel", one.window.Cancel)
	if err != nil {
		return err
	}

	err = errors.Join(one.window.SetDefaultButton(install),
		one.window.SetCancelButton(cancel))
	if err != nil {
		return fmt.Errorf("configure installer buttons: %w", err)
	}

	return nil
}

func (one *picker) accept() {
	checked := make([]bool, 0, len(one.rows))
	slots := make([]string, 0, len(one.rows))

	for _, row := range one.rows {
		checked = append(checked, row.check.Checked())
		slots = append(slots, row.slot.Text())
	}

	selection, err := Choose(one.items, checked, slots, one.versions,
		one.version.CurrentIndex())
	if err != nil {
		walk.MsgBox(one.window, "Check your selection", err.Error(),
			walk.MsgBoxIconWarning)

		return
	}

	one.selection = selection
	one.accepted = true
	one.window.Accept()
}
