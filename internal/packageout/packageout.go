package packageout

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/someTrickyCase/ma2_plugins/internal/manifest"
)

var (
	errUnexpected = errors.New("unexpected distribution file")
	errMissing    = errors.New("missing distribution file")
	errBackup     = errors.New("previous package backup still exists")
	errEmpty      = errors.New("empty distribution manifest")
	errDuplicate  = errors.New("duplicate staged plugin")
)

const (
	folderMode = 0o750
	namedError = "%w: %s"
)

type locations struct {
	stage  string
	target string
	backup string
}

func paths(root string) locations {
	dist := filepath.Join(root, "dist")

	return locations{
		stage:  filepath.Join(dist, "bundle-stage"),
		target: filepath.Join(dist, "bundle"),
		backup: filepath.Join(dist, "bundle-previous"),
	}
}

func Prepare(root string) error {
	stage := paths(root).stage

	err := os.RemoveAll(stage)
	if err != nil {
		return fmt.Errorf("remove old staging folder: %w", err)
	}

	err = os.MkdirAll(stage, folderMode)
	if err != nil {
		return fmt.Errorf("create staging folder: %w", err)
	}

	return nil
}

func Verify(stage string) error {
	want, err := expected(stage)
	if err != nil {
		return err
	}

	entries, err := os.ReadDir(stage)
	if err != nil {
		return fmt.Errorf("read staging folder: %w", err)
	}

	return compare(entries, want)
}

func expected(stage string) (map[string]bool, error) {
	plugins, err := manifest.ReadList(filepath.Join(stage, manifest.ListFile))
	if err != nil {
		return nil, fmt.Errorf("read staged manifest: %w", err)
	}

	if len(plugins) == 0 {
		return nil, errEmpty
	}

	want := map[string]bool{manifest.ListFile: true}

	installer := "install"
	if runtime.GOOS == "windows" {
		installer += ".exe"
	}

	want[installer] = true

	err = addExpectedPlugins(plugins, want)
	if err != nil {
		return nil, err
	}

	return want, nil
}

func addExpectedPlugins(
	plugins []manifest.Manifest, want map[string]bool,
) error {
	seen := map[string]bool{}

	for _, plugin := range plugins {
		err := manifest.ValidateFile(plugin.File)
		if err != nil {
			return fmt.Errorf("invalid staged plugin: %w", err)
		}

		key := strings.ToLower(plugin.File)
		if seen[key] {
			return fmt.Errorf("%w: %s", errDuplicate, plugin.File)
		}

		seen[key] = true

		want[plugin.File+".lua"] = true
		want[plugin.File+".xml"] = true
	}

	return nil
}

func compare(entries []os.DirEntry, want map[string]bool) error {
	for _, entry := range entries {
		if entry.IsDir() || !want[entry.Name()] {
			return fmt.Errorf(namedError, errUnexpected, entry.Name())
		}

		delete(want, entry.Name())
	}

	for name := range want {
		return fmt.Errorf(namedError, errMissing, name)
	}

	return nil
}

func Promote(root string) error {
	paths := paths(root)

	err := Verify(paths.stage)
	if err != nil {
		return err
	}

	previous, err := savePrevious(paths.target, paths.backup)
	if err != nil {
		return err
	}

	return installStage(paths.stage, paths.target, previous)
}

func savePrevious(target string, backup string) (string, error) {
	_, err := os.Stat(backup)
	if err == nil {
		return "", fmt.Errorf(namedError, errBackup, backup)
	}

	if !errors.Is(err, os.ErrNotExist) {
		return "", fmt.Errorf("check package backup: %w", err)
	}

	_, err = os.Stat(target)
	if err == nil {
		err = os.Rename(target, backup)
		if err != nil {
			return "", fmt.Errorf("save previous package: %w", err)
		}

		return backup, nil
	} else if !errors.Is(err, os.ErrNotExist) {
		return "", fmt.Errorf("check previous package: %w", err)
	}

	return "", nil
}

func installStage(stage string, target string, previous string) error {
	err := os.Rename(stage, target)
	if err != nil {
		if previous != "" {
			_ = os.Rename(previous, target)
		}

		return fmt.Errorf("promote staged package: %w", err)
	}

	if previous != "" {
		err = os.RemoveAll(previous)
		if err != nil {
			return fmt.Errorf("remove previous package: %w", err)
		}
	}

	return nil
}
