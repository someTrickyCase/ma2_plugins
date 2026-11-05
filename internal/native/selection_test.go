package native_test

import (
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/mahome"
	"github.com/someTrickyCase/ma2_plugins/internal/native"
	"github.com/someTrickyCase/ma2_plugins/internal/tui"
)

const (
	slotNumber  = 205
	secondSlot  = 2
	versionText = "1"
)

func TestChooseUsesCheckedPluginsEditedSlotsAndVersion(t *testing.T) {
	t.Parallel()

	items := []tui.Item{
		{Key: "first", Name: "First", Version: versionText, Slot: 1},
		{Key: "second", Name: "Second", Version: versionText, Slot: secondSlot},
	}
	versions := []mahome.Version{{Text: "3.9.60", Parts: nil}}

	got, err := native.Choose(items, []bool{true, false},
		[]string{"205", "invalid unchecked field"}, versions, 0)
	if err != nil {
		t.Fatal(err)
	}

	if len(got.Items) != 1 || got.Items[0].Slot != slotNumber ||
		got.Version.Text != versions[0].Text || items[0].Slot != 1 {
		t.Fatalf("unexpected selection: %v", got)
	}
}

func TestChooseRejectsInvalidSelection(t *testing.T) {
	t.Parallel()

	items := []tui.Item{
		{Key: "first", Name: "First", Version: versionText, Slot: 1},
		{Key: "second", Name: "Second", Version: versionText, Slot: secondSlot},
	}
	cases := [][]string{
		{"0", versionText},
		{"-1", versionText},
		{"abc", versionText},
		{versionText, versionText},
	}

	for _, slots := range cases {
		_, err := native.Choose(items, []bool{true, true}, slots,
			[]mahome.Version{{Text: "3.9.60", Parts: nil}}, 0)
		if err == nil {
			t.Fatalf("accepted invalid slots %v", slots)
		}
	}
}

func TestChooseRejectsEmptyOrInconsistentInput(t *testing.T) {
	t.Parallel()

	_, err := native.Choose(nil, nil, nil, nil, -1)
	if err == nil {
		t.Fatal("accepted empty input")
	}
}
