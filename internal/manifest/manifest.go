package manifest

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"path/filepath"
	"regexp"

	"github.com/someTrickyCase/ma2_plugins/internal/readfile"
)

var errInvalidFile = errors.New("invalid plugin file base")

var filePattern = regexp.MustCompile(`^k-[a-z0-9-]+$`)

func ValidateFile(name string) error {
	if !filePattern.MatchString(name) {
		return fmt.Errorf("%w %q", errInvalidFile, name)
	}

	return nil
}

const (
	pluginFolder = "plugins"
	fileName     = "plugin.json"
	ListFile     = "plugins.json"
	indent       = "  "
)

type Manifest struct {
	Name    string `json:"name"`
	File    string `json:"file"`
	Version string `json:"version"`
	Slot    int    `json:"slot"`
}

type Entry struct {
	Folder   string
	Manifest Manifest
}

func Path(root string, plugin string) string {
	return filepath.Join(root, pluginFolder, plugin, fileName)
}

func Parse(text string) (Manifest, error) {
	var one Manifest

	err := json.Unmarshal([]byte(text), &one)
	if err != nil {
		return Manifest{}, fmt.Errorf("cannot parse the manifest: %w", err)
	}

	return one, nil
}

func Read(path string) (Manifest, error) {
	data, err := readfile.Read(path)
	if err != nil {
		return Manifest{}, fmt.Errorf(
			"cannot read the manifest %q: %w", path, err)
	}

	return Parse(string(data))
}

func ReadAll(root string) ([]Manifest, error) {
	entries, err := ReadEntries(root)
	if err != nil {
		return nil, err
	}

	all := []Manifest{}

	for _, entry := range entries {
		all = append(all, entry.Manifest)
	}

	return all, nil
}

func ReadEntries(root string) ([]Entry, error) {
	pattern := filepath.Join(root, pluginFolder, "*", fileName)

	paths, err := filepath.Glob(pattern)
	if err != nil {
		return nil, fmt.Errorf("cannot list the plugins: %w", err)
	}

	all := []Entry{}

	for _, path := range paths {
		one, err := Read(path)
		if err != nil {
			return nil, err
		}

		folder := filepath.Base(filepath.Dir(path))

		all = append(all, Entry{Folder: folder, Manifest: one})
	}

	return all, nil
}

func Format(one Manifest) ([]byte, error) {
	var buffer bytes.Buffer

	encoder := json.NewEncoder(&buffer)
	encoder.SetEscapeHTML(false)
	encoder.SetIndent("", indent)

	err := encoder.Encode(one)
	if err != nil {
		return nil, fmt.Errorf("cannot write the manifest: %w", err)
	}

	return buffer.Bytes(), nil
}

type list struct {
	Plugins []Manifest `json:"plugins"`
}

func ReadList(path string) ([]Manifest, error) {
	data, err := readfile.Read(path)
	if err != nil {
		return nil, fmt.Errorf("cannot read %q: %w", path, err)
	}

	var one list

	err = json.Unmarshal(data, &one)
	if err != nil {
		return nil, fmt.Errorf("cannot parse %q: %w", path, err)
	}

	return one.Plugins, nil
}

func FormatList(all []Manifest) ([]byte, error) {
	var buffer bytes.Buffer

	encoder := json.NewEncoder(&buffer)
	encoder.SetEscapeHTML(false)
	encoder.SetIndent("", indent)

	err := encoder.Encode(list{Plugins: all})
	if err != nil {
		return nil, fmt.Errorf("cannot write the list: %w", err)
	}

	return buffer.Bytes(), nil
}
