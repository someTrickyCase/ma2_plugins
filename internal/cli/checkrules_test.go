package cli_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/cli"
)

const (
	testFileMode   = 0o600
	checkRulesName = "check-rules"
)

func writeFile(t *testing.T, path string, text string) {
	t.Helper()

	err := os.WriteFile(path, []byte(text), testFileMode)
	if err != nil {
		t.Fatalf("cannot write %q: %v", path, err)
	}
}

func TestCheckRulesReportsEveryViolation(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	path := filepath.Join(dir, "a.lua")
	writeFile(t, path, "return 1 -- hi\nlocal b = '\t'\n")

	got := run(checkRulesName, path)

	expectCode(t, got, cli.ExitViolations)

	want := path + ":1: comment: code must explain itself, no comments"
	expectStdoutContains(t, got, want)

	want = path + ":2: ascii: only printable ASCII characters are allowed"
	expectStdoutContains(t, got, want)
}

func TestCheckRulesPassesOnCleanFile(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	path := filepath.Join(dir, "a.go")
	writeFile(t, path, "package main\n\nfunc main() {}\n")

	got := run(checkRulesName, path)

	expectCode(t, got, cli.ExitOK)

	if got.stdout != "" {
		t.Errorf("stdout = %q, want it to be empty", got.stdout)
	}
}

func TestCheckRulesChecksSeveralFiles(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	lua := filepath.Join(dir, "a.lua")
	goFile := filepath.Join(dir, "b.go")

	writeFile(t, lua, "return 1\n")
	writeFile(t, goFile, "package main\n\nfunc main() {} // hi\n")

	got := run(checkRulesName, lua, goFile)

	expectCode(t, got, cli.ExitViolations)

	want := goFile + ":3: comment: code must explain itself, no comments"
	expectStdoutContains(t, got, want)
}

func TestCheckRulesRejectsUnknownFileType(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	path := filepath.Join(dir, "notes.txt")
	writeFile(t, path, "hello\n")

	got := run(checkRulesName, path)

	expectCode(t, got, cli.ExitUsage)
	expectStderr(t, got, "unknown file type")
}

func TestCheckRulesReportsMissingFile(t *testing.T) {
	t.Parallel()

	path := filepath.Join(t.TempDir(), "missing.lua")

	got := run(checkRulesName, path)

	expectCode(t, got, cli.ExitUsage)
	expectStderr(t, got, "cannot read")
}

func TestCheckRulesWithoutFilesShowsUsage(t *testing.T) {
	t.Parallel()

	got := run(checkRulesName)

	expectCode(t, got, cli.ExitUsage)
	expectStderr(t, got, checkRulesName)
}
