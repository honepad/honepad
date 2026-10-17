#!/usr/bin/env lua

local function adapter_dir()
  local src = arg[0] or ""
  return src:match("^(.*)[/\\]") or "."
end

package.path = adapter_dir() .. "/?.lua;" .. package.path
local json = require("json")
local unpack = table.unpack or unpack

local function store(value)
  if value == nil then
    return json.null
  end
  return value
end

local function is_nonfinite(value, seen)
  local tv = type(value)
  if tv == "number" then
    return value ~= value or value == math.huge or value == -math.huge
  end
  if tv ~= "table" or value == json.null then
    return false
  end
  seen = seen or {}
  if seen[value] then
    return false
  end
  seen[value] = true
  for _, item in pairs(value) do
    if is_nonfinite(item, seen) then
      return true
    end
  end
  return false
end

local function tag_value(value, seen)
  local tv = type(value)
  if tv == "number" then
    if value ~= value then
      return "NaN"
    end
    if value == math.huge then
      return "Infinity"
    end
    if value == -math.huge then
      return "-Infinity"
    end
    return value
  end
  if tv ~= "table" or value == json.null then
    return value
  end
  seen = seen or {}
  if seen[value] then
    return "circular"
  end
  seen[value] = true
  local out = {}
  for key, item in pairs(value) do
    out[key] = tag_value(item, seen)
  end
  seen[value] = nil
  return out
end

local function main()
  local file = arg[1]
  local class_name = arg[2]
  local cases_path = arg[3]
  local orig_write = io.write
  print = function() end
  io.write = function() end
  io.stdout = { write = function() end }
  dofile(file)
  local cls = _G[class_name]
  if type(cls) ~= "table" or type(cls.new) ~= "function" then
    error("missing class " .. tostring(class_name))
  end
  local handle = assert(io.open(cases_path, "r"))
  local raw = handle:read("*a")
  handle:close()
  local cases = json.decode(raw)
  local failed = {}
  local passed = 0
  for _, case in ipairs(cases) do
    local obj = cls.new()
    local ok = true
    for i, call in ipairs(case.calls) do
      local method = call.m
      local args = call.a
      local expected = call.e
      local fn = obj[method]
      local actual
      if type(fn) ~= "function" then
        failed[#failed + 1] = {
          case = case.id,
          index = i - 1,
          method = method,
          expected = store(expected),
          actual = "exc:missing_method",
        }
        ok = false
        break
      end
      local ran, result = pcall(fn, obj, unpack(args))
      if not ran then
        local err = tostring(result):gsub("%s+$", "")
        err = err:gsub("%s+%[string .*", "")
        failed[#failed + 1] = {
          case = case.id,
          index = i - 1,
          method = method,
          expected = store(expected),
          actual = "exc:" .. err,
        }
        ok = false
        break
      end
      actual = result
      local bad = is_nonfinite(actual)
      if bad or json.encode(actual) ~= json.encode(expected) then
        local shown = bad and tag_value(actual) or actual
        failed[#failed + 1] = {
          case = case.id,
          index = i - 1,
          method = method,
          expected = store(expected),
          actual = store(shown),
        }
        ok = false
        break
      end
    end
    if ok then
      passed = passed + 1
    end
  end
  local parts = {}
  for i = 1, #failed do
    parts[i] = json.encode(failed[i])
  end
  orig_write(string.format('{"passed":%d,"failed":[%s]}\n', passed, table.concat(parts, ",")))
  if #failed > 0 then
    os.exit(1)
  end
  os.exit(0)
end

main()
