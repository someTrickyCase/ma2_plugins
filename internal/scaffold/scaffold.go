package scaffold

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/someTrickyCase/ma2_plugins/internal/manifest"
)

const (
	firstSlot      = 101
	pluginFolder   = "plugins"
	testFolder     = "test/plugins"
	entryFile      = "main.lua"
	testFileName   = "main.test.lua"
	versionText    = "0.1.0"
	filePrefix     = "k-"
	dirPermission  = 0o750
	filePermission = 0o600
)

var (
	errBadName = errors.New("not a plugin name, use kebab-case")
	errExists  = errors.New("plugin already exists")

	namePattern = regexp.MustCompile(`^[a-z][a-z0-9]*(-[a-z0-9]+)*$`)
)

const entryPointTemplate = `local TITLE = "%s"
local VERSION = "%s"

local function start()
  gma.echo(TITLE .. " " .. VERSION)
end

return start
`

const testTemplate = `local lu = require("luaunit")
local fakeGma = require("test.support.fake-gma")

local MAIN = "%s"

local function loadPlugin(fake)
  local environment = setmetatable({ gma = fake.gma }, { __index = _G })
  local chunk = assert(loadfile(MAIN, "t", environment))
  return chunk("plugin_1", "%s")
end

local tests = {}

function tests.testEchoesItsNameAndVersion()
  local fake = fakeGma.new({})
  local start = loadPlugin(fake)
  start()
  lu.assertEquals(fake.echoes, { "%s %s" })
end

return tests
`

type Result struct {
	Name  string
	Title string
	Slot  int
	Files []string
}

type content struct {
	path string
	text string
}

func New(root string, name string) (Result, error) {
	if !namePattern.MatchString(name) {
		return Result{}, fmt.Errorf("%w: %q", errBadName, name)
	}

	folder := filepath.Join(root, pluginFolder, name)

	_, err := os.Stat(folder)
	if err == nil {
		return Result{}, fmt.Errorf("%w: %q", errExists, name)
	}

	slot, err := freeSlot(root)
	if err != nil {
		return Result{}, err
	}

	title := titleFor(name)

	manifestText, err := manifestText(name, title, slot)
	if err != nil {
		return Result{}, err
	}

	files := []content{
		{
			path: manifest.Path(root, name),
			text: manifestText,
		},
		{
			path: filepath.Join(folder, entryFile),
			text: entryPoint(title),
		},
		{
			path: filepath.Join(root, testFolder, name, testFileName),
			text: testFile(name, title),
		},
	}

	written := []string{}

	for _, file := range files {
		err := write(file.path, file.text)
		if err != nil {
			return Result{}, err
		}

		written = append(written, file.path)
	}

	return Result{
		Name:  name,
		Title: title,
		Slot:  slot,
		Files: written,
	}, nil
}

func write(path string, text string) error {
	err := os.MkdirAll(filepath.Dir(path), dirPermission)
	if err != nil {
		return fmt.Errorf("cannot create the folder for %q: %w", path, err)
	}

	err = os.WriteFile(path, []byte(text), filePermission)
	if err != nil {
		return fmt.Errorf("cannot write %q: %w", path, err)
	}

	return nil
}

func freeSlot(root string) (int, error) {
	used, err := usedSlots(root)
	if err != nil {
		return 0, err
	}

	for slot := firstSlot; ; slot++ {
		if !used[slot] {
			return slot, nil
		}
	}
}

func usedSlots(root string) (map[int]bool, error) {
	manifests, err := manifest.ReadAll(root)
	if err != nil {
		return nil, fmt.Errorf("cannot read the manifests: %w", err)
	}

	used := map[int]bool{}

	for _, one := range manifests {
		used[one.Slot] = true
	}

	return used, nil
}

func titleFor(name string) string {
	words := strings.Split(name, "-")
	for index, word := range words {
		words[index] = strings.ToUpper(word[:1]) + word[1:]
	}

	return strings.Join(words, " ")
}

func manifestText(name string, title string, slot int) (string, error) {
	data, err := manifest.Format(manifest.Manifest{
		Name:    title,
		File:    filePrefix + name,
		Version: versionText,
		Slot:    slot,
	})
	if err != nil {
		return "", fmt.Errorf("cannot build the manifest: %w", err)
	}

	return string(data), nil
}

func entryPoint(title string) string {
	return fmt.Sprintf(entryPointTemplate, title, versionText)
}

func testFile(name string, title string) string {
	main := pluginFolder + "/" + name + "/" + entryFile

	return fmt.Sprintf(testTemplate, main, title, title, versionText)
}
