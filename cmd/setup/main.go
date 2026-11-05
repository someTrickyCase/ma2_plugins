package main

import (
	"os"

	"github.com/someTrickyCase/ma2_plugins/internal/setup"
	"github.com/someTrickyCase/ma2_plugins/internal/tui"
)

func main() {
	show := func(text string) error {
		return tui.ShowResult(os.Stdout, text)
	}

	os.Exit(setup.Interactive(
		os.Args[1:], os.Stdout, os.Stderr, tui.Run, show))
}
