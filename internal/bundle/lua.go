package bundle

import "strings"

const (
	partsPerModule = 3
	extraParts     = 4
)

const prelude = `local modules = {}
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
end`

func Lua(plugin Plugin) string {
	parts := make([]string, 0, len(plugin.Modules)*partsPerModule+extraParts)
	parts = append(parts, prelude)

	for _, module := range plugin.Modules {
		parts = append(parts, "modules["+Quote(module.Name)+"] = function()")
		parts = append(parts, module.Text)
		parts = append(parts, "end")
	}

	parts = append(parts, "gma.echo("+Quote(stampText(plugin))+")")
	parts = append(parts, "return (function(...)")
	parts = append(parts, plugin.Main)
	parts = append(parts, "end)(...)")

	return strings.Join(parts, "\n") + "\n"
}

func stampText(plugin Plugin) string {
	build := plugin.Stamp.Commit + ", " + plugin.Stamp.Date

	return plugin.Manifest.Name + " " + plugin.Manifest.Version +
		" (" + build + ")"
}
