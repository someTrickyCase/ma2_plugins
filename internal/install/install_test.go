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
)

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
		Stamp:   bundle.Stamp{Commit: "abc1234", Date: "2026-10-24"},
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

	for _, name := range []string{answerFile + ".lua", answerFile + ".xml"} {
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

	_, err = os.Stat(filepath.Join(folder, answerFile+".lua"))
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
