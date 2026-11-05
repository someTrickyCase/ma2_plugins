package main

import (
	"os"
	"runtime"

	"github.com/someTrickyCase/ma2_plugins/internal/native"
	"github.com/someTrickyCase/ma2_plugins/internal/setup"
)

func runPlatform(args []string) int {
	runtime.LockOSThread()

	defer runtime.UnlockOSThread()

	return setup.Interactive(args, os.Stdout, os.Stderr,
		native.Pick, native.ShowResult)
}
