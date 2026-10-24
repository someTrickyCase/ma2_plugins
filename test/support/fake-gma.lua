local EMPTY_ID = "-"
local LAYERS_CD = 'cd "Layers"'
local ASSIGN_PATTERN = "cd (%d+); assign (%d+) /(%a+)=(.*)$"
local HANDLE_PATTERN = "^(%a+) (%d+)$"
local ID_PROPERTIES = { Fixture = "FixId", Channel = "ChaId" }
local PROGRESS_HANDLE = 7

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

local function findByName(layers, name)
  local kind, id = name:match(HANDLE_PATTERN)
  local property = ID_PROPERTIES[kind]
  if not property then
    return nil
  end
  for _, layer in ipairs(layers.children) do
    for _, fixture in ipairs(layer.children) do
      if fixture.props[property] == id then
        return fixture
      end
    end
  end
  return nil
end

local function applyEdit(layers, edit)
  local layer = layers.children[edit.layer]
  local fixture = layer.children[edit.position]
  if edit.value == "" then
    fixture.props[edit.property] = EMPTY_ID
  else
    fixture.props[edit.property] = edit.value
  end
end

local function new(options)
  local root, layers = buildPatch(options.layers or {})
  local fake = { commands = {}, dest = root, pending = {} }

  local function commit()
    for _, edit in ipairs(fake.pending) do
      applyEdit(layers, edit)
    end
    fake.pending = {}
    fake.dest = root
  end

  local function remember(layer, position, property, value)
    if options.ignoreAssign then
      return
    end
    fake.pending[#fake.pending + 1] = {
      layer = tonumber(layer),
      position = tonumber(position),
      property = property,
      value = value,
    }
  end

  local function cmd(command)
    fake.commands[#fake.commands + 1] = command
    if options.failWith then
      return options.failWith
    end
    local layer, position, property, value = command:match(ASSIGN_PATTERN)
    if command == "cd /" then
      commit()
    elseif layer then
      remember(layer, position, property, value)
    elseif endsWith(command, LAYERS_CD) and not options.cdLandsNowhere then
      fake.dest = layers
    end
  end

  fake.messages = {}
  fake.questions = {}
  fake.echoes = {}
  fake.progress = {}

  local function progressEvent(event)
    fake.progress[#fake.progress + 1] = event
  end

  local progressWindow = {
    start = function(title)
      progressEvent("start " .. title)
      return PROGRESS_HANDLE
    end,
    setrange = function(_, from, to)
      progressEvent("range " .. from .. " " .. to)
    end,
    set = function(_, value)
      progressEvent("set " .. value)
    end,
    settext = function(_, text)
      progressEvent("text " .. text)
    end,
    stop = function()
      progressEvent("stop")
    end,
  }

  local gui = {
    confirm = function(title, text)
      fake.questions[#fake.questions + 1] = { title = title, text = text }
      return options.confirm ~= false
    end,
    msgbox = function(title, text)
      fake.messages[#fake.messages + 1] = { title = title, text = text }
    end,
    progress = progressWindow,
  }

  fake.gma = {
    cmd = cmd,
    echo = function(text)
      fake.echoes[#fake.echoes + 1] = text
    end,
    sleep = function()
      if options.onSleep then
        options.onSleep()
      end
    end,
    gui = gui,
    user = {
      getcmddest = function()
        return fake.dest
      end,
    },
    show = {
      getobj = {
        handle = function(name)
          return findByName(layers, name)
        end,
        class = function(handle)
          return handle.class
        end,
        amount = function(handle)
          return #handle.children
        end,
        child = function(handle, index)
          return handle.children[index + 1]
        end,
        parent = function(handle)
          return handle.parent
        end,
        index = function(handle)
          return handle.index
        end,
        number = function(handle)
          return tostring(handle.index + 1)
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

  function fake.propsAt(layerNumber, position)
    return layers.children[layerNumber].children[position].props
  end

  return fake
end

return { new = new }
