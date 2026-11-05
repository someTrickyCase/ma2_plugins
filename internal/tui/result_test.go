package tui_test

import (
	"strings"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/tui"
)

func TestResultWaitsForExplicitClose(t *testing.T) {
	t.Parallel()

	model := tui.NewResult("Import plugin commands")
	if model.Init() != nil {
		t.Fatal("result closed before user input")
	}

	if !strings.Contains(model.View(), "Import plugin commands") {
		t.Fatal("result is missing the import commands")
	}

	_, idle := model.Update(key(keyDown))

	_, closeCommand := model.Update(key(keyEnter))
	if idle != nil || closeCommand == nil {
		t.Fatal("result should close only on explicit confirmation")
	}
}
