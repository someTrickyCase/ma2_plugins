package cli_test

import (
	"bytes"
	"strings"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/cli"
)

const usageLine = "usage: ma2kit <command> [args]"

type result struct {
	code   int
	stdout string
	stderr string
}

func run(args ...string) result {
	var stdout, stderr bytes.Buffer

	code := cli.Run(args, &stdout, &stderr)

	return result{code: code, stdout: stdout.String(), stderr: stderr.String()}
}

func expectCode(t *testing.T, got result, want int) {
	t.Helper()

	if got.code != want {
		t.Errorf("exit code = %d, want %d", got.code, want)
	}
}

func expectStdoutPrefix(t *testing.T, got result, want string) {
	t.Helper()

	if !strings.HasPrefix(got.stdout, want) {
		t.Errorf("stdout = %q, want prefix %q", got.stdout, want)
	}
}

func expectStdoutContains(t *testing.T, got result, want string) {
	t.Helper()

	if !strings.Contains(got.stdout, want) {
		t.Errorf("stdout = %q, want it to contain %q", got.stdout, want)
	}
}

func expectStderr(t *testing.T, got result, want string) {
	t.Helper()

	if !strings.Contains(got.stderr, want) {
		t.Errorf("stderr = %q, want %q", got.stderr, want)
	}
}

func TestVersionPrintsNameAndBuild(t *testing.T) {
	t.Parallel()

	got := run("version")

	expectCode(t, got, cli.ExitOK)
	expectStdoutPrefix(t, got, "ma2kit ")
}

func TestUnknownCommandShowsUsage(t *testing.T) {
	t.Parallel()

	got := run("dance")

	expectCode(t, got, cli.ExitUsage)
	expectStderr(t, got, "unknown command \"dance\"")
	expectStderr(t, got, usageLine)
}

func TestNoCommandShowsUsage(t *testing.T) {
	t.Parallel()

	got := run()

	expectCode(t, got, cli.ExitUsage)
	expectStderr(t, got, usageLine)
}
