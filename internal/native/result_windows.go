package native

import (
	"errors"
	"fmt"
	"strings"

	"github.com/lxn/walk"
)

func ShowResult(text string) error {
	window, err := dialog("MA2 installation result")
	if err != nil {
		return err
	}
	defer window.Dispose()

	err = resultContents(window, text)
	if err != nil {
		return err
	}

	window.Run()

	return nil
}

func resultContents(window *walk.Dialog, text string) error {
	err := label(window,
		"Copy the import commands into MA2. Close this window when ready.")
	if err != nil {
		return err
	}

	commands, err := walk.NewTextEdit(window)
	if err != nil {
		return fmt.Errorf("create result text: %w", err)
	}

	err = errors.Join(commands.SetReadOnly(true),
		commands.SetMinMaxSize(walk.Size{Width: 0, Height: resultHeight},
			walk.Size{Width: 0, Height: 0}),
		commands.SetText(strings.ReplaceAll(text, "\n", "\r\n")))
	if err != nil {
		return fmt.Errorf("set result text: %w", err)
	}

	closeButton, err := button(window, "Close", window.Accept)
	if err != nil {
		return err
	}

	err = errors.Join(window.SetDefaultButton(closeButton),
		window.SetCancelButton(closeButton))
	if err != nil {
		return fmt.Errorf("configure Close button: %w", err)
	}

	return nil
}
