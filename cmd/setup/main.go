package main

import (
	"os"
)

func main() {
	os.Exit(runPlatform(os.Args[1:]))
}
