local function new(gma)
  local last = gma.gettime()
  local calls = 0
  return function()
    calls = calls + 1
    if gma.gettime() - last >= 0.05 or calls >= 8 then
      gma.sleep(0.01)
      last = gma.gettime()
      calls = 0
    end
  end
end

return { new = new }
