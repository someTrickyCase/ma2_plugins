package tui

import (
	"fmt"
	"io"

	tea "github.com/charmbracelet/bubbletea"
)

type Result struct {
	text string
}

func NewResult(text string) Result {
	return Result{text: text}
}

func (Result) Init() tea.Cmd {
	return nil
}

func (model Result) Update(message tea.Msg) (tea.Model, tea.Cmd) {
	key, ok := message.(tea.KeyMsg)
	if !ok {
		return model, nil
	}

	switch key.String() {
	case keyEnter, keyEsc, keyQuit, keyCtrlC:
		return model, tea.Quit
	default:
		return model, nil
	}
}

func (model Result) View() string {
	return model.text + "\n\nCopy the MA2 commands above. Enter: close"
}

func ShowResult(output io.Writer, text string) error {
	program := tea.NewProgram(NewResult(text), tea.WithOutput(output))

	_, err := program.Run()
	if err != nil {
		return fmt.Errorf("cannot show installer result: %w", err)
	}

	return nil
}
