-- Library for TeX templates expansion
--- @module 'textemplates'
local textemplates = {}

--- remove braces
--- @param text string braced text
local function remove_braces(text)
  return text:gsub("^{", ""):gsub("}$","")
end

--- find if table contains a value. multidimensional values can be specified, separated by dot
---@param text string dot separated tree of values
---@param params table to be searched
local function get_value(text, params)
  -- get value before dot and rest of the string
  local key, rest = text:match("([^%.]+)%.?(.*)")
  local value = params[key]
  if value then
    if rest and rest ~= ""  then
      -- try to find next key in the current subtable
      return get_value(rest, value)
    else
      return value
    end
  end
  return nil
end

--- expand template
---@param template string
---@param content string
---@param params table
---@return string
function textemplates.expand(template, content, params)
  local content = content or ""
  local params = params or {}
  -- test if the variable in the first parameter exists and expand true or false part accordingly
  local result = template:gsub("%?(%b{})(%b{})(%b{})", function(test, true_part, false_part)
    local test, true_part, false_part = remove_braces(test), remove_braces(true_part), remove_braces(false_part)
    local value = get_value(test, params)
    if value then
      return textemplates.expand(true_part, content, params)
    else
      return textemplates.expand(false_part, content, params)
    end
  end)
  --  expand variables from params
  result = result:gsub("@(%b{})", function(key)
    local key = remove_braces(key)
    -- return original text if the value is empty
    if not key or key == "" then return "@{}" end
    return get_value(key, params) or ""
  end)
  result = result:gsub("%%s", content)
  return result
end



return textemplates
