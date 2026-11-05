package install_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/bundle"
	"github.com/someTrickyCase/ma2_plugins/internal/install"
	"github.com/someTrickyCase/ma2_plugins/internal/manifest"
)

const (
	answerName    = "Answer"
	answerFile    = "k-answer"
	answerVersion = "1.2.3"
	answerSlot    = 101
	otherSlot     = 5
	cleanMain     = "return 1\n"
	dirtyMain     = "-- a comment\nreturn 1\n"
	otherFile     = "answer"
	fileMode      = 0o600
	dirMode       = 0o750
	fileCount     = 2
	doError       = "Do() error = %v"
	doFails       = "Do() error = nil, want an error"
	folderFull    = "the folder has files, want nothing"
	pluginFolder  = "plugins"
	commitStamp   = "abc1234"
	dateStamp     = "2026-10-24"
	luaSuffix     = ".lua"
	xmlSuffix     = ".xml"
)

const answerManifest = `{
  "name": "Answer",
  "file": "k-answer",
  "version": "1.2.3",
  "slot": 101
}
`

func answerPlugin(main string) bundle.Plugin {
	return bundle.Plugin{
		Manifest: manifest.Manifest{
			Name:    answerName,
			File:    answerFile,
			Version: answerVersion,
			Slot:    answerSlot,
		},
		Main:    main,
		Modules: []bundle.Module{},
		Stamp:   bundle.Stamp{Commit: commitStamp, Date: dateStamp},
	}
}

func targetFolder(t *testing.T) string {
	t.Helper()

	folder := filepath.Join(t.TempDir(), "plugins")

	err := os.MkdirAll(folder, dirMode)
	if err != nil {
		t.Fatalf("cannot create %q: %v", folder, err)
	}

	return folder
}

func writtenFiles(folder string) []string {
	found := []string{}

	entries, err := os.ReadDir(folder)
	if err != nil {
		return found
	}

	for _, entry := range entries {
		found = append(found, entry.Name())
	}

	return found
}

func TestDoWritesBothFiles(t *testing.T) {
	t.Parallel()

	folder := targetFolder(t)

	got, err := install.Do(install.Request{
		Plugin: answerPlugin(cleanMain),
		Slot:   answerSlot,
		Folder: folder,
		DryRun: false,
	})
	if err != nil {
		t.Fatalf(doError, err)
	}

	if got.Folder != folder {
		t.Errorf("Folder = %q, want %q", got.Folder, folder)
	}

	names := []string{answerFile + luaSuffix, answerFile + xmlSuffix}

	for _, name := range names {
		_, err := os.Stat(filepath.Join(folder, name))
		if err != nil {
			t.Errorf("missing %q: %v", name, err)
		}
	}
}

func TestDoCreatesTheTargetFolder(t *testing.T) {
	t.Parallel()

	folder := filepath.Join(t.TempDir(), "plugins")

	_, err := install.Do(install.Request{
		Plugin: answerPlugin(cleanMain),
		Slot:   answerSlot,
		Folder: folder,
		DryRun: false,
	})
	if err != nil {
		t.Fatalf(doError, err)
	}

	_, err = os.Stat(filepath.Join(folder, answerFile+luaSuffix))
	if err != nil {
		t.Errorf("missing the built file: %v", err)
	}
}

func TestDoRefusesAFileThatIsNotOurs(t *testing.T) {
	t.Parallel()

	folder := targetFolder(t)

	plugin := answerPlugin(cleanMain)
	plugin.Manifest.File = otherFile

	_, err := install.Do(install.Request{
		Plugin: plugin,
		Slot:   answerSlot,
		Folder: folder,
		DryRun: false,
	})
	if err == nil {
		t.Error(doFails)
	}

	if len(writtenFiles(folder)) != 0 {
		t.Error(folderFull)
	}
}

func TestDoRefusesABundleWithRuleViolations(t *testing.T) {
	t.Parallel()

	folder := targetFolder(t)

	_, err := install.Do(install.Request{
		Plugin: answerPlugin(dirtyMain),
		Slot:   answerSlot,
		Folder: folder,
		DryRun: false,
	})
	if err == nil {
		t.Error(doFails)
	}

	if !strings.Contains(err.Error(), "code rules") {
		t.Errorf("Do() error = %q, want it to say code rules", err.Error())
	}

	if len(writtenFiles(folder)) != 0 {
		t.Error(folderFull)
	}
}

