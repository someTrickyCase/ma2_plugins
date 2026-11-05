package tui

import (
	"errors"
	"fmt"
	"strconv"

	tea "github.com/charmbracelet/bubbletea"
)

var (
	errSlot  = errors.New("plugin slots must be positive whole numbers")
	errTaken = errors.New("selected plugins must have different slots")
)

func ValidateItems(items []Item) error {
	seen := map[int]bool{}

	for _, item := range items {
		if item.Slot <= 0 {
			return errSlot
		}

		if seen[item.Slot] {
			return fmt.Errorf("%w: %d", errTaken, item.Slot)
		}

		seen[item.Slot] = true
	}

	return nil
}

func (model Model) slotKey(key tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch key.String() {
	case keyCtrlC:
		return model, tea.Quit
	case keyEsc:
		model.step = stepPlugins
	case keyEnter:
		return model.saveSlot(), nil
	case "backspace":
		model.slotText = model.slotText[:max(0, len(model.slotText)-1)]
	default:
		if key.Type == tea.KeyRunes {
			model.slotText += string(key.Runes)
		}
	}

	return model, nil
}

func (model Model) saveSlot() Model {
	value, err := strconv.Atoi(model.slotText)
	if err != nil || value <= 0 {
		model.problem = errSlot.Error()

		return model
	}

	items := append([]Item{}, model.plugins...)
	items[model.cursor].Slot = value
	previous := model.plugins
	model.plugins = items

	err = ValidateItems(model.selected())
	if err != nil {
		model.plugins = previous
		model.problem = err.Error()

		return model
	}

	model.step = stepPlugins
	model.problem = ""

	return model
}
