local EMPTY_ID = "-"
local LAYERS_CD = 'cd "Layers"'

local function object(class, props)
  return { class = class, props = props, children = {} }
end

local function addChild(parent, child)
  child.parent = parent
  child.index = #parent.children
  parent.children[#parent.children + 1] = child
  return child
end

local function fixtureObject(fixture)
  return object("CMD_FIXTURE", {
    Name = fixture.name,
    FixId = fixture.fixId or EMPTY_ID,
    ChaId = fixture.chaId or EMPTY_ID,
  })
end

local function buildPatch(layers)
  local root = object("CMD_ROOT", {})
  local collect = object("CMD_FIXTURE_LAYER_COLLECT", { Name = "Layers" })
  addChild(root, collect)
  for _, layer in ipairs(layers) do
    local layerObject = object("CMD_FIXTURE_LAYER", { Name = layer.name })
    addChild(collect, layerObject)
    for _, fixture in ipairs(layer.fixtures) do
      addChild(layerObject, fixtureObject(fixture))
    end
  end
  return root, collect
end

local function endsWith(text, suffix)
  return text:sub(-#suffix) == suffix
end

local function new(options)
  local root, layers = buildPatch(options.layers or {})
  local fake = { commands = {}, dest = root }

  local function cmd(command)
    fake.commands[#fake.commands + 1] = command
    if options.failWith then
      return options.failWith
    end
    if command == "cd /" then
      fake.dest = root
    elseif endsWith(command, LAYERS_CD) and not options.cdLandsNowhere then
      fake.dest = layers
    end
  end

  fake.gma = {
    cmd = cmd,
    user = {
      getcmddest = function()
        return fake.dest
      end,
    },
    show = {
      getobj = {
        class = function(handle)
          return handle.class
        end,
        amount = function(handle)
          return #handle.children
        end,
        child = function(handle, index)
          return handle.children[index + 1]
        end,
      },
      property = {
        get = function(handle, name)
          return handle.props[name]
        end,
      },
    },
  }

  function fake.lastCommand()
    return fake.commands[#fake.commands]
  end

  return fake
end

return { new = new }
