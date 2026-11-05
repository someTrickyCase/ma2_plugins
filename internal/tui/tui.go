package tui

import (
	"errors"
	"fmt"
	"io"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/someTrickyCase/ma2_plugins/internal/mahome"
)

var errNoModel = errors.New("the installer is not the model we made")

func Run(
	output io.Writer,
	plugins []Item,
	versions []mahome.Version,
) (Selection, error) {
	model := New(plugins, versions)

	program := tea.NewProgram(model, tea.WithOutput(output))

	final, err := program.Run()
	if err != nil {
		return Selection{}, fmt.Errorf("the installer stopped: %w", err)
	}

	done, ok := final.(Model)
	if !ok {
		return Selection{}, errNoModel
	}

	return done.Selection()
}
