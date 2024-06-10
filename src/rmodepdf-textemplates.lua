-- Library for TeX templates expansion
--- @module 'textemplates'
local textemplates = {}

--- expand
---@param template string
---@param content string
---@param params table
---@return string
function textemplates.expand(template, content, params)
  local content = content or ""
  local params = params or {}
  -- first, expand variables from params
  local result = template:gsub("@{(..*)}", function(key)
    return params[key] or ""
  end)
  result = result:gsub("%%s", content)
  return result
end



return textemplates
