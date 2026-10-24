local EMPTY_ID = "-"
local LAYERS_CD = 'cd "Layers"'
local ASSIGN_PATTERN = "cd (%d+); assign (%d+) /(%a+)=(.*)$"
local HANDLE_PATTERN = "^(%a+) (%d+)$"
local ID_PROPERTIES = { Fixture = "FixId", Channel = "ChaId" }
local PROGRESS_HANDLE = 7
local STORE_PATTERN = '^Store (%a+) (%d+) "(.-)" /nc$'
local RECALL_PATTERN = "^Group (%d+)$"
local SELECTED_COUNT = "SELECTEDFIXTURESCOUNT"

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

local function poolObject(label, members)
  local pool = object("CMD_GROUP", { Name = label })
  pool.label = label
  pool.members = members
  return pool
end

local function buildPools(options)
  local pools = { Group = {}, Layout = {} }
  for _, number in ipairs(options.groups or {}) do
    pools.Group[number] = poolObject("old", {})
  end
  for _, number in ipairs(options.layouts or {}) do
    pools.Layout[number] = poolObject("old", {})
  end
  return pools
end

local function copy(list)
  return { table.unpack(list) }
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
  local pools = buildPools(options)
  local fake = { commands = {}, dest = root, pending = {}, selection = {} }

  local function store(kind, number, label)
    local members = copy(fake.selection)
    if options.groupLosesOne and kind == "Group" then
      members[#members] = nil
    end
    pools[kind][tonumber(number)] = poolObject(label, members)
  end

  local function select(command)
    local fixture = findByName(layers, command)
    if fixture and not options.selectNothing then
      fake.selection[#fake.selection + 1] = fixture
    end
  end

  local function selectionCommand(command)
    local kind, number, label = command:match(STORE_PATTERN)
    local recalled = command:match(RECALL_PATTERN)
    if command == "ClearSelection" then
      fake.selection = {}
    elseif kind and not options.storeIgnored then
      store(kind, number, label)
    elseif recalled then
      fake.selection = copy(pools.Group[tonumber(recalled)].members)
    else
      select(command)
    end
  end

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
    else
      selectionCommand(command)
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
      getvar = function(name)
        if name == SELECTED_COUNT then
          return tostring(#fake.selection)
        end
      end,
      getobj = {
        handle = function(name)
          local kind, number = name:match(HANDLE_PATTERN)
          if pools[kind] then
            return pools[kind][tonumber(number)]
          end
          return findByName(layers, name)
        end,
        label = function(handle)
          return handle.label
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

  function fake.poolMembers(kind, number)
    local names = {}
    for _, fixture in ipairs(pools[kind][number].members) do
      names[#names + 1] = fixture.props.Name
    end
    return names
  end

  function fake.propsAt(layerNumber, position)
    return layers.children[layerNumber].children[position].props
  end

  return fake
end

return { new = new }
