package install

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/someTrickyCase/ma2_plugins/internal/bundle"
	"github.com/someTrickyCase/ma2_plugins/internal/rules"
)

const (
	ourPrefix      = "k-"
	dirPermission  = 0o750
	filePermission = 0o600
)

var (
	ErrRules   = errors.New("the built file breaks the code rules")
	errNotOurs = errors.New("the file name must start with k-")
)

type Request struct {
	Plugin bundle.Plugin
	Slot   int
	Folder string
	DryRun bool
}

type Result struct {
	Folder       string
	Files        []string
	Instructions []string
	DryRun       bool
}

type target struct {
	path string
	text string
}

func Do(req Request) (Result, error) {
	name := req.Plugin.Manifest.File

	lua := bundle.Lua(req.Plugin)
	xml := bundle.XML(req.Plugin)

	err := checkRules(name+".lua", lua)
	if err != nil {
		return Result{}, err
	}

	err = checkOurName(name)
	if err != nil {
		return Result{}, err
	}

	instructions, err := bundle.Instructions(req.Plugin, req.Slot)
	if err != nil {
		return Result{}, fmt.Errorf("cannot build the commands: %w", err)
	}

	targets := []target{
		{path: filepath.Join(req.Folder, name+".lua"), text: lua},
		{path: filepath.Join(req.Folder, name+".xml"), text: xml},
	}

	if !req.DryRun {
		err = writeFiles(targets)
		if err != nil {
			return Result{}, err
		}
	}

	return Result{
		Folder:       req.Folder,
		Files:        pathsOf(targets),
		Instructions: instructions,
		DryRun:       req.DryRun,
	}, nil
}

func pathsOf(targets []target) []string {
	paths := make([]string, 0, len(targets))

	for _, one := range targets {
		paths = append(paths, one.path)
	}

	return paths
}

func checkRules(path string, text string) error {
	report := rules.Report([]rules.File{{
		Path:     path,
		Text:     text,
		Language: rules.Lua,
	}})

	if len(report) == 0 {
		return nil
	}

	return fmt.Errorf("%w:\n%s", ErrRules, strings.Join(report, "\n"))
}

func checkOurName(name string) error {
	if !strings.HasPrefix(name, ourPrefix) {
		return fmt.Errorf("%w: %q", errNotOurs, name)
	}

	return nil
}

func writeFiles(targets []target) error {
	err := os.MkdirAll(filepath.Dir(targets[0].path), dirPermission)
	if err != nil {
		return fmt.Errorf("cannot create the folder: %w", err)
	}

	for _, one := range targets {
		err := os.WriteFile(one.path, []byte(one.text), filePermission)
		if err != nil {
			return fmt.Errorf("cannot write %q: %w", one.path, err)
		}
	}

	return nil
}
