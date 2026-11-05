package native

import (
	"errors"
	"fmt"
	"strconv"

	"github.com/someTrickyCase/ma2_plugins/internal/mahome"
	"github.com/someTrickyCase/ma2_plugins/internal/tui"
)

var errSelection = errors.New("choose plugins and an installed MA2 version")

func Choose(
	items []tui.Item,
	checked []bool,
	slots []string,
	versions []mahome.Version,
	version int,
) (tui.Selection, error) {
	if len(items) != len(checked) || len(items) != len(slots) ||
		version < 0 || version >= len(versions) {
		return tui.Selection{}, errSelection
	}

	chosen, err := checkedItems(items, checked, slots)
	if err != nil {
		return tui.Selection{}, err
	}

	if len(chosen) == 0 {
		return tui.Selection{}, errSelection
	}

	err = tui.ValidateItems(chosen)
	if err != nil {
		return tui.Selection{}, fmt.Errorf("check plugin slots: %w", err)
	}

	return tui.Selection{Items: chosen, Version: versions[version]}, nil
}

func checkedItems(
	items []tui.Item, checked []bool, slots []string,
) ([]tui.Item, error) {
	chosen := []tui.Item{}

	for index, item := range items {
		if !checked[index] {
			continue
		}

		slot, err := strconv.Atoi(slots[index])
		if err != nil {
			return nil, fmt.Errorf("slot for %s: %w", item.Name, err)
		}

		item.Slot = slot
		chosen = append(chosen, item)
	}

	return chosen, nil
}
