package bundle_test

import (
	"testing"

	"github.com/someTrickyCase/ma2_plugins/internal/bundle"
	"github.com/someTrickyCase/ma2_plugins/internal/manifest"
)

func answerPlugin(modules []bundle.Module) bundle.Plugin {
	return bundle.Plugin{
		Manifest: manifest.Manifest{
			Name:    "Answer",
			File:    "k-answer",
			Version: answerVersion,
			Slot:    answerSlot,
		},
		Main:    mainText,
		Modules: modules,
		Stamp:   fixedStamp(),
	}
}

func TestLua(t *testing.T) {
	t.Parallel()

	plugin := answerPlugin([]bundle.Module{
		{Name: "core.b", Text: "return { value = 42 }\n"},
	})

	want := `local modules = {}
local loaded = {}
local realRequire = require
local function require(name)
  local loader = modules[name]
  if not loader then
    return realRequire(name)
  end
  if loaded[name] == nil then
    loaded[name] = loader()
  end
  return loaded[name]
end
modules["core.b"] = function()
return { value = 42 }

end
gma.echo("Answer 1.2.3 (abc1234, 2026-10-24)")
return (function(...)
return 1

end)(...)
`

	if got := bundle.Lua(plugin); got != want {
		t.Errorf("Lua() =\n%s\nwant\n%s", got, want)
	}
}

func TestLuaWithoutModules(t *testing.T) {
	t.Parallel()

	plugin := answerPlugin([]bundle.Module{})

	want := `local modules = {}
local loaded = {}
local realRequire = require
local function require(name)
  local loader = modules[name]
  if not loader then
    return realRequire(name)
  end
  if loaded[name] == nil then
    loaded[name] = loader()
  end
  return loaded[name]
end
gma.echo("Answer 1.2.3 (abc1234, 2026-10-24)")
return (function(...)
return 1

end)(...)
`

	if got := bundle.Lua(plugin); got != want {
		t.Errorf("Lua() =\n%s\nwant\n%s", got, want)
	}
}
