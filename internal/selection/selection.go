package selection

import (
	"errors"
	"fmt"

	"github.com/someTrickyCase/ma2_plugins/internal/mahome"
)

var (
	ErrSlot  = errors.New("plugin slots must be positive whole numbers")
	errTaken = errors.New("selected plugins must have different slots")
)

type Item struct {
	Key     string
	Name    string
	Version string
	Slot    int
}

type Selection struct {
	Items   []Item
	Version mahome.Version
}

func ValidateItems(items []Item) error {
	seen := map[int]bool{}

	for _, item := range items {
		if item.Slot <= 0 {
			return ErrSlot
		}

		if seen[item.Slot] {
			return fmt.Errorf("%w: %d", errTaken, item.Slot)
		}

		seen[item.Slot] = true
	}

	return nil
}
