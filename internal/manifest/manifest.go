package manifest

import (
	"bytes"
	"encoding/json"
	"fmt"
	"path/filepath"

	"github.com/someTrickyCase/ma2_plugins/internal/readfile"
)

const (
	pluginFolder = "plugins"
	fileName     = "plugin.json"
	indent       = "  "
)

type Manifest struct {
	Name    string `json:"name"`
	File    string `json:"file"`
	Version string `json:"version"`
	Slot    int    `json:"slot"`
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
	pattern := filepath.Join(root, pluginFolder, "*", fileName)

	paths, err := filepath.Glob(pattern)
	if err != nil {
		return nil, fmt.Errorf("cannot list the plugins: %w", err)
	}

	all := []Manifest{}

	for _, path := range paths {
		one, err := Read(path)
		if err != nil {
			return nil, err
		}

		all = append(all, one)
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
