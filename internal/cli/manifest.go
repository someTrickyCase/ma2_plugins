package cli

import (
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/someTrickyCase/ma2_plugins/internal/manifest"
)

func runManifest(args []string, stdout, stderr io.Writer) int {
	flags := flag.NewFlagSet("manifest", flag.ContinueOnError)
	flags.SetOutput(stderr)

	out := flags.String("out", defaultFolder, "folder for the manifest")

	err := flags.Parse(args)
	if err != nil {
		return ExitUsage
	}

	all, err := manifest.ReadAll(".")
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	text, err := manifest.FormatList(all)
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	err = os.MkdirAll(*out, dirPermission)
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	path := filepath.Join(*out, manifest.ListFile)

	err = os.WriteFile(path, text, filePermission)
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	_, _ = fmt.Fprintln(stdout, filepath.ToSlash(path))

	return ExitOK
}
