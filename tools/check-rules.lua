local MESSAGES = {
  ascii = "only printable ASCII characters are allowed",
  comment = "code must explain itself, no comments",
}

local NOT_PRINTABLE = "[^ -~]"

local function lineAt(text, position)
  local _, newlines = text:sub(1, position - 1):gsub("\n", "")
  return newlines + 1
end

local function longBracketEnd(text, position)
  local equals = text:match("^%[(=*)%[", position)
  if not equals then
    return nil
  end
  local _, last = text:find("]" .. equals .. "]", position, true)
  return last or #text
end

local function quotedStringEnd(text, position)
  local quote = text:sub(position, position)
  local index = position + 1
  while index <= #text do
    local char = text:sub(index, index)
    if char == "\\" then
      index = index + 2
    elseif char == quote or char == "\n" then
      return index
    else
      index = index + 1
    end
  end
  return #text
end

local function commentEnd(text, position)
  local afterDashes = position + 2
  return longBracketEnd(text, afterDashes)
    or text:find("\n", afterDashes, true)
    or #text
end

local function addCommentViolations(text, found)
  local index = 1
  while index <= #text do
    local char = text:sub(index, index)
    if text:sub(index, index + 1) == "--" then
      found[#found + 1] = { line = lineAt(text, index), rule = "comment" }
      index = commentEnd(text, index) + 1
    elseif char == '"' or char == "'" then
      index = quotedStringEnd(text, index) + 1
    elseif char == "[" then
      index = (longBracketEnd(text, index) or index) + 1
    else
      index = index + 1
    end
  end
end

local function addAsciiViolations(text, found)
  local number = 0
  for line in (text .. "\n"):gmatch("(.-)\n") do
    number = number + 1
    if line:find(NOT_PRINTABLE) then
      found[#found + 1] = { line = number, rule = "ascii" }
    end
  end
end

local function byLineThenRule(a, b)
  if a.line ~= b.line then
    return a.line < b.line
  end
  return a.rule < b.rule
end

local function findViolations(text)
  local found = {}
  addCommentViolations(text, found)
  addAsciiViolations(text, found)
  table.sort(found, byLineThenRule)
  return found
end

local function report(files)
  local lines = {}
  for _, file in ipairs(files) do
    for _, violation in ipairs(findViolations(file.text)) do
      lines[#lines + 1] = string.format(
        "%s:%d: %s: %s",
        file.path,
        violation.line,
        violation.rule,
        MESSAGES[violation.rule]
      )
    end
  end
  return lines
end

return { findViolations = findViolations, report = report }
