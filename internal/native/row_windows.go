package native

import (
	"errors"
	"fmt"
	"strconv"

	"github.com/lxn/walk"

	"github.com/someTrickyCase/ma2_plugins/internal/tui"
)

type pluginRow struct {
	check *walk.CheckBox
	slot  *walk.LineEdit
}

func newRow(parent walk.Container, item tui.Item) (pluginRow, error) {
	container, err := walk.NewComposite(parent)
	if err != nil {
		return pluginRow{}, fmt.Errorf("create plugin row: %w", err)
	}

	err = container.SetLayout(walk.NewHBoxLayout())
	if err != nil {
		return pluginRow{}, fmt.Errorf("set plugin row layout: %w", err)
	}

	check, err := walk.NewCheckBox(container)
	if err != nil {
		return pluginRow{}, fmt.Errorf("create plugin checkbox: %w", err)
	}

	field, err := walk.NewLineEdit(container)
	if err != nil {
		return pluginRow{}, fmt.Errorf("create plugin slot field: %w", err)
	}

	err = errors.Join(check.SetText(item.Name+"  "+item.Version+"    Slot:"),
		field.SetText(strconv.Itoa(item.Slot)),
		field.SetMinMaxSize(walk.Size{Width: slotWidth, Height: 0},
			walk.Size{Width: slotWidth, Height: 0}))
	if err != nil {
		return pluginRow{}, fmt.Errorf("configure plugin row: %w", err)
	}

	return pluginRow{check: check, slot: field}, nil
}
