package buildinfo_test

import (
	"runtime/debug"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/buildinfo"
)

const fullHash = "7d21c63c0ffee0123456789abcdef0123456789a"

func gitBuild(modified string) []debug.BuildSetting {
	return []debug.BuildSetting{
		{Key: "vcs.revision", Value: fullHash},
		{Key: "vcs.time", Value: "2026-10-25T00:12:00Z"},
		{Key: "vcs.modified", Value: modified},
	}
}

func TestDescribe(t *testing.T) {
	t.Parallel()

	cases := []struct {
		name     string
		settings []debug.BuildSetting
		want     string
	}{
		{"short commit and date", gitBuild("false"), "7d21c63 (2026-10-25)"},
		{"uncommitted changes", gitBuild("true"), "7d21c63-dirty (2026-10-25)"},
		{"no git data", nil, "dev"},
	}

	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			t.Parallel()

			got := buildinfo.Describe(testCase.settings)
			if got != testCase.want {
				t.Errorf("Describe() = %q, want %q", got, testCase.want)
			}
		})
	}
}
