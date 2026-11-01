package cli

import (
	"fmt"
	"io"
	"path/filepath"
	"strings"

	"github.com/someTrickyCase/ma2_plugins/internal/readfile"
	"github.com/someTrickyCase/ma2_plugins/internal/rules"
)

func runCheckRules(paths []string, stdout, stderr io.Writer) int {
	if len(paths) == 0 {
		return showUsage(stderr, "check-rules needs at least one file")
	}

	files, problem := readRuleFiles(paths)
	if problem != "" {
		return showUsage(stderr, problem)
	}

	lines := rules.Report(files)
	for _, line := range lines {
		_, _ = fmt.Fprintln(stdout, line)
	}

	if len(lines) > 0 {
		return ExitViolations
	}

	return ExitOK
}

func readRuleFiles(paths []string) ([]rules.File, string) {
	files := []rules.File{}

	for _, path := range paths {
		language, known := languageFor(path)
		if !known {
			return nil, fmt.Sprintf("unknown file type %q", path)
		}

		text, err := readfile.Read(path)
		if err != nil {
			return nil, fmt.Sprintf("cannot read %q: %v", path, err)
		}

		files = append(files, rules.File{
			Path:     path,
			Text:     string(text),
			Language: language,
		})
	}

	return files, ""
}

func languageFor(path string) (rules.Language, bool) {
	switch strings.ToLower(filepath.Ext(path)) {
	case ".lua":
		return rules.Lua, true
	case ".go":
		return rules.Golang, true
	default:
		return rules.Lua, false
	}
}
