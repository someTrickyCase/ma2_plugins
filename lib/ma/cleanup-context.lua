local function sequence(gma)
  local getobj = gma.show.getobj
  local selected = gma.user.getselectedexec()
  if not selected then
    return nil, "No selected executor"
  end
  local address = getobj.number(selected)
  if not address or address == "" then
    return nil, "Selected executor has no readable number"
  end
  local cue = getobj.handle("Executor " .. address .. " Cue 1")
  if not cue then
    return nil, "Cannot resolve selected sequence through Cue 1"
  end
  local parent = getobj.parent(cue)
  if not parent or getobj.class(parent) ~= "CMD_SEQUENCE" then
    return nil, "Executor cue has no sequence parent"
  end
  return getobj.number(parent)
end

local function fixture(gma, address)
  local getobj = gma.show.getobj
  local handle = getobj.handle(address)
  if not handle then
    return nil, "Fixture not found"
  end
  if getobj.amount(handle) ~= 1 then
    return nil, "Fixture instance mapping is not verified"
  end
  local instance = getobj.child(handle, 0)
  local value = gma.show.property.get(instance, "Fixture|Type")
  local number = type(value) == "string" and value:match("^(%d+)%s")
  if not number then
    return nil, "Fixture type cannot be read"
  end
  return { type = number, module = "0" }
end

local function fixtures(gma, addresses, yield, progress)
  local result = { fixtures = {}, types = {}, uncertain = {} }
  local seen = {}
  for index, address in ipairs(addresses) do
    local definition, problem = fixture(gma, address)
    if definition then
      result.fixtures[address] = definition
      if not seen[definition.type] then
        seen[definition.type] = true
        result.types[#result.types + 1] = definition.type
      end
    else
      result.uncertain[#result.uncertain + 1] = {
        address = address,
        problem = problem,
      }
    end
    if progress then
      progress(index, #addresses)
    end
    if yield then
      yield()
    else
      gma.sleep(0.01)
    end
  end
  table.sort(result.types, function(left, right)
    return tonumber(left) < tonumber(right)
  end)
  return result
end

return { sequence = sequence, fixtures = fixtures }
