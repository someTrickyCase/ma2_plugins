package bundle_test

import (
	"reflect"
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/bundle"
	"github.com/someTrickyCase/ma2_plugins/internal/manifest"
)

const (
	answerName    = "answer"
	manifestPath  = "plugins/answer/plugin.json"
	mainPath      = "plugins/answer/main.lua"
	mainText      = "return 1\n"
	emptyModule   = "return {}\n"
	answerSlot    = 101
	otherSlot     = 5
	collectError  = "Collect() error = %v"
	collectFails  = "Collect() error = nil, want an error"
	answerVersion = "1.2.3"
)

const answerManifest = `{
  "name": "Answer",
  "file": "k-answer",
  "version": "1.2.3",
  "slot": 101
}
`

func fixedStamp() bundle.Stamp {
	return bundle.Stamp{Commit: "abc1234", Date: "2026-10-24"}
}

func files(pairs map[string]string) bundle.Reader {
	return func(path string) (string, bool) {
		text, found := pairs[path]

		return text, found
	}
}

func TestModulePath(t *testing.T) {
	t.Parallel()

	got := bundle.ModulePath("core.swap-ids")
	want := "lib/core/swap-ids.lua"

	if got != want {
		t.Errorf("ModulePath() = %q, want %q", got, want)
	}
}

func TestCollectReadsTheManifestAndTheStamp(t *testing.T) {
	t.Parallel()

	read := files(map[string]string{
		manifestPath: answerManifest,
		mainPath:     mainText,
	})

	got, err := bundle.Collect(answerName, read, fixedStamp())
	if err != nil {
		t.Fatalf(collectError, err)
	}

	want := bundle.Plugin{
		Manifest: manifest.Manifest{
			Name:    "Answer",
			File:    "k-answer",
			Version: answerVersion,
			Slot:    answerSlot,
		},
		Main:    mainText,
		Modules: []bundle.Module{},
		Stamp:   fixedStamp(),
	}

	if !reflect.DeepEqual(got, want) {
		t.Errorf("Collect() = %+v, want %+v", got, want)
	}
}

func TestCollectFollowsTheRequiresDepthFirst(t *testing.T) {
	t.Parallel()

	read := files(map[string]string{
		manifestPath:     answerManifest,
		mainPath:         `require("ma.a") require("core.b")`,
		"lib/ma/a.lua":   `require("core.b") require("core.c")`,
		"lib/core/b.lua": emptyModule,
		"lib/core/c.lua": emptyModule,
	})

	got, err := bundle.Collect(answerName, read, fixedStamp())
	if err != nil {
		t.Fatalf(collectError, err)
	}

	want := []bundle.Module{
		{Name: "ma.a", Text: `require("core.b") require("core.c")`},
		{Name: "core.b", Text: emptyModule},
		{Name: "core.c", Text: emptyModule},
	}

	if !reflect.DeepEqual(got.Modules, want) {
		t.Errorf("Modules = %+v, want %+v", got.Modules, want)
	}
}

func TestCollectLeavesTheModulesOfMaAlone(t *testing.T) {
	t.Parallel()

	read := files(map[string]string{
		manifestPath: answerManifest,
		mainPath:     `require("socket.core")`,
	})

	got, err := bundle.Collect(answerName, read, fixedStamp())
	if err != nil {
		t.Fatalf(collectError, err)
	}

	if len(got.Modules) != 0 {
		t.Errorf("Modules = %+v, want none", got.Modules)
	}
}

func TestCollectKeepsAnEmptyModule(t *testing.T) {
	t.Parallel()

	read := files(map[string]string{
		manifestPath:         answerManifest,
		mainPath:             `require("core.empty")`,
		"lib/core/empty.lua": "",
	})

	got, err := bundle.Collect(answerName, read, fixedStamp())
	if err != nil {
		t.Fatalf(collectError, err)
	}

	want := []bundle.Module{{Name: "core.empty", Text: ""}}

	if !reflect.DeepEqual(got.Modules, want) {
		t.Errorf("Modules = %+v, want %+v", got.Modules, want)
	}
}

func TestCollectFailsWithoutAManifest(t *testing.T) {
	t.Parallel()

	read := files(map[string]string{
		mainPath: mainText,
	})

	_, err := bundle.Collect(answerName, read, fixedStamp())
	if err == nil {
		t.Error(collectFails)
	}
}

func TestCollectFailsWithoutAMainFile(t *testing.T) {
	t.Parallel()

	read := files(map[string]string{
		manifestPath: answerManifest,
	})

	_, err := bundle.Collect(answerName, read, fixedStamp())
	if err == nil {
		t.Error(collectFails)
	}
}

func TestCollectFailsOnABrokenManifest(t *testing.T) {
	t.Parallel()

	read := files(map[string]string{
		manifestPath: "{name = }",
		mainPath:     mainText,
	})

	_, err := bundle.Collect(answerName, read, fixedStamp())
	if err == nil {
		t.Error(collectFails)
	}
}
