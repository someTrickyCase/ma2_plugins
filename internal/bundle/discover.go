package bundle

import (
	"errors"
	"fmt"
	"regexp"
	"strings"
)

var requirePattern = regexp.MustCompile(
	`(?m)^[ \t]*(?:local [A-Za-z0-9_]+[ \t]*=[ \t]*|` +
		`[A-Za-z0-9_]+[ \t]*=[ \t]*)?require\("([A-Za-z0-9._-]+)"\)`,
)

var errMissingModule = errors.New("missing project module")

func missingProjectModule(name string, importer string) error {
	if strings.HasPrefix(name, "core.") || strings.HasPrefix(name, "ma.") {
		return fmt.Errorf(
			"%w %q required by %s", errMissingModule, name, importer,
		)
	}

	return nil
}

func appendModule(
	name string,
	read Reader,
	found []Module,
	seen map[string]bool,
	importer string,
) ([]Module, error) {
	moduleText, ok := read(ModulePath(name))
	if !ok {
		return found, missingProjectModule(name, importer)
	}

	found = append(found, Module{Name: name, Text: moduleText})

	return discover(moduleText, read, found, seen, ModulePath(name))
}

func discover(
	text string,
	read Reader,
	found []Module,
	seen map[string]bool,
	importer string,
) ([]Module, error) {
	for _, match := range requirePattern.FindAllStringSubmatch(text, -1) {
		name := match[1]

		if seen[name] {
			continue
		}

		seen[name] = true

		var err error

		found, err = appendModule(name, read, found, seen, importer)
		if err != nil {
			return nil, err
		}
	}

	return found, nil
}
