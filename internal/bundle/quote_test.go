package bundle_test

import (
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/bundle"
)

func TestQuote(t *testing.T) {
	t.Parallel()

	cases := []struct {
		name string
		text string
		want string
	}{
		{"plain", "plain", `"plain"`},
		{"space", "a b", `"a b"`},
		{"quote", `a"b`, `"a\"b"`},
		{"backslash", `a\b`, `"a\\b"`},
		{"newline", "a\nb", "\"a\\\nb\""},
		{"carriage return", "a\rb", `"a\13b"`},
		{"tab", "a\tb", `"a\9b"`},
		{"null", "a\x00b", `"a\0b"`},
		{"delete", "a\x7fb", `"a\127b"`},
		{"control before a digit", "a\x015", `"a\0015"`},
		{"control before a letter", "a\x01b", `"a\1b"`},
		{"high bytes", "caf\xc3\xa9", "\"caf\xc3\xa9\""},
		{"percent", "a%b", `"a%b"`},
		{"empty", "", `""`},
	}

	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			t.Parallel()

			if got := bundle.Quote(testCase.text); got != testCase.want {
				t.Errorf("Quote(%q) = %q, want %q",
					testCase.text, got, testCase.want)
			}
		})
	}
}
