package rules

import "strings"

const (
	luaLineComment    = "--"
	escapedCharLength = 2
)

func luaCommentViolations(text string) []Violation {
	found := []Violation{}

	index := 0
	for index < len(text) {
		switch {
		case hasPrefixAt(text, index, luaLineComment):
			found = append(found, Violation{
				Line: lineAt(text, index),
				Rule: RuleComment,
			})
			index = luaCommentEnd(text, index) + 1
		case text[index] == '"' || text[index] == '\'':
			index = quotedEnd(text, index) + 1
		case text[index] == '[':
			index = luaBracketStep(text, index)
		default:
			index++
		}
	}

	return found
}

func luaBracketStep(text string, index int) int {
	end := luaLongBracketEnd(text, index)
	if end == 0 {
		return index + 1
	}

	return end + 1
}

func luaCommentEnd(text string, position int) int {
	afterDashes := position + len(luaLineComment)
	if end := luaLongBracketEnd(text, afterDashes); end != 0 {
		return end
	}

	if end := strings.Index(text[afterDashes:], "\n"); end >= 0 {
		return afterDashes + end
	}

	return len(text)
}

func luaLongBracketEnd(text string, position int) int {
	level, ok := luaBracketLevel(text, position)
	if !ok {
		return 0
	}

	closing := "]" + strings.Repeat("=", level) + "]"

	found := strings.Index(text[position:], closing)
	if found < 0 {
		return len(text)
	}

	return position + found + len(closing) - 1
}

func luaBracketLevel(text string, position int) (int, bool) {
	if position >= len(text) || text[position] != '[' {
		return 0, false
	}

	index := position + 1

	level := 0
	for index < len(text) && text[index] == '=' {
		level++
		index++
	}

	if index < len(text) && text[index] == '[' {
		return level, true
	}

	return 0, false
}

func quotedEnd(text string, position int) int {
	quote := text[position]

	index := position + 1
	for index < len(text) {
		switch text[index] {
		case '\\':
			index += escapedCharLength
		case quote, '\n':
			return index
		default:
			index++
		}
	}

	return len(text)
}

func hasPrefixAt(text string, index int, prefix string) bool {
	return strings.HasPrefix(text[index:], prefix)
}
