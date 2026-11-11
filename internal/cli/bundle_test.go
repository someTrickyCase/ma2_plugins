package cli_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const (
	answerLua     = "k-answer.lua"
	answerXML     = "k-answer.xml"
	bundleFailure = "bundle failed with %d: %s"
	pluginDir     = "plugins"
	answerPlugin  = "answer"
	outFolder     = "out"
	bundleCmd     = "bundle"
	outFlag       = "--out"
	dirMode       = 0o750
	fileMode      = 0o600
	manifestFile  = "plugin.json"
	createdError  = "output folder was created: %v"
)

const answerJSON = `{
  "name": "Answer",
  "file": "k-answer",
  "version": "1.2.3",
  "slot": 101
}
`

func TestBundleAllDiscoversPlugins(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root)
	t.Chdir(root)

	got := run(bundleCmd, "--all", outFlag, outFolder)
	if got.code != 0 {
		t.Fatalf(bundleFailure, got.code, got.stderr)
	}

	for _, name := range []string{answerLua, answerXML} {
		_, err := os.Stat(filepath.Join(outFolder, name))
		if err != nil {
			t.Fatalf("missing %q: %v", name, err)
		}
	}
}

func TestBundleRejectsTraversalBeforeWriting(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root)
	t.Chdir(root)

	manifestPath := filepath.Join(pluginDir, answerPlugin, manifestFile)
	bad := strings.Replace(answerJSON, "k-answer", "../escaped", 1)

	err := os.WriteFile(manifestPath, []byte(bad), fileMode)
	if err != nil {
		t.Fatal(err)
	}

	got := run(bundleCmd, answerPlugin, outFlag, outFolder)
	if got.code == 0 {
		t.Fatal("traversal manifest was bundled")
	}

	_, err = os.Stat(outFolder)
	if !os.IsNotExist(err) {
		t.Fatalf(createdError, err)
	}
}

func TestBundleRejectsNegativeSlotBeforeWriting(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root)
	t.Chdir(root)

	got := run(bundleCmd, answerPlugin, "--at", "-1", outFlag, outFolder)
	if got.code == 0 {
		t.Fatal("negative slot was accepted")
	}

	_, err := os.Stat(outFolder)
	if !os.IsNotExist(err) {
		t.Fatalf(createdError, err)
	}
}

func TestBundleAllRejectsDuplicateFileBasesBeforeWriting(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root)
	second := filepath.Join(root, pluginDir, "second")

	err := os.MkdirAll(second, dirMode)
	if err != nil {
		t.Fatal(err)
	}

	err = os.WriteFile(filepath.Join(second, manifestFile),
		[]byte(answerJSON), fileMode)
	if err != nil {
		t.Fatal(err)
	}

	t.Chdir(root)

	got := run(bundleCmd, "--all", outFlag, outFolder)
	if got.code == 0 {
		t.Fatal("duplicate file base was accepted")
	}

	_, err = os.Stat(outFolder)
	if !os.IsNotExist(err) {
		t.Fatalf(createdError, err)
	}
}

func writePlugin(t *testing.T, root string) {
	t.Helper()

	folder := filepath.Join(root, pluginDir, answerPlugin)

	err := os.MkdirAll(folder, dirMode)
	if err != nil {
		t.Fatalf("cannot create %q: %v", folder, err)
	}

	err = os.WriteFile(
		filepath.Join(folder, manifestFile), []byte(answerJSON), fileMode)
	if err != nil {
		t.Fatalf("cannot write the manifest: %v", err)
	}

	err = os.WriteFile(
		filepath.Join(folder, "main.lua"), []byte("return 1\n"), fileMode)
	if err != nil {
		t.Fatalf("cannot write the entry point: %v", err)
	}
}

func TestBundle(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root)
	t.Chdir(root)

	got := run(bundleCmd, answerPlugin, outFlag, outFolder)

	if got.code != 0 {
		t.Fatalf(bundleFailure, got.code, got.stderr)
	}

	for _, name := range []string{answerLua, answerXML} {
		_, err := os.Stat(filepath.Join(outFolder, name))
		if err != nil {
			t.Errorf("missing %q: %v", name, err)
		}
	}

	want := []string{
		"out/k-answer.lua",
		"out/k-answer.xml",
		"MA2 commands, paste them in this order:",
		"     Delete Plugin 101",
		`     Import "` + answerXML + `" At Plugin 101`,
		"     Plugin 101",
	}

	for _, line := range want {
		if !strings.Contains(got.stdout, line) {
			t.Errorf("stdout =\n%s\nwant the line %q", got.stdout, line)
		}
	}
}

func TestBundleTakesTheGivenSlot(t *testing.T) {
	root := t.TempDir()
	writePlugin(t, root)
	t.Chdir(root)

	got := run(bundleCmd, answerPlugin, outFlag, outFolder, "--at", "5")

	if got.code != 0 {
		t.Fatalf(bundleFailure, got.code, got.stderr)
	}

	if !strings.Contains(got.stdout, "     Delete Plugin 5") {
		t.Errorf("stdout =\n%s\nwant the slot 5", got.stdout)
	}
}

func TestBundleFailsOnAnUnknownPlugin(t *testing.T) {
	t.Chdir(t.TempDir())

	got := run(bundleCmd, "nothing", outFlag, outFolder)

	if got.code == 0 {
		t.Error("bundle() code = 0, want an error")
	}

	if !strings.Contains(got.stderr, "missing file") {
		t.Errorf("stderr = %q, want it to say missing file", got.stderr)
	}
}

func TestBundleNeedsAPluginName(t *testing.T) {
	t.Parallel()

	got := run(bundleCmd)

	if got.code == 0 {
		t.Error("bundle() code = 0, want an error")
	}
}
