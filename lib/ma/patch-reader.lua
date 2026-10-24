local LAYERS_PATH = 'cd /; cd "EditSetup"; cd "Layers"'
local LAYERS_CLASS = "CMD_FIXTURE_LAYER_COLLECT"
local EMPTY_ID = "-"

local function parseId(text)
  if text == EMPTY_ID then
    return nil
  end
  return math.tointeger(tonumber(text))
end

local function children(gma, handle)
  local getobj = gma.show.getobj
  local found = {}
  for index = 0, getobj.amount(handle) - 1 do
    found[#found + 1] = getobj.child(handle, index)
  end
  return found
end

local function readFixture(gma, handle, layerName)
  local get = gma.show.property.get
  return {
    name = get(handle, "Name"),
    layer = layerName,
    fixId = parseId(get(handle, "FixId")),
    chaId = parseId(get(handle, "ChaId")),
  }
end

local function readLayers(gma, layers)
  local fixtures = {}
  for _, layer in ipairs(children(gma, layers)) do
    local layerName = gma.show.property.get(layer, "Name")
    for _, fixture in ipairs(children(gma, layer)) do
      fixtures[#fixtures + 1] = readFixture(gma, fixture, layerName)
    end
  end
  return fixtures
end

local function openLayers(gma)
  local problem = gma.cmd(LAYERS_PATH)
  if problem then
    return nil, problem
  end
  local layers = gma.user.getcmddest()
  local class = gma.show.getobj.class(layers)
  if class ~= LAYERS_CLASS then
    return nil, "landed in " .. tostring(class)
  end
  return layers
end

local function read(gma)
  local layers, problem = openLayers(gma)
  local fixtures = layers and readLayers(gma, layers)
  gma.cmd("cd /")
  if not layers then
    return nil, "cannot open the patch: " .. problem
  end
  return fixtures
end

return { read = read }
