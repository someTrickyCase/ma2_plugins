package setup_test

import (
	"bytes"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/mahome"
	"github.com/someTrickyCase/ma2_plugins/internal/manifest"
	"github.com/someTrickyCase/ma2_plugins/internal/setup"
	"github.com/someTrickyCase/ma2_plugins/internal/tui"
)

const (
	answerName    = "Answer"
	answerFile    = "k-answer"
	answerVersion = "1.2.3"
	answerSlot    = 101
	luaText       = "return 1\n"
	xmlText       = "<MA></MA>\n"
	version       = "3.9.60"
	dirMode       = 0o750
	fileMode      = 0o600
	boxFlag       = "--box"
	maRootFlag    = "--ma-root"
	chosenSlot    = 205
)

var errNoVersion = errors.New("no MA2 version")

func writeBox(t *testing.T) string {
	t.Helper()

	folder := t.TempDir()

	all := []manifest.Manifest{{
		Name:    answerName,
		File:    answerFile,
		Version: answerVersion,
		Slot:    answerSlot,
	}}

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
		filepath.Join(folder, answerFile+".lua"), []byte(luaText), fileMode)
	if err != nil {
		t.Fatalf("cannot write the lua file: %v", err)
	}

	err = os.WriteFile(
		filepath.Join(folder, answerFile+".xml"), []byte(xmlText), fileMode)
	if err != nil {
		t.Fatalf("cannot write the xml file: %v", err)
	}

	return folder
}

func writeMaFolder(t *testing.T) string {
	t.Helper()

	root := t.TempDir()

	folder := filepath.Join(root, "gma2_V_"+version, "plugins")

	err := os.MkdirAll(folder, dirMode)
	if err != nil {
		t.Fatalf("cannot create %q: %v", folder, err)
	}

	return root
}

func fakePicker(items []tui.Item) setup.Picker {
	return func(
		_ io.Writer,
		_ []tui.Item,
		versions []mahome.Version,
	) (tui.Selection, error) {
		if len(versions) == 0 {
			return tui.Selection{}, errNoVersion
		}

		return tui.Selection{
			Items:   items,
			Version: versions[0],
		}, nil
	}
}

func TestRunCopiesTheFilesAndPrintsTheCommands(t *testing.T) {
	t.Parallel()

	boxFolder := writeBox(t)
	maRoot := writeMaFolder(t)

	var stdout, stderr bytes.Buffer

	items := []tui.Item{{
		Key:     answerFile,
		Name:    answerName,
		Version: answerVersion,
		Slot:    answerSlot,
	}}

	code := setup.Run(
		[]string{boxFlag, boxFolder, maRootFlag, maRoot},
		&stdout,
		&stderr,
		fakePicker(items),
	)

	if code != 0 {
		t.Fatalf("Run() = %d, want 0: %s", code, stderr.String())
	}

	target := filepath.Join(maRoot, "gma2_V_"+version, "plugins")

	for _, name := range []string{answerFile + ".lua", answerFile + ".xml"} {
		_, err := os.Stat(filepath.Join(target, name))
		if err != nil {
			t.Errorf("missing %q: %v", name, err)
		}
	}

	if !strings.Contains(stdout.String(), "Delete Plugin 101") {
		t.Errorf("stdout = %q, want the commands", stdout.String())
	}
}

func TestRunFailsWithoutABox(t *testing.T) {
	t.Parallel()

	maRoot := writeMaFolder(t)

	var stdout, stderr bytes.Buffer

	code := setup.Run(
		[]string{boxFlag, t.TempDir(), maRootFlag, maRoot},
		&stdout,
		&stderr,
		fakePicker(nil),
	)

	if code == 0 {
		t.Error("Run() = 0, want an error")
	}
}

func TestRunFailsWithoutAMaFolder(t *testing.T) {
	t.Parallel()

	boxFolder := writeBox(t)

	var stdout, stderr bytes.Buffer

	code := setup.Run(
		[]string{boxFlag, boxFolder, maRootFlag, t.TempDir()},
		&stdout,
		&stderr,
		fakePicker(nil),
	)

	if code == 0 {
		t.Error("Run() = 0, want an error")
	}
}

func TestRunUsesTheChosenSlot(t *testing.T) {
	t.Parallel()

	boxFolder := writeBox(t)
	maRoot := writeMaFolder(t)

	var stdout, stderr bytes.Buffer

	items := []tui.Item{{
		Key: answerFile, Name: answerName, Version: answerVersion,
		Slot: chosenSlot,
	}}

	code := setup.Run([]string{boxFlag, boxFolder, maRootFlag, maRoot},
		&stdout, &stderr, fakePicker(items))
	if code != 0 || !strings.Contains(stdout.String(), "At Plugin 205") {
		t.Fatalf("Run() = %d: %s %s", code, stdout.String(), stderr.String())
	}
}
