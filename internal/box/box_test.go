package box_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/box"
	"github.com/someTrickyCase/ma2_plugins/internal/manifest"
	"github.com/someTrickyCase/ma2_plugins/internal/readfile"
)

const (
	copyFailure   = "Copy() error = nil, want an error"
	earlyTarget   = "target was created before validation: %v"
	targetFolder  = "plugins"
	answerName    = "Answer"
	answerFile    = "k-answer"
	answerVersion = "1.2.3"
	answerSlot    = 101
	luaText       = "return 1\n"
	xmlText       = "<MA></MA>\n"
	dirMode       = 0o750
	fileMode      = 0o600
	readError     = "Read() error = %v"
	luaSuffix     = ".lua"
	xmlSuffix     = ".xml"
)

func answerManifest() manifest.Manifest {
	return manifest.Manifest{
		Name:    answerName,
		File:    answerFile,
		Version: answerVersion,
		Slot:    answerSlot,
	}
}

func writeBox(t *testing.T) string {
	t.Helper()

	folder := t.TempDir()

	all := []manifest.Manifest{answerManifest()}

	text, err := manifest.FormatList(all)
	if err != nil {
		t.Fatalf("cannot write the list: %v", err)
	}

	err = os.WriteFile(
		filepath.Join(folder, manifest.ListFile), text, fileMode)
	if err != nil {
		t.Fatalf("cannot write the list: %v", err)
	}

	err = os.WriteFile(
		filepath.Join(folder, answerFile+luaSuffix), []byte(luaText), fileMode)
	if err != nil {
		t.Fatalf("cannot write the lua file: %v", err)
	}

	err = os.WriteFile(
		filepath.Join(folder, answerFile+xmlSuffix), []byte(xmlText), fileMode)
	if err != nil {
		t.Fatalf("cannot write the xml file: %v", err)
	}

	return folder
}

func TestReadReadsTheManifest(t *testing.T) {
	t.Parallel()

	folder := writeBox(t)

	got, err := box.Read(folder)
	if err != nil {
		t.Fatalf(readError, err)
	}

	if len(got.Plugins) != 1 {
		t.Fatalf("Read() = %d plugins, want 1", len(got.Plugins))
	}

	if got.Plugins[0].File != answerFile {
		t.Errorf("File = %q, want %q", got.Plugins[0].File, answerFile)
	}
}

func TestReadFailsWithoutAManifest(t *testing.T) {
	t.Parallel()

	_, err := box.Read(t.TempDir())
	if err == nil {
		t.Error("Read() error = nil, want an error")
	}
}

func TestCopyCopiesBothFiles(t *testing.T) {
	t.Parallel()

	folder := writeBox(t)

	one, err := box.Read(folder)
	if err != nil {
		t.Fatalf(readError, err)
	}

	target := filepath.Join(t.TempDir(), targetFolder)

	err = one.Copy(target, one.Plugins)
	if err != nil {
		t.Fatalf("Copy() error = %v", err)
	}

	names := []string{answerFile + luaSuffix, answerFile + xmlSuffix}

	for _, name := range names {
		_, err := os.Stat(filepath.Join(target, name))
		if err != nil {
			t.Errorf("missing %q: %v", name, err)
		}
	}

	data, err := readfile.Read(filepath.Join(target, answerFile+luaSuffix))
	if err != nil {
		t.Fatalf("cannot read the copied file: %v", err)
	}

	if string(data) != luaText {
		t.Errorf("the copied file = %q, want %q", data, luaText)
	}
}

func TestCopyFailsOnAMissingFile(t *testing.T) {
	t.Parallel()

	folder := writeBox(t)

	one, err := box.Read(folder)
	if err != nil {
		t.Fatalf(readError, err)
	}

	missing := answerManifest()
	missing.File = "k-nothing"

	target := filepath.Join(t.TempDir(), targetFolder)

	err = one.Copy(target, []manifest.Manifest{missing})
	if err == nil {
		t.Error(copyFailure)
	}
}

func TestCommandsTellWhatToType(t *testing.T) {
	t.Parallel()

	folder := writeBox(t)

	one, err := box.Read(folder)
	if err != nil {
		t.Fatalf(readError, err)
	}

	got, err := box.Commands(one.Plugins)
	if err != nil {
		t.Fatalf("Commands() error = %v", err)
	}

	joined := strings.Join(got, "\n")

	want := []string{
		"Delete Plugin 101",
		`Import "k-answer.xml" At Plugin 101`,
		"Plugin 101",
	}

	for _, line := range want {
		if !strings.Contains(joined, line) {
			t.Errorf("Commands() = %q, want the line %q", joined, line)
		}
	}
}

func TestCopyValidatesBeforeWriting(t *testing.T) {
	t.Parallel()

	cases := map[string]string{
		"missing later file": "k-missing",
		"not ours":           "answer",
		"parent path":        "../k-answer",
		"nested path":        "k-folder/answer",
		"windows path":       `k-folder\answer`,
	}

	for name, file := range cases {
		t.Run(name, func(t *testing.T) {
			t.Parallel()

			folder := writeBox(t)
			one := box.Box{Folder: folder, Plugins: nil}
			bad := answerManifest()
			bad.File = file
			target := filepath.Join(t.TempDir(), targetFolder)

			err := one.Copy(target, []manifest.Manifest{answerManifest(), bad})
			if err == nil {
				t.Fatal(copyFailure)
			}

			assertAbsent(t, target)
		})
	}
}

func assertAbsent(t *testing.T, target string) {
	t.Helper()

	_, err := os.Stat(target)
	if !os.IsNotExist(err) {
		t.Fatalf(earlyTarget, err)
	}
}

func TestCopyRejectsMissingSlotBeforeWriting(t *testing.T) {
	t.Parallel()

	one := box.Box{Folder: writeBox(t), Plugins: nil}
	plugin := answerManifest()
	plugin.Slot = 0
	target := filepath.Join(t.TempDir(), targetFolder)

	err := one.Copy(target, []manifest.Manifest{plugin})
	if err == nil {
		t.Fatal(copyFailure)
	}

	_, err = os.Stat(target)

	if !os.IsNotExist(err) {
		t.Fatalf(earlyTarget, err)
	}
}

func TestCopyRejectsInvalidLuaBeforeWriting(t *testing.T) {
	t.Parallel()

	folder := writeBox(t)

	err := os.WriteFile(filepath.Join(folder, answerFile+luaSuffix),
		[]byte("-- forbidden comment\nreturn 1\n"), fileMode)
	if err != nil {
		t.Fatal(err)
	}

	one := box.Box{Folder: folder, Plugins: nil}
	target := filepath.Join(t.TempDir(), targetFolder)

	err = one.Copy(target, []manifest.Manifest{answerManifest()})
	if err == nil {
		t.Fatal(copyFailure)
	}

	_, err = os.Stat(target)

	if !os.IsNotExist(err) {
		t.Fatalf(earlyTarget, err)
	}
}

func TestCopyRejectsDuplicatePlugins(t *testing.T) {
	t.Parallel()

	one := box.Box{Folder: writeBox(t), Plugins: nil}
	plugins := []manifest.Manifest{answerManifest(), answerManifest()}

	err := one.Copy(t.TempDir(), plugins)
	if err == nil {
		t.Fatal(copyFailure)
	}
}
