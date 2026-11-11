package native

import (
	"errors"
	"fmt"
	"strconv"

	"github.com/someTrickyCase/ma2_plugins/internal/mahome"
	"github.com/someTrickyCase/ma2_plugins/internal/selection"
)

var errSelection = errors.New("choose plugins and an installed MA2 version")

func Choose(
	items []selection.Item,
	checked []bool,
	slots []string,
	versions []mahome.Version,
	version int,
) (selection.Selection, error) {
	if len(items) != len(checked) || len(items) != len(slots) ||
		version < 0 || version >= len(versions) {
		return selection.Selection{}, errSelection
	}

	chosen, err := checkedItems(items, checked, slots)
	if err != nil {
		return selection.Selection{}, err
	}

	if len(chosen) == 0 {
		return selection.Selection{}, errSelection
	}

	err = selection.ValidateItems(chosen)
	if err != nil {
		return selection.Selection{}, fmt.Errorf("check plugin slots: %w", err)
	}

	return selection.Selection{Items: chosen, Version: versions[version]}, nil
}

func checkedItems(
	items []selection.Item, checked []bool, slots []string,
) ([]selection.Item, error) {
	chosen := []selection.Item{}

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
