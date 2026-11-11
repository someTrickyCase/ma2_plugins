local function read(path)
  local file, problem = io.open(path, "rb")
  assert(file, problem)
  local content, failure = file:read("*a")
  local closed, closing = file:close()
  assert(content, failure)
  assert(closed, closing)
  return content
end

local function write(path, content)
  local file, problem = io.open(path, "wb")
  assert(file, problem)
  local written, failure = file:write(content)
  local closed, closing = file:close()
  assert(written, failure)
  assert(closed, closing)
end

local function new(gma, storage)
  storage = storage or { read = read, write = write }
  local root = gma.show.getvar("PATH")
  assert(type(root) == "string" and root ~= "", "Missing MA2 data path")
  local prefix = "k-sequence-cleanup-"
    .. string.format("%.0f", gma.gettime() * 1000000)
    .. "-"

  local function basename(tag)
    assert(tag:match("^[a-z0-9-]+$"), "Invalid internal filename")
    return prefix .. tag
  end

  local function path(tag, folder)
    return root
      .. "/"
      .. (folder or "importexport")
      .. "/"
      .. basename(tag)
      .. ".xml"
  end

  local function command(text)
    local problem = gma.cmd(text)
    assert(not problem, tostring(problem))
    gma.sleep(0.01)
  end

  local function export(object, tag, folder)
    command("Export " .. object .. ' "' .. basename(tag) .. '" /o')
    return storage.read(path(tag, folder))
  end

  local function save(tag, content)
    storage.write(path(tag), content)
  end

  local function import(object, tag)
    command('Import "' .. basename(tag) .. '.xml" At ' .. object .. " /o")
  end

  return { command = command, export = export, save = save, import = import }
end

return { new = new }
