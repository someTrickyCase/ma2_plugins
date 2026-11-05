package box

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/someTrickyCase/ma2_plugins/internal/bundle"
	"github.com/someTrickyCase/ma2_plugins/internal/install"
	"github.com/someTrickyCase/ma2_plugins/internal/manifest"
	"github.com/someTrickyCase/ma2_plugins/internal/readfile"
)

var errEmpty = errors.New("no plugins selected")

var errDuplicate = errors.New("duplicate plugin file")

type pending struct {
	name string
	data []byte
}

const (
	luaSuffix      = ".lua"
	xmlSuffix      = ".xml"
	dirPermission  = 0o750
	filePermission = 0o600
)

type Box struct {
	Folder  string
	Plugins []manifest.Manifest
}

func Read(folder string) (Box, error) {
	path := filepath.Join(folder, manifest.ListFile)

	plugins, err := manifest.ReadList(path)
	if err != nil {
		return Box{}, fmt.Errorf("cannot read the box: %w", err)
	}

	return Box{Folder: folder, Plugins: plugins}, nil
}

func Files(plugin manifest.Manifest) []string {
	return []string{plugin.File + luaSuffix, plugin.File + xmlSuffix}
}

func (one Box) Copy(target string, plugins []manifest.Manifest) error {
	files, err := one.prepare(plugins)
	if err != nil {
		return err
	}

	err = os.MkdirAll(target, dirPermission)
	if err != nil {
		return fmt.Errorf("cannot create %q: %w", target, err)
	}

	for _, file := range files {
		path := filepath.Join(target, file.name)

		err = os.WriteFile(path, file.data, filePermission)
		if err != nil {
			return fmt.Errorf("cannot write %q: %w", path, err)
		}
	}

	return nil
}

func Commands(plugins []manifest.Manifest) ([]string, error) {
	lines := []string{}

	for _, plugin := range plugins {
		text, err := bundle.Instructions(plugin, 0)
		if err != nil {
			return nil, fmt.Errorf("cannot build the commands: %w", err)
		}

		lines = append(lines, plugin.Name+" "+plugin.Version, "")
		lines = append(lines, text...)
		lines = append(lines, "")
	}

	return lines, nil
}

func (one Box) prepare(plugins []manifest.Manifest) ([]pending, error) {
	if len(plugins) == 0 {
		return nil, errEmpty
	}

	_, err := Commands(plugins)
	if err != nil {
		return nil, err
	}

	err = uniqueNames(plugins)
	if err != nil {
		return nil, err
	}

	files := []pending{}

	for _, plugin := range plugins {
		prepared, prepareErr := one.preparePlugin(plugin)
		if prepareErr != nil {
			return nil, prepareErr
		}

		files = append(files, prepared...)
	}

	return files, nil
}

func uniqueNames(plugins []manifest.Manifest) error {
	seen := map[string]bool{}

	for _, plugin := range plugins {
		err := install.Validate(plugin.File, "")
		if err != nil {
			return fmt.Errorf("invalid plugin: %w", err)
		}

		if seen[plugin.File] {
			return fmt.Errorf("%w %q", errDuplicate, plugin.File)
		}

		seen[plugin.File] = true
	}

	return nil
}

func (one Box) preparePlugin(plugin manifest.Manifest) ([]pending, error) {
	files := []pending{}

	for _, name := range Files(plugin) {
		data, err := readfile.Read(filepath.Join(one.Folder, name))
		if err != nil {
			return nil, fmt.Errorf("cannot prepare plugin: %w", err)
		}

		err = validateFile(plugin.File, name, data)
		if err != nil {
			return nil, err
		}

		files = append(files, pending{name: name, data: data})
	}

	return files, nil
}

func validateFile(base string, name string, data []byte) error {
	if filepath.Ext(name) != luaSuffix {
		return nil
	}

	err := install.Validate(base, string(data))
	if err != nil {
		return fmt.Errorf("invalid plugin: %w", err)
	}

	return nil
}
