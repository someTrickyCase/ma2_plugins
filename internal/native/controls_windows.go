package native

import (
	"errors"
	"fmt"

	"github.com/lxn/walk"
)

const (
	windowWidth  = 720
	windowHeight = 480
	slotWidth    = 100
	resultHeight = 340
)

func dialog(title string) (*walk.Dialog, error) {
	one, err := walk.NewDialog(nil)
	if err != nil {
		return nil, fmt.Errorf("create installer window: %w", err)
	}

	err = errors.Join(one.SetTitle(title), one.SetLayout(walk.NewVBoxLayout()),
		one.SetSize(walk.Size{Width: windowWidth, Height: windowHeight}),
		one.SetMinMaxSize(walk.Size{Width: windowWidth, Height: windowHeight},
			walk.Size{Width: 0, Height: 0}))
	if err != nil {
		one.Dispose()

		return nil, fmt.Errorf("configure installer window: %w", err)
	}

	return one, nil
}

func label(parent walk.Container, text string) error {
	one, err := walk.NewLabel(parent)
	if err != nil {
		return fmt.Errorf("create installer label: %w", err)
	}

	err = one.SetText(text)
	if err != nil {
		return fmt.Errorf("set installer label: %w", err)
	}

	return nil
}

func button(
	parent walk.Container, text string, clicked func(),
) (*walk.PushButton, error) {
	one, err := walk.NewPushButton(parent)
	if err != nil {
		return nil, fmt.Errorf("create installer button: %w", err)
	}

	err = one.SetText(text)
	if err != nil {
		return nil, fmt.Errorf("set installer button: %w", err)
	}

	one.Clicked().Attach(clicked)

	return one, nil
}
