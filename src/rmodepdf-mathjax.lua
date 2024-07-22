-- preprocess DOM and find inline LaTeX code, like MathJax
--

local function list_to_hash(tbl)
  local t = {}
  for _, v in ipairs(tbl) do t[v] = true end
  return t
end

local math_patterns = {
"\\%(.+\\%)",
"\\%[.+\\%]",
"%$%$.+%$%$",
"%$.*%\\.+%$",
"%$.+%=.+%$",
"\\begin.+\\end" ,
}

--- find if text contains math
---@param text string where to look for math
---@param position integer|nil starting position of the lookup
---@return integer
---@return integer|nil
local function find_math(text, position)
  -- loop over math patterns and try to find if the text node contains any
  -- return 
  local position = position or 1
  local found = {}
  for _, pattern in ipairs(math_patterns) do
    local start, stop = string.find(text, pattern, position)
    if start then found[#found+1] = {start, stop} end
  end
  if #found == 0 then return nil end
  -- there may be multiple matches. we need to go from left to right and return the first
  table.sort(found, function(a,b) return a[1] < b[1] end)
  return table.unpack(found[1])
end


--- get table with text and math chunks from the current text node
---@param text string
---@return nil
local function get_chunks(text)
  local chunks = {}
  local previous = 1
  local start, stop = find_math(text)
  -- if we didn't find any math, return nil so the original text will be not modified
  if not start then return nil end
  while start do
    if start > 1 then 
      chunks[#chunks+1] = {string = text:sub(previous, start-1), type="text"}
    end
    chunks[#chunks+1] = {string = text:sub(start, stop), type="math"}
    previous = stop + 1
    start, stop = find_math(text, previous)
  end
  if previous < string.len(text) then
    chunks[#chunks+1] = {string = text:sub(previous), type="text"}
  end
  return chunks

end

local function fix_latex(child, allowed_commands)
  -- at this moment, we will just add the <mathjax> element around the
  -- whole text that contain LaTeX math. we can add more advanced
  -- parser in the future, but I think that it sufficess at the moment
  local text = child._text
  local chunks = get_chunks(text)
  -- if is_math(text, allowed_commands) then
  if chunks then
    -- add the mathjax element
    local parent = child:get_parent()
    local mathjax = parent:create_element("mathjax-parent")
    -- add <mathjax> or text nodes for all chunks of math
    for _, child in ipairs(chunks) do
      if child.type == "math" then
        local child_element = mathjax:create_element("mathjax")
        local text = child_element:create_text_node(child.string)
        child_element:add_child_node(text)
        mathjax:add_child_node(child_element)
      else
        local text = mathjax:create_text_node(child.string)
        mathjax:add_child_node(text)
      end
    end
    child:replace_node(mathjax)
  end
end

local function traverse_elements(current, ignored_elements, allowed_commands)
	local current = current or {}
	-- Following situation may happen when this method is called directly on the parsed object
	if not current:get_node_type() then
		current = current:root_node() 
	end
	if current:is_element() or current:get_node_type() == "ROOT" then
    if not ignored_elements[current:get_element_name()] then
			for _, child in ipairs(current:get_children()) do
        if child:is_text() then
          fix_latex(child, allowed_commands)
        else
          traverse_elements(child, ignored_elements, allowed_commands)
        end
			end
		end
	end
end



-- keep LaTeX math and selected commands in the transformed HTML code 
function process_latex(dom, ignored_elements, allowed_commands)
	-- we don't want to do this preprocessing in <code> or <pre> elements
	local ignored_elements = list_to_hash(ignored_elements or {})
	-- list of LaTeX commands that should be kept in the source
	local allowed_commands = list_to_hash(allowed_commands or {})
  traverse_elements(dom, ignored_elements, allowed_commands)
end

return {
  process_latex = process_latex
}
