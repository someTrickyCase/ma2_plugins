package rules

import (
	"cmp"
	"fmt"
	"slices"
	"strings"
)

type Language int

const (
	Lua Language = iota
	Golang
)

type Rule string

const (
	RuleASCII   Rule = "ascii"
	RuleComment Rule = "comment"
)

const (
	firstPrintable = 0x20
	lastPrintable  = 0x7E
	tab            = 0x09
)

type Violation struct {
	Line int
	Rule Rule
}

type File struct {
	Path     string
	Text     string
	Language Language
}

func Find(text string, language Language) []Violation {
	found := commentViolations(text, language)
	found = append(found, asciiViolations(text, language)...)
	slices.SortFunc(found, func(first, second Violation) int {
		if first.Line != second.Line {
			return cmp.Compare(first.Line, second.Line)
		}

		return cmp.Compare(first.Rule, second.Rule)
	})

	return found
}

func Report(files []File) []string {
	lines := []string{}

	for _, file := range files {
		for _, violation := range Find(file.Text, file.Language) {
			lines = append(lines, fmt.Sprintf(
				"%s:%d: %s: %s",
				file.Path,
				violation.Line,
				violation.Rule,
				message(violation.Rule),
			))
		}
	}

	return lines
}

func message(rule Rule) string {
	switch rule {
	case RuleASCII:
		return "only printable ASCII characters are allowed"
	case RuleComment:
		return "code must explain itself, no comments"
	default:
		return "unknown rule"
	}
}

func commentViolations(text string, language Language) []Violation {
	switch language {
	case Lua:
		return luaCommentViolations(text)
	case Golang:
		return goCommentViolations(text)
	default:
		return []Violation{}
	}
}

func asciiViolations(text string, language Language) []Violation {
	lines := strings.Split(text, "\n")

	found := make([]Violation, 0, len(lines))
	for number, line := range lines {
		if hasNonPrintable(line, language) {
			found = append(found, Violation{Line: number + 1, Rule: RuleASCII})
		}
	}

	return found
}

func hasNonPrintable(line string, language Language) bool {
	for _, char := range line {
		if char == tab && language == Golang {
			continue
		}

		if char < firstPrintable || char > lastPrintable {
			return true
		}
	}

	return false
}

func lineAt(text string, position int) int {
	return strings.Count(text[:position], "\n") + 1
}
