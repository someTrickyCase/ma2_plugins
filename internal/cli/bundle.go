package cli

import (
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"github.com/someTrickyCase/ma2_plugins/internal/buildinfo"
	"github.com/someTrickyCase/ma2_plugins/internal/bundle"
)

const (
	defaultFolder  = "dist"
	dateLayout     = "2006-01-02"
	dirPermission  = 0o750
	filePermission = 0o600
)

func runBundle(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return showUsage(stderr, "bundle needs a plugin name")
	}

	flags := flag.NewFlagSet("bundle", flag.ContinueOnError)
	flags.SetOutput(stderr)

	out := flags.String("out", defaultFolder, "folder for the built files")
	slot := flags.Int("at", 0, "plugin pool slot")
	commit := flags.String("commit", "", "commit for the stamp")
	date := flags.String("date", "", "build date for the stamp")

	err := flags.Parse(args[1:])
	if err != nil {
		return ExitUsage
	}

	plugin, err := bundle.Collect(
		args[0], bundle.FileReader("."), stampOf(*commit, *date))
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	lines, err := bundle.Instructions(plugin, *slot)
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	files, err := writeBundle(*out, plugin)
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	printBundle(stdout, []string{files.lua, files.xml}, lines)

	return ExitOK
}

func stampOf(commit string, date string) bundle.Stamp {
	stamp := bundle.Stamp{
		Commit: buildinfo.Commit(),
		Date:   time.Now().Format(dateLayout),
	}

	if commit != "" {
		stamp.Commit = commit
	}

	if date != "" {
		stamp.Date = date
	}

	return stamp
}

type bundleFiles struct {
	lua string
	xml string
}

func writeBundle(folder string, plugin bundle.Plugin) (bundleFiles, error) {
	base := filepath.Join(folder, plugin.Manifest.File)

	luaPath := filepath.ToSlash(base + ".lua")
	xmlPath := filepath.ToSlash(base + ".xml")

	err := os.MkdirAll(folder, dirPermission)
	if err != nil {
		return bundleFiles{}, fmt.Errorf("cannot create %q: %w", folder, err)
	}

	err = os.WriteFile(luaPath, []byte(bundle.Lua(plugin)), filePermission)
	if err != nil {
		return bundleFiles{}, fmt.Errorf("cannot write %q: %w", luaPath, err)
	}

	err = os.WriteFile(xmlPath, []byte(bundle.XML(plugin)), filePermission)
	if err != nil {
		return bundleFiles{}, fmt.Errorf("cannot write %q: %w", xmlPath, err)
	}

	return bundleFiles{lua: luaPath, xml: xmlPath}, nil
}

func printBundle(stdout io.Writer, paths []string, lines []string) {
	for _, path := range paths {
		_, _ = fmt.Fprintln(stdout, path)
	}

	for _, line := range lines {
		_, _ = fmt.Fprintln(stdout, line)
	}
}
