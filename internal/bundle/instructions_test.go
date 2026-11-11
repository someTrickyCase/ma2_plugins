package bundle_test

import (
	"strings"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/bundle"
)

func wantInstructions() []string {
	return []string{
		"MA2 commands, paste them in this order:",
		"",
		"  1. Only when updating, remove the old copy:",
		"     Delete Plugin 101",
		"  2. Load the plugin into the pool:",
		`     Import "k-answer.xml" At Plugin 101`,
		"  3. Run it (on a show copy first!):",
		"     Plugin 101",
	}
}

func TestInstructions(t *testing.T) {
	t.Parallel()

	got, err := bundle.Instructions(answerPlugin([]bundle.Module{}).Manifest, 0)
	if err != nil {
		t.Fatalf("Instructions() error = %v", err)
	}

	want := wantInstructions()

	if len(got) != len(want) {
		t.Fatalf("Instructions() = %d lines, want %d", len(got), len(want))
	}

	for index, line := range want {
		if got[index] != line {
			t.Errorf("line %d = %q, want %q", index+1, got[index], line)
		}
	}
}

func TestInstructionsTakeTheGivenSlot(t *testing.T) {
	t.Parallel()

	answer := answerPlugin([]bundle.Module{}).Manifest

	got, err := bundle.Instructions(answer, otherSlot)
	if err != nil {
		t.Fatalf("Instructions() error = %v", err)
	}

	want := []string{
		"     Delete Plugin 5",
		`     Import "k-answer.xml" At Plugin 5`,
		"     Plugin 5",
	}

	for _, line := range want {
		if !strings.Contains(strings.Join(got, "\n"), line) {
			t.Errorf("Instructions() = %v, want the line %q", got, line)
		}
	}
}

func TestInstructionsNeedASlot(t *testing.T) {
	t.Parallel()

	plugin := answerPlugin([]bundle.Module{})
	plugin.Manifest.Slot = 0

	_, err := bundle.Instructions(plugin.Manifest, 0)
	if err == nil {
		t.Fatal("Instructions() error = nil, want an error")
	}

	if !strings.Contains(err.Error(), "no plugin slot") {
		t.Errorf("Instructions() error = %q, want it to say no plugin slot",
			err.Error())
	}
}

func TestInstructionsRejectNegativeSlots(t *testing.T) {
	t.Parallel()

	plugin := answerPlugin([]bundle.Module{}).Manifest

	_, err := bundle.Instructions(plugin, -1)
	if err == nil {
		t.Fatal("negative override accepted")
	}

	plugin.Slot = -1

	_, err = bundle.Instructions(plugin, 0)
	if err == nil {
		t.Fatal("negative default accepted")
	}
}
