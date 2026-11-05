package tui_test

import (
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/someTrickyCase/ma2_plugins/internal/mahome"
	"github.com/someTrickyCase/ma2_plugins/internal/tui"
)

const (
	keyUp       = "up"
	keyDown     = "down"
	keySpace    = " "
	keyEnter    = "enter"
	keyEsc      = "esc"
	keyQuit     = "q"
	keyCtrlC    = "ctrl+c"
	firstName   = "Channel to Fixture"
	secondName  = "Fixture to Channel"
	firstFolder = "channel-to-fixture"
	firstSlot   = 101
	secondSlot  = 102
	versionOne  = "3.9.60"
	versionTwo  = "3.10.0"
	majorPart   = 3
	minorPart   = 9
	patchPart   = 60
	tenPart     = 10
	wantPlugins = "View() = %q, want the plugins"
)

func key(name string) tea.KeyMsg {
	switch name {
	case keyUp:
		return tea.KeyMsg{
			Type: tea.KeyUp, Runes: []rune{}, Alt: false, Paste: false,
		}
	case keyDown:
		return tea.KeyMsg{
			Type: tea.KeyDown, Runes: []rune{}, Alt: false, Paste: false,
		}
	case keyEnter:
		return tea.KeyMsg{
			Type: tea.KeyEnter, Runes: []rune{}, Alt: false, Paste: false,
		}
	case keyEsc:
		return tea.KeyMsg{
			Type: tea.KeyEsc, Runes: []rune{}, Alt: false, Paste: false,
		}
	case keyCtrlC:
		return tea.KeyMsg{
			Type: tea.KeyCtrlC, Runes: []rune{}, Alt: false, Paste: false,
		}
	case keySpace:
		return tea.KeyMsg{
			Type: tea.KeyRunes, Runes: []rune{' '}, Alt: false, Paste: false,
		}
	default:
		return tea.KeyMsg{
			Type: tea.KeyRunes, Runes: []rune(name), Alt: false, Paste: false,
		}
	}
}

func entries() []tui.Item {
	return []tui.Item{
		{
			Key:     firstFolder,
			Name:    firstName,
			Version: "0.2.0",
			Slot:    firstSlot,
		},
		{
			Key:     "fixture-to-channel",
			Name:    secondName,
			Version: "0.2.0",
			Slot:    secondSlot,
		},
	}
}

func versions() []mahome.Version {
	return []mahome.Version{
		{Text: versionOne, Parts: []int{majorPart, minorPart, patchPart}},
		{Text: versionTwo, Parts: []int{majorPart, tenPart, 0}},
	}
}

func press(model tui.Model, names ...string) tui.Model {
	for _, name := range names {
		updated, _ := model.Update(key(name))

		next, ok := updated.(tui.Model)
		if !ok {
			return model
		}

		model = next
	}

	return model
}

func TestTheModelStartsOnThePlugins(t *testing.T) {
	t.Parallel()

	model := tui.New(entries(), versions())

	view := model.View()

	if !strings.Contains(view, "Plugins") {
		t.Errorf("View() = %q, want the plugins", view)
	}

	if !strings.Contains(view, firstName) {
		t.Errorf("View() = %q, want the first plugin", view)
	}
}

func TestTheCursorMovesDown(t *testing.T) {
	t.Parallel()

	model := press(tui.New(entries(), versions()), keyDown)

	view := model.View()

	if !strings.Contains(view, "> [ ] "+secondName) {
		t.Errorf("View() = %q, want the cursor on the second plugin", view)
	}
}

func TestTheCursorStaysInsideTheList(t *testing.T) {
	t.Parallel()

	model := press(tui.New(entries(), versions()), keyUp)

	view := model.View()

	if !strings.Contains(view, "> [ ] "+firstName) {
		t.Errorf("View() = %q, want the cursor on the first plugin", view)
	}
}

func TestSpacePicksAPlugin(t *testing.T) {
	t.Parallel()

	model := press(tui.New(entries(), versions()), keySpace)

	view := model.View()

	if !strings.Contains(view, "> [x] "+firstName) {
		t.Errorf("View() = %q, want the plugin picked", view)
	}
}

func TestEnterGoesToTheVersions(t *testing.T) {
	t.Parallel()

	model := press(tui.New(entries(), versions()), keySpace, keyEnter)

	view := model.View()

	if !strings.Contains(view, versionOne) {
		t.Errorf("View() = %q, want the versions", view)
	}

	if strings.Contains(view, firstName) {
		t.Errorf("View() = %q, want no plugins", view)
	}
}

func TestEnterWithoutAPickStaysOnThePlugins(t *testing.T) {
	t.Parallel()

	model := press(tui.New(entries(), versions()), keyEnter)

	view := model.View()

	if !strings.Contains(view, firstName) {
		t.Errorf(wantPlugins, view)
	}
}

func TestEscGoesBackToThePlugins(t *testing.T) {
	t.Parallel()

	model := press(
		tui.New(entries(), versions()), keySpace, keyEnter, keyEsc)

	view := model.View()

	if !strings.Contains(view, firstName) {
		t.Errorf(wantPlugins, view)
	}
}

func TestTheSelectionHasThePickedPluginAndVersion(t *testing.T) {
	t.Parallel()

	model := press(
		tui.New(entries(), versions()),
		keySpace, keyEnter, keyDown, keyEnter)

	got, err := model.Selection()
	if err != nil {
		t.Fatalf("Selection() error = %v", err)
	}

	if len(got.Items) != 1 {
		t.Fatalf("Selection() = %d plugins, want 1", len(got.Items))
	}

	if got.Items[0].Key != firstFolder {
		t.Errorf("Key = %q, want %q", got.Items[0].Key, firstFolder)
	}

	if got.Version.Text != versionTwo {
		t.Errorf("Version = %q, want %q", got.Version.Text, versionTwo)
	}
}

func TestTheSelectionIsEmptyWhenTheUserQuits(t *testing.T) {
	t.Parallel()

	model := press(tui.New(entries(), versions()), keyQuit)

	_, err := model.Selection()
	if err == nil {
		t.Error("Selection() error = nil, want an error")
	}
}

func TestQuitStopsTheProgram(t *testing.T) {
	t.Parallel()

	_, cmd := tui.New(entries(), versions()).Update(key(keyQuit))

	if cmd == nil {
		t.Fatal("Update() command = nil, want the quit command")
	}

	if _, ok := cmd().(tea.QuitMsg); !ok {
		t.Error("Update() command does not quit")
	}
}

func TestCtrlCStopsTheProgram(t *testing.T) {
	t.Parallel()

	_, cmd := tui.New(entries(), versions()).Update(key(keyCtrlC))

	if cmd == nil {
		t.Fatal("Update() command = nil, want the quit command")
	}

	if _, ok := cmd().(tea.QuitMsg); !ok {
		t.Error("Update() command does not quit")
	}
}
