package tui_test

import (
	"strings"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/tui"
)

const changedSlot = 205

func TestSlotEditingChangesTheSelectedPluginOnly(t *testing.T) {
	t.Parallel()

	items := entries()
	model := press(tui.New(items, versions()), "s", "205", keyEnter,
		keySpace, keyEnter, keyEnter)

	got, err := model.Selection()
	if err != nil {
		t.Fatal(err)
	}

	if got.Items[0].Slot != changedSlot || items[0].Slot != firstSlot {
		t.Fatalf("slots = %d/%d, want edited/original", got.Items[0].Slot,
			items[0].Slot)
	}
}

func TestSlotEditingRejectsInvalidValues(t *testing.T) {
	t.Parallel()

	for _, value := range []string{"0", "-1", "abc", "102"} {
		t.Run(value, func(t *testing.T) {
			t.Parallel()

			model := press(tui.New(entries(), versions()),
				keySpace, keyDown, keySpace, keyUp, "s", value, keyEnter)

			if !strings.Contains(model.View(), "Plugin slot") {
				t.Fatal("invalid slot was accepted")
			}
		})
	}
}
