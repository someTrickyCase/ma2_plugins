package rules

import "strings"

const (
	goLineComment = "//"
	goBlockStart  = "/*"
	goBlockEnd    = "*/"
	goRawQuote    = '`'
)

func goCommentViolations(text string) []Violation {
	found := []Violation{}

	index := 0
	for index < len(text) {
		switch {
		case hasPrefixAt(text, index, goBlockStart):
			found = append(found, Violation{
				Line: lineAt(text, index),
				Rule: RuleComment,
			})
			index = goBlockEndAt(text, index) + 1
		case hasPrefixAt(text, index, goLineComment):
			found = append(found, Violation{
				Line: lineAt(text, index),
				Rule: RuleComment,
			})
			index = goLineEnd(text, index) + 1
		case text[index] == '"' || text[index] == '\'':
			index = quotedEnd(text, index) + 1
		case text[index] == goRawQuote:
			index = rawStringEnd(text, index) + 1
		default:
			index++
		}
	}

	return found
}

func goLineEnd(text string, position int) int {
	found := strings.Index(text[position:], "\n")
	if found < 0 {
		return len(text)
	}

	return position + found
}

func goBlockEndAt(text string, position int) int {
	search := position + len(goBlockStart)

	found := strings.Index(text[search:], goBlockEnd)
	if found < 0 {
		return len(text)
	}

	return search + found + len(goBlockEnd) - 1
}

func rawStringEnd(text string, position int) int {
	found := strings.IndexByte(text[position+1:], goRawQuote)
	if found < 0 {
		return len(text)
	}

	return position + 1 + found
}
