package bundle

import (
	"errors"
	"fmt"
	"path/filepath"
	"strings"

	"github.com/someTrickyCase/ma2_plugins/internal/manifest"
	"github.com/someTrickyCase/ma2_plugins/internal/readfile"
)

const (
	pluginFolder = "plugins"
	libFolder    = "lib"
	manifestFile = "plugin.json"
	mainFile     = "main.lua"
	slash        = "/"
)

var (
	errMissingFile = errors.New("missing file")
	errBadManifest = errors.New("cannot read the manifest")
)

type Stamp struct {
	Commit string
	Date   string
}

type Module struct {
	Name string
	Text string
}

type Plugin struct {
	Manifest manifest.Manifest
	Main     string
	Modules  []Module
	Stamp    Stamp
}

type Reader func(path string) (string, bool)

func ModulePath(name string) string {
	folder := strings.ReplaceAll(name, ".", slash)

	return libFolder + slash + folder + ".lua"
}

func FileReader(root string) Reader {
	return func(path string) (string, bool) {
		data, err := readfile.Read(filepath.Join(root, path))
		if err != nil {
			return "", false
		}

		return string(data), true
	}
}

func Collect(plugin string, read Reader, stamp Stamp) (Plugin, error) {
	folder := pluginFolder + slash + plugin + slash

	manifestPath := folder + manifestFile

	manifestText, found := read(manifestPath)
	if !found {
		return Plugin{}, fmt.Errorf("%w %s", errMissingFile, manifestPath)
	}

	parsed, err := manifest.Parse(manifestText)
	if err != nil {
		return Plugin{}, fmt.Errorf(
			"%w %s: %w", errBadManifest, manifestPath, err)
	}

	mainPath := folder + mainFile

	main, found := read(mainPath)
	if !found {
		return Plugin{}, fmt.Errorf("%w %s", errMissingFile, mainPath)
	}

	return Plugin{
		Manifest: parsed,
		Main:     main,
		Modules:  discover(main, read, []Module{}, map[string]bool{}),
		Stamp:    stamp,
	}, nil
}
