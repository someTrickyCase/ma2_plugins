package main

import (
	"os"

	"github.com/someTrickyCase/ma2_plugins/internal/setup"
	"github.com/someTrickyCase/ma2_plugins/internal/tui"
)

func main() {
	os.Exit(setup.Run(os.Args[1:], os.Stdout, os.Stderr, tui.Run))
}
