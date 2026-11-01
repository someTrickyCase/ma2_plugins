package bundle

import (
	"fmt"
)

const (
	quoteMark       = '"'
	backslash       = '\\'
	newline         = '\n'
	firstControl    = 0x20
	deleteCharacter = 0x7F
	firstDigit      = '0'
	lastDigit       = '9'
	quoteOverhead   = 2
)

func Quote(text string) string {
	out := make([]byte, 0, len(text)+quoteOverhead)
	out = append(out, quoteMark)

	for index := range len(text) {
		out = appendQuoted(out, text[index], byteAt(text, index+1))
	}

	out = append(out, quoteMark)

	return string(out)
}

func appendQuoted(out []byte, char byte, next byte) []byte {
	switch {
	case char == quoteMark || char == backslash || char == newline:
		return append(out, backslash, char)
	case char < firstControl || char == deleteCharacter:
		if isDigit(next) {
			return append(out, fmt.Sprintf("\\%03d", char)...)
		}

		return append(out, fmt.Sprintf("\\%d", char)...)
	default:
		return append(out, char)
	}
}

func byteAt(text string, index int) byte {
	if index >= len(text) {
		return 0
	}

	return text[index]
}

func isDigit(char byte) bool {
	return char >= firstDigit && char <= lastDigit
}
