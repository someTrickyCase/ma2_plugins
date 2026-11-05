package setup_test

import (
	"bytes"
	"strings"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/setup"
	"github.com/someTrickyCase/ma2_plugins/internal/tui"
)

func TestInteractivePresentsCommandsBeforeReturning(t *testing.T) {
	t.Parallel()

	var stdout, stderr bytes.Buffer

	shown := ""
	show := func(text string) error {
		shown = text

		return nil
	}
	items := []tui.Item{{
		Key: answerFile, Name: answerName, Version: answerVersion,
		Slot: chosenSlot,
	}}
	args := []string{boxFlag, writeBox(t), maRootFlag, writeMaFolder(t)}

	code := setup.Interactive(args, &stdout, &stderr, fakePicker(items), show)
	if code != 0 || !strings.Contains(shown, "At Plugin 205") {
		t.Fatalf("Interactive() = %d, result = %q", code, shown)
	}
}

func TestInteractiveKeepsErrorsVisible(t *testing.T) {
	t.Parallel()

	var stdout, stderr bytes.Buffer

	shown := ""
	show := func(text string) error {
		shown = text

		return nil
	}
	args := []string{boxFlag, t.TempDir()}

	code := setup.Interactive(args, &stdout, &stderr, fakePicker(nil), show)
	if code == 0 || !strings.Contains(shown, "plugins.json") {
		t.Fatalf("Interactive() = %d, error = %q", code, shown)
	}
}

func TestAllDoesNotWaitForConfirmation(t *testing.T) {
	t.Parallel()

	var stdout, stderr bytes.Buffer

	show := func(_ string) error {
		t.Error("--all must not open a result screen")

		return nil
	}
	args := []string{
		boxFlag, writeBox(t), maRootFlag, writeMaFolder(t),
		"--all",
	}

	code := setup.Interactive(args, &stdout, &stderr, fakePicker(nil), show)
	if code != 0 {
		t.Fatalf("Interactive() = %d: %s", code, stderr.String())
	}
}
