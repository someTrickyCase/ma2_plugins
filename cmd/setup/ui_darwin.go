package main

import (
	"os"

	"github.com/someTrickyCase/ma2_plugins/internal/setup"
	"github.com/someTrickyCase/ma2_plugins/internal/tui"
)

func runPlatform(args []string) int {
	show := func(text string) error {
		return tui.ShowResult(os.Stdout, text)
	}

	return setup.Interactive(args, os.Stdout, os.Stderr, tui.Run, show)
}
