package rules_test

import (
	"slices"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/rules"
)

const (
	accent      = "\xc3\xa9"
	rawByte     = "\xff"
	luaDash     = "--"
	goSlash     = "//"
	goBlock     = "/*"
	goBlockEnd  = "*/"
	commentTail = " note\n"
	secondLine  = 2
	thirdLine   = 3
)

type findCase struct {
	name string
	text string
	want []rules.Violation
}

func violation(line int, rule rules.Rule) rules.Violation {
	return rules.Violation{Line: line, Rule: rule}
}

func runFindCases(t *testing.T, language rules.Language, cases []findCase) {
	t.Helper()

	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			t.Parallel()

			got := rules.Find(testCase.text, language)

			if !slices.Equal(got, testCase.want) {
				t.Errorf("Find() = %v, want %v", got, testCase.want)
			}
		})
	}
}

func TestFindLuaComments(t *testing.T) {
	t.Parallel()

	cases := []findCase{
		{
			name: "finds a line comment",
			text: "local x = 1\nlocal y = 2 " + luaDash + commentTail,
			want: []rules.Violation{
				violation(secondLine, rules.RuleComment),
			},
		},
		{
			name: "finds a block comment once at its start",
			text: "local x = 1\n" + luaDash + "[[ one\ntwo ]]\nreturn x\n",
			want: []rules.Violation{
				violation(secondLine, rules.RuleComment),
			},
		},
		{
			name: "finds a leveled block comment",
			text: luaDash + "[==[ a ]] still " + luaDash + " inside ]==]\n" +
				"return 1 " + luaDash + commentTail,
			want: []rules.Violation{
				violation(1, rules.RuleComment),
				violation(secondLine, rules.RuleComment),
			},
		},
		{
			name: "finds a comment after a long string",
			text: "local s = [[a]] " + luaDash + commentTail,
			want: []rules.Violation{
				violation(1, rules.RuleComment),
			},
		},
	}

	runFindCases(t, rules.Lua, cases)
}

func TestFindLuaStringsAndAscii(t *testing.T) {
	t.Parallel()

	cases := []findCase{
		{
			name: "clean code has no violations",
			text: "local x = 1\nreturn x\n",
			want: nil,
		},
		{
			name: "finds a non-ascii character",
			text: "local a = 1\nlocal b = '" + accent + "'\n",
			want: []rules.Violation{
				violation(secondLine, rules.RuleASCII),
			},
		},
		{
			name: "finds a tab",
			text: "if x then\n\treturn x\nend\n",
			want: []rules.Violation{
				violation(secondLine, rules.RuleASCII),
			},
		},
		{
			name: "ignores dashes in a double quoted string",
			text: "local s = \"a " + luaDash + " b\"\n",
			want: nil,
		},
		{
			name: "ignores dashes in a single quoted string with escapes",
			text: "local s = 'it\\'s " + luaDash + " fine'\n",
			want: nil,
		},
		{
			name: "ignores dashes in long strings",
			text: "local a = [[ " + luaDash + " ]]\n" +
				"local b = [=[ ]] " + luaDash + " ]=]\n",
			want: nil,
		},
		{
			name: "sorts violations by line",
			text: luaDash + " a\nlocal b = '" + rawByte + "'\n",
			want: []rules.Violation{
				violation(1, rules.RuleComment),
				violation(secondLine, rules.RuleASCII),
			},
		},
	}

	runFindCases(t, rules.Lua, cases)
}

func TestFindGoComments(t *testing.T) {
	t.Parallel()

	cases := []findCase{
		{
			name: "finds a line comment",
			text: "package main\n\nfunc main() {} " + goSlash + commentTail,
			want: []rules.Violation{
				violation(thirdLine, rules.RuleComment),
			},
		},
		{
			name: "finds a block comment once at its start",
			text: "package main\n\n" + goBlock + " one\ntwo " + goBlockEnd +
				"\nfunc main() {}\n",
			want: []rules.Violation{
				violation(thirdLine, rules.RuleComment),
			},
		},
		{
			name: "finds a comment after a raw string",
			text: "package main\n\nvar s = `text` " + goSlash + commentTail,
			want: []rules.Violation{
				violation(thirdLine, rules.RuleComment),
			},
		},
	}

	runFindCases(t, rules.Golang, cases)
}

func TestFindGoStringsAndAscii(t *testing.T) {
	t.Parallel()

	cases := []findCase{
		{
			name: "clean code has no violations",
			text: "package main\n\nfunc main() {}\n",
			want: nil,
		},
		{
			name: "finds a non-ascii character",
			text: "package main\n\nvar s = \"" + accent + "\"\n",
			want: []rules.Violation{
				violation(thirdLine, rules.RuleASCII),
			},
		},
		{
			name: "ignores slashes in a double quoted string",
			text: "package main\n\nvar s = \"http://example.com\"\n",
			want: nil,
		},
		{
			name: "ignores slashes in a raw string",
			text: "package main\n\nvar s = `" + goSlash + " not a comment`\n",
			want: nil,
		},
		{
			name: "ignores a double quote inside a rune literal",
			text: "package main\n\nvar r = '\"'\n",
			want: nil,
		},
		{
			name: "allows tab indentation",
			text: "package main\n\nfunc main() {\n\treturn\n}\n",
			want: nil,
		},
		{
			name: "finds a carriage return",
			text: "package main\r\n",
			want: []rules.Violation{
				violation(1, rules.RuleASCII),
			},
		},
	}

	runFindCases(t, rules.Golang, cases)
}

func TestReportFormatsOneLinePerViolation(t *testing.T) {
	t.Parallel()

	files := []rules.File{
		{
			Path:     "a.lua",
			Text:     "return 1 " + luaDash + commentTail,
			Language: rules.Lua,
		},
		{
			Path:     "b.lua",
			Text:     "return 2\n",
			Language: rules.Lua,
		},
	}

	want := []string{
		"a.lua:1: comment: code must explain itself, no comments",
	}

	got := rules.Report(files)

	if !slices.Equal(got, want) {
		t.Errorf("Report() = %v, want %v", got, want)
	}
}

func TestReportNamesAsciiRule(t *testing.T) {
	t.Parallel()

	files := []rules.File{
		{
			Path:     "c.lua",
			Text:     "\treturn 1\n",
			Language: rules.Lua,
		},
	}

	want := []string{
		"c.lua:1: ascii: only printable ASCII characters are allowed",
	}

	got := rules.Report(files)

	if !slices.Equal(got, want) {
		t.Errorf("Report() = %v, want %v", got, want)
	}
}
