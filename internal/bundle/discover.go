package bundle

import "regexp"

var requirePattern = regexp.MustCompile(`require\("([A-Za-z0-9._-]+)"\)`)

func discover(
	text string,
	read Reader,
	found []Module,
	seen map[string]bool,
) []Module {
	for _, match := range requirePattern.FindAllStringSubmatch(text, -1) {
		name := match[1]

		if seen[name] {
			continue
		}

		seen[name] = true

		moduleText, ok := read(ModulePath(name))
		if !ok {
			continue
		}

		found = append(found, Module{Name: name, Text: moduleText})
		found = discover(moduleText, read, found, seen)
	}

	return found
}
