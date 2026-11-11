package manifest_test

import (
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/manifest"
)

func TestValidateFile(t *testing.T) {
	t.Parallel()

	bad := []string{
		"", "k-", "../escaped", "k-a/b", `k-a"b`, "k-a*b", "k-A", "k-a.b",
		"k-a?b", "k-a<b", "k-a>b", "k-a|b", "k-a:b", "k-a\\b",
	}

	for _, name := range bad {
		err := manifest.ValidateFile(name)
		if err == nil {
			t.Errorf("ValidateFile(%q) accepted invalid base", name)
		}
	}

	err := manifest.ValidateFile("k-sequence-cleanup")
	if err != nil {
		t.Fatalf("valid base rejected: %v", err)
	}
}
