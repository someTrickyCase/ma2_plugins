package selection_test

import (
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/selection"
)

func item(slot int) selection.Item {
	return selection.Item{Key: "", Name: "", Version: "", Slot: slot}
}

func TestValidateItems(t *testing.T) {
	t.Parallel()

	const validSlot = 101

	cases := []struct {
		name  string
		items []selection.Item
		valid bool
	}{
		{name: "empty", items: nil, valid: true},
		{
			name:  "positive",
			items: []selection.Item{item(validSlot)},
			valid: true,
		},
		{name: "zero", items: []selection.Item{item(0)}, valid: false},
		{name: "negative", items: []selection.Item{item(-1)}, valid: false},
		{
			name:  "duplicate",
			items: []selection.Item{item(1), item(1)},
			valid: false,
		},
	}

	for _, one := range cases {
		t.Run(one.name, func(t *testing.T) {
			t.Parallel()

			err := selection.ValidateItems(one.items)
			if (err == nil) != one.valid {
				t.Errorf(
					"ValidateItems() error = %v, valid = %t", err, one.valid,
				)
			}
		})
	}
}
