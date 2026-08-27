-- Tiny JSON encode/decode for the honepad trace schema.
-- MIT License. Enough for objects, arrays, strings, numbers, booleans, null.

local json = {}
json.null = {}

local function encode_string(s)
  local parts = {}
  for i = 1, #s do
    local c = s:sub(i, i)
    local b = s:byte(i)
    if c == '"' then
      parts[#parts + 1] = '\\"'
    elseif c == "\\" then
      parts[#parts + 1] = "\\\\"
    elseif c == "\b" then
      parts[#parts + 1] = "\\b"
    elseif c == "\f" then
      parts[#parts + 1] = "\\f"
    elseif c == "\n" then
      parts[#parts + 1] = "\\n"
    elseif c == "\r" then
      parts[#parts + 1] = "\\r"
    elseif c == "\t" then
      parts[#parts + 1] = "\\t"
    elseif b < 32 then
      parts[#parts + 1] = string.format("\\u%04x", b)
    else
      parts[#parts + 1] = c
    end
  end
  return '"' .. table.concat(parts) .. '"'
end

local function is_array(t)
  local n = 0
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
      return false
    end
    if k > n then
      n = k
    end
  end
  return n == #t
end

function json.encode(value)
  if value == nil or value == json.null then
    return "null"
  end
  local tv = type(value)
  if tv == "boolean" then
    return value and "true" or "false"
  end
  if tv == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      error("cannot encode non-finite number")
    end
    if math.type and math.type(value) == "integer" then
      return tostring(value)
    end
    if value % 1 == 0 and math.abs(value) < 1e15 then
      return string.format("%.0f", value)
    end
    return tostring(value)
  end
  if tv == "string" then
    return encode_string(value)
  end
  if tv == "table" then
    if is_array(value) then
      local parts = {}
      for i = 1, #value do
        parts[i] = json.encode(value[i])
      end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(value) do
      if type(k) == "string" then
        keys[#keys + 1] = k
      end
    end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
      parts[#parts + 1] = encode_string(k) .. ":" .. json.encode(value[k])
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  error("cannot encode " .. tv)
end

local escapes = {
  ['"'] = '"',
  ["\\"] = "\\",
  ["/"] = "/",
  b = "\b",
  f = "\f",
  n = "\n",
  r = "\r",
  t = "\t",
}

function json.decode(text)
  local i = 1
  local n = #text

  local function peek()
    return text:sub(i, i)
  end

  local function skip()
    while i <= n and text:sub(i, i):match("%s") do
      i = i + 1
    end
  end

  local parse_value

  local function parse_string()
    i = i + 1
    local parts = {}
    while i <= n do
      local c = text:sub(i, i)
      if c == '"' then
        i = i + 1
        return table.concat(parts)
      end
      if c == "\\" then
        local nxt = text:sub(i + 1, i + 1)
        if nxt == "u" then
          local hex = text:sub(i + 2, i + 5)
          parts[#parts + 1] = utf8.char(tonumber(hex, 16))
          i = i + 6
        else
          parts[#parts + 1] = escapes[nxt] or nxt
          i = i + 2
        end
      else
        parts[#parts + 1] = c
        i = i + 1
      end
    end
    error("unterminated string")
  end

  local function parse_number()
    local start = i
    if peek() == "-" then
      i = i + 1
    end
    while text:sub(i, i):match("%d") do
      i = i + 1
    end
    if peek() == "." then
      i = i + 1
      while text:sub(i, i):match("%d") do
        i = i + 1
      end
    end
    local exp = peek()
    if exp == "e" or exp == "E" then
      i = i + 1
      local sign = peek()
      if sign == "+" or sign == "-" then
        i = i + 1
      end
      while text:sub(i, i):match("%d") do
        i = i + 1
      end
    end
    return tonumber(text:sub(start, i - 1))
  end

  local function parse_array()
    i = i + 1
    skip()
    local arr = {}
    if peek() == "]" then
      i = i + 1
      return arr
    end
    while true do
      arr[#arr + 1] = parse_value()
      skip()
      local c = peek()
      if c == "]" then
        i = i + 1
        return arr
      end
      if c ~= "," then
        error("expected comma or ]")
      end
      i = i + 1
      skip()
    end
  end

  local function parse_object()
    i = i + 1
    skip()
    local obj = {}
    if peek() == "}" then
      i = i + 1
      return obj
    end
    while true do
      if peek() ~= '"' then
        error("expected string key")
      end
      local key = parse_string()
      skip()
      if peek() ~= ":" then
        error("expected colon")
      end
      i = i + 1
      skip()
      obj[key] = parse_value()
      skip()
      local c = peek()
      if c == "}" then
        i = i + 1
        return obj
      end
      if c ~= "," then
        error("expected comma or }")
      end
      i = i + 1
      skip()
    end
  end

  function parse_value()
    skip()
    local c = peek()
    if c == '"' then
      return parse_string()
    end
    if c == "{" then
      return parse_object()
    end
    if c == "[" then
      return parse_array()
    end
    if c == "-" or c:match("%d") then
      return parse_number()
    end
    if text:sub(i, i + 3) == "true" then
      i = i + 4
      return true
    end
    if text:sub(i, i + 4) == "false" then
      i = i + 5
      return false
    end
    if text:sub(i, i + 3) == "null" then
      i = i + 4
      return json.null
    end
    error("unexpected token at " .. i)
  end

  local value = parse_value()
  skip()
  if i <= n then
    error("trailing data")
  end
  return value
end

return json
