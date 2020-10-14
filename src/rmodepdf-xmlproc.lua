-- use template string to place the processed children
local function simple_content(s)
  return function(element)
    local content = process_children(element)
    -- process attrubutes
    -- attribute should be marked as @{name}
    local expanded = s:gsub("@{(.-)}", function(name)
      return element:get_attribute(name) or ""
    end)
    return string.format(expanded, content)
  end
end

local function get_child_element(element, count)
  -- return specified child element 
  local i = 0
  for _, el in ipairs(element:get_children()) do
    -- count elements 
    if el:is_element() then
      -- return the desired numbered element
      i = i + 1
      if i == count then return el end
    end
  end
end

-- actions for particular elements
local actions = {
  
}

-- add more complicated action
local function add_custom_action(name, fn)
  actions[name] = fn
end

-- normal actions
local function add_action(name, template)
  actions[name] = simple_content(template)
end

-- convert Unicode characters to TeX sequences
local unicodes = {
  [35] = "\\#",
  [38] = "\\&",
  [60] = "\\textless{}",
  [62] = "\\textgreater{}",
  [92] = "\\textbackslash{}",
  [123] = "\\{",
  [125] = "\\}"
}

local function process_text(text)
  local t = {}
  -- process all Unicode characters and find if they should be replaced
  for _, char in utf8.codes(text) do
    -- construct new string with replacements or original char
    t[#t+1] = unicodes[char] or utf8.char(char)
  end
  return table.concat(t)
end

function process_children(element)
  -- accumulate text from children elements
  local t = {}
  -- sometimes we may get text node
  if type(element) ~= "table" then return element end
  for i, elem in ipairs(element:get_children()) do
    if elem:is_text() then
      -- concat text
      t[#t+1] = process_text(elem:get_text())
    elseif elem:is_element() then
      -- recursivelly process child elements
      t[#t+1] = process_tree(elem)
    end
  end
  return table.concat(t)
end


function process_tree(element)
  -- find specific action for the element, or use the default action
  local element_name = element:get_element_name()
  local action = actions[element_name] or default_action
  return action(element)
end

function parse_xml(content)
  -- parse XML string and process it
  local dom = domobject.parse(content)
  -- start processing of DOM from the root element
  -- return string with TeX content
  return process_tree(dom:root_node())
end

local function load_file(filename)
  local f = io.open(filename, "r")
  local content = f:read("*all")
  f:close()
  return parse_xml(content)
end


function print_tex(content)
  -- we need to replace "\n" characters with calls to tex.sprint
  for s in content:gmatch("([^\n]*)") do
    tex.sprint(s)
  end
end


local M = {
  parse_xml = parse_xml,
  process_children = process_children,
  print_tex = print_tex,
  add_action = add_action,
  add_custom_action = add_custom_action,
  simple_content = simple_content,
  load_file = load_file
}

return M