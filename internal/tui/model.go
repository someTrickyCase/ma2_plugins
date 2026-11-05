package tui

import (
	"errors"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/someTrickyCase/ma2_plugins/internal/mahome"
)

const (
	keyUp    = "up"
	keyDown  = "down"
	keySpace = " "
	keyEnter = "enter"
	keyEsc   = "esc"
	keyQuit  = "q"
	keyCtrlC = "ctrl+c"
	moveUp   = -1
	moveDown = 1
)

var errNoChoice = errors.New("nothing was chosen")

type step int

const (
	stepPlugins step = iota
	stepVersions
	stepSlot
	stepDone
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

type Model struct {
	plugins  []Item
	versions []mahome.Version
	chosen   []bool
	cursor   int
	step     step
	picked   int
	slotText string
	problem  string
}

func New(plugins []Item, versions []mahome.Version) Model {
	return Model{
		plugins:  plugins,
		versions: versions,
		chosen:   make([]bool, len(plugins)),
		cursor:   0,
		step:     stepPlugins,
		picked:   0,
		slotText: "",
		problem:  "",
	}
}

func (Model) Init() tea.Cmd {
	return nil
}

func (model Model) Update(message tea.Msg) (tea.Model, tea.Cmd) {
	key, ok := message.(tea.KeyMsg)
	if !ok {
		return model, nil
	}

	if model.step == stepPlugins {
		return model.pluginKey(key)
	}

	if model.step == stepVersions {
		return model.versionKey(key)
	}

	if model.step == stepSlot {
		return model.slotKey(key)
	}

	return model, nil
}

func (model Model) Selection() (Selection, error) {
	if model.step != stepDone {
		return Selection{}, errNoChoice
	}

	if model.picked >= len(model.versions) {
		return Selection{}, errNoChoice
	}

	plugins := []Item{}

	for index, item := range model.plugins {
		if model.chosen[index] {
			plugins = append(plugins, item)
		}
	}

	return Selection{
		Items:   plugins,
		Version: model.versions[model.picked],
	}, nil
}

func (model Model) pluginKey(key tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch key.String() {
	case keyCtrlC, keyQuit, keyEsc:
		return model, tea.Quit
	case keyUp:
		return model.move(moveUp), nil
	case keyDown:
		return model.move(moveDown), nil
	case keySpace:
		return model.toggle(), nil
	case "s":
		if len(model.plugins) == 0 {
			return model, nil
		}

		model.step = stepSlot
		model.slotText = ""
		model.problem = ""

		return model, nil
	case keyEnter:
		return model.next(), nil
	default:
		return model, nil
	}
}

func (model Model) versionKey(key tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch key.String() {
	case keyCtrlC, keyQuit:
		return model, tea.Quit
	case keyEsc:
		return model.back(), nil
	case keyUp:
		return model.move(moveUp), nil
	case keyDown:
		return model.move(moveDown), nil
	case keyEnter:
		return model.pick(), tea.Quit
	default:
		return model, nil
	}
}

func (model Model) move(delta int) Model {
	next := model.cursor + delta

	if next < 0 || next >= model.length() {
		return model
	}

	model.cursor = next

	return model
}

func (model Model) length() int {
	if model.step == stepVersions {
		return len(model.versions)
	}

	return len(model.plugins)
}

func (model Model) toggle() Model {
	chosen := make([]bool, len(model.chosen))
	copy(chosen, model.chosen)

	if model.cursor < len(chosen) {
		chosen[model.cursor] = !chosen[model.cursor]
	}

	model.chosen = chosen

	return model
}

func (model Model) next() Model {
	if !model.anyChosen() {
		return model
	}

	err := ValidateItems(model.selected())
	if err != nil {
		model.problem = err.Error()

		return model
	}

	model.step = stepVersions
	model.cursor = 0

	return model
}

func (model Model) selected() []Item {
	items := []Item{}

	for index, item := range model.plugins {
		if model.chosen[index] {
			items = append(items, item)
		}
	}

	return items
}

func (model Model) back() Model {
	model.step = stepPlugins
	model.cursor = 0

	return model
}

func (model Model) pick() Model {
	model.picked = model.cursor
	model.step = stepDone

	return model
}

func (model Model) anyChosen() bool {
	for _, one := range model.chosen {
		if one {
			return true
		}
	}

	return false
}
