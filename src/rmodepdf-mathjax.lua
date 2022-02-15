-- preprocess DOM and find inline LaTeX code, like MathJax
--

local function list_to_hash(tbl)
  local t = {}
  for _, v in ipairs(tbl) do t[v] = true end
  return t
end

local function is_math(text, allowed_commands)
  if text:match("\\%(.+\\%)") then return true end
  if text:match("\\%[.+\\%]") then return true end
  if text:match("%$%$.+%$%$") then return true end
  -- support for $ is a bit more complicated, as we don't want to 
  -- be too eagerly. $ can be used in normal text
  -- match $ ... \ ... $
  if text:match("%$.*%\\.+%$") then return true end
  -- match $ ... = ... $ 
  if text:match("%$.+%=.+%$") then return true end
  if text:match("\\begin.+\\end") then return true end
end

local function fix_latex(child, allowed_commands)
  -- at this moment, we will just add the <mathjax> element around the
  -- whole text that contain LaTeX math. we can add more advanced
  -- parser in the future, but I think that it sufficess at the moment
  local text = child._text
  if is_math(text, allowed_commands) then
    -- add the mathjax element
    local parent = child:get_parent()
    local mathjax = parent:create_element("mathjax")
    local text = mathjax:create_text_node(text)
    mathjax:add_child_node(text)
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
