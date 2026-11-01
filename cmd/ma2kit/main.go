package main

import (
	"os"

	"github.com/someTrickyCase/ma2_plugins/internal/cli"
)

func main() {
	os.Exit(cli.Run(os.Args[1:], os.Stdout, os.Stderr))
}
