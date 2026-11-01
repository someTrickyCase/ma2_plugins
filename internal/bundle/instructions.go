package bundle

import (
	"errors"
	"fmt"
	"strconv"
)

var errNoSlot = errors.New(
	"no plugin slot: add slot to plugin.json or pass one")

func Instructions(plugin Plugin, slot int) ([]string, error) {
	target := slot

	if target == 0 {
		target = plugin.Manifest.Slot
	}

	if target == 0 {
		return nil, errNoSlot
	}

	pool := "Plugin " + strconv.Itoa(target)

	return []string{
		"MA2 commands, paste them in this order:",
		"",
		"  1. Only when updating, remove the old copy:",
		"     Delete " + pool,
		"  2. Load the plugin into the pool:",
		fmt.Sprintf(`     Import "%s.xml" At %s`, plugin.Manifest.File, pool),
		"  3. Run it (on a show copy first!):",
		"     " + pool,
	}, nil
}
