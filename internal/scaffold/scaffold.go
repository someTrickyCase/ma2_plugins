package scaffold

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"github.com/someTrickyCase/ma2_plugins/internal/readfile"
)

const (
	firstSlot      = 101
	pluginFolder   = "plugins"
	testFolder     = "test/plugins"
	manifestFile   = "plugin.lua"
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
	slotPattern = regexp.MustCompile(`slot\s*=\s*([0-9]+)`)
)

const manifestTemplate = `return {
  name = "%s",
  file = "%s",
  version = "%s",
  slot = %d,
}
`

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
	files := []content{
		{
			path: filepath.Join(folder, manifestFile),
			text: manifest(name, title, slot),
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
	texts, err := manifestTexts(root)
	if err != nil {
		return nil, err
	}

	used := map[int]bool{}

	for _, text := range texts {
		slot, found := slotOf(text)
		if found {
			used[slot] = true
		}
	}

	return used, nil
}

func manifestTexts(root string) ([]string, error) {
	pattern := filepath.Join(root, pluginFolder, "*", manifestFile)

	paths, err := filepath.Glob(pattern)
	if err != nil {
		return nil, fmt.Errorf("cannot list the plugins: %w", err)
	}

	texts := []string{}

	for _, path := range paths {
		text, err := readfile.Read(path)
		if err != nil {
			return nil, fmt.Errorf("cannot read %q: %w", path, err)
		}

		texts = append(texts, string(text))
	}

	return texts, nil
}

func slotOf(text string) (int, bool) {
	found := slotPattern.FindStringSubmatch(text)
	if found == nil {
		return 0, false
	}

	slot, err := strconv.Atoi(found[1])
	if err != nil {
		return 0, false
	}

	return slot, true
}

func titleFor(name string) string {
	words := strings.Split(name, "-")
	for index, word := range words {
		words[index] = strings.ToUpper(word[:1]) + word[1:]
	}

	return strings.Join(words, " ")
}

func manifest(name string, title string, slot int) string {
	return fmt.Sprintf(
		manifestTemplate, title, filePrefix+name, versionText, slot)
}

func entryPoint(title string) string {
	return fmt.Sprintf(entryPointTemplate, title, versionText)
}

func testFile(name string, title string) string {
	main := pluginFolder + "/" + name + "/" + entryFile

	return fmt.Sprintf(testTemplate, main, title, title, versionText)
}