func TestDoWritesNothingOnADryRun(t *testing.T) {
	t.Parallel()

	folder := targetFolder(t)

	got, err := install.Do(install.Request{
		Plugin: answerPlugin(cleanMain),
		Slot:   answerSlot,
		Folder: folder,
		DryRun: true,
	})
	if err != nil {
		t.Fatalf(doError, err)
	}

	if !got.DryRun {
		t.Error("DryRun = false, want true")
	}

	if len(writtenFiles(folder)) != 0 {
		t.Error(folderFull)
	}

	if len(got.Files) != fileCount {
		t.Errorf("Files = %d, want %d", len(got.Files), fileCount)
	}
}

func TestDoReturnsTheInstructions(t *testing.T) {
	t.Parallel()

	got, err := install.Do(install.Request{
		Plugin: answerPlugin(cleanMain),
		Slot:   answerSlot,
		Folder: targetFolder(t),
		DryRun: false,
	})
	if err != nil {
		t.Fatalf(doError, err)
	}

	want := []string{
		"     Delete Plugin 101",
		`     Import "k-answer.xml" At Plugin 101`,
		"     Plugin 101",
	}

	joined := strings.Join(got.Instructions, "\n")

	for _, line := range want {
		if !strings.Contains(joined, line) {
			t.Errorf("Instructions() = %q, want the line %q", joined, line)
		}
	}
}

func TestDoTakesTheGivenSlot(t *testing.T) {
	t.Parallel()

	got, err := install.Do(install.Request{
		Plugin: answerPlugin(cleanMain),
		Slot:   otherSlot,
		Folder: targetFolder(t),
		DryRun: false,
	})
	if err != nil {
		t.Fatalf(doError, err)
	}

	if !strings.Contains(strings.Join(got.Instructions, "\n"), "Plugin 5") {
		t.Errorf("Instructions() = %v, want the slot 5", got.Instructions)
	}
}

func TestDoFailsWithoutASlot(t *testing.T) {
	t.Parallel()

	folder := targetFolder(t)

	plugin := answerPlugin(cleanMain)
	plugin.Manifest.Slot = 0

	_, err := install.Do(install.Request{
		Plugin: plugin,
		Slot:   0,
		Folder: folder,
		DryRun: false,
	})
	if err == nil {
		t.Error(doFails)
	}

	if len(writtenFiles(folder)) != 0 {
		t.Error(folderFull)
	}
}

func writePlugin(t *testing.T, root string, name string) {
	t.Helper()

	folder := filepath.Join(root, pluginFolder, name)

	err := os.MkdirAll(folder, dirMode)
	if err != nil {
		t.Fatalf("cannot create %q: %v", folder, err)
	}

	err = os.WriteFile(
		filepath.Join(folder, "plugin.json"), []byte(answerManifest), fileMode)
	if err != nil {
		t.Fatalf("cannot write the manifest: %v", err)
	}

	err = os.WriteFile(
		filepath.Join(folder, "main.lua"), []byte(cleanMain), fileMode)
	if err != nil {
		t.Fatalf("cannot write the entry point: %v", err)
	}
}

func TestAllInstallsEveryPlugin(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	writePlugin(t, root, answerFile)

	target := targetFolder(t)

	got, err := install.All(install.Batch{
		Root:   root,
		Folder: target,
		Slot:   0,
		DryRun: false,
		Stamp:  bundle.Stamp{Commit: commitStamp, Date: dateStamp},
	}, []string{answerFile})
	if err != nil {
		t.Fatalf("All() error = %v", err)
	}

	if len(got) != 1 {
		t.Fatalf("All() = %d results, want 1", len(got))
	}

	_, err = os.Stat(filepath.Join(target, answerFile+luaSuffix))
	if err != nil {
		t.Errorf("missing the built file: %v", err)
	}
}

func TestAllFailsOnAMissingPlugin(t *testing.T) {
	t.Parallel()

	target := targetFolder(t)

	_, err := install.All(install.Batch{
		Root:   t.TempDir(),
		Folder: target,
		Slot:   0,
		DryRun: false,
		Stamp:  bundle.Stamp{Commit: commitStamp, Date: dateStamp},
	}, []string{"nothing"})
	if err == nil {
		t.Error(doFails)
	}

	if len(writtenFiles(target)) != 0 {
		t.Error(folderFull)
	}
}
