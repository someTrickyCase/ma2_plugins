package cli

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/someTrickyCase/ma2_plugins/internal/buildinfo"
	"github.com/someTrickyCase/ma2_plugins/internal/bundle"
	"github.com/someTrickyCase/ma2_plugins/internal/manifest"
)

var errDuplicateBundleFile = errors.New("duplicate plugin file base")

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

	if args[0] == "--all" {
		return runBundleAll(args[1:], stdout, stderr)
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

	lines, err := bundle.Instructions(plugin.Manifest, *slot)
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

func runBundleAll(args []string, stdout, stderr io.Writer) int {
	entries, err := manifest.ReadEntries(".")
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	if len(entries) == 0 {
		return showUsage(stderr, "no plugins found")
	}

	err = validateBundleEntries(entries)
	if err != nil {
		return showUsage(stderr, err.Error())
	}

	for _, entry := range entries {
		one := append([]string{entry.Folder}, args...)

		code := runBundle(one, stdout, stderr)
		if code != ExitOK {
			return code
		}
	}

	return ExitOK
}

func validateBundleEntries(entries []manifest.Entry) error {
	seen := map[string]bool{}

	for _, entry := range entries {
		err := manifest.ValidateFile(entry.Manifest.File)
		if err != nil {
			return fmt.Errorf("invalid bundle entry: %w", err)
		}

		key := strings.ToLower(entry.Manifest.File)
		if seen[key] {
			return fmt.Errorf(
				"%w: %s", errDuplicateBundleFile, entry.Manifest.File,
			)
		}

		seen[key] = true
	}

	return nil
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
	err := manifest.ValidateFile(plugin.Manifest.File)
	if err != nil {
		return bundleFiles{}, fmt.Errorf("cannot bundle plugin: %w", err)
	}

	base := filepath.Join(folder, plugin.Manifest.File)

	luaPath := filepath.ToSlash(base + ".lua")
	xmlPath := filepath.ToSlash(base + ".xml")

	err = os.MkdirAll(folder, dirPermission)
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
