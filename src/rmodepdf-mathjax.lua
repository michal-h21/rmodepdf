-- preprocess DOM and find inline LaTeX code, like MathJax
--

local function list_to_hash(tbl)
  local t = {}
  for _, v in ipairs(tbl) do t[v] = true end
  return t
end

function traverse_elements(current, ignored_elements, allowed_commands)
	local current = current or {}
	-- Following situation may happen when this method is called directly on the parsed object
	if not current:get_node_type() then
		current = current:root_node() 
	end
	if current:is_element() or current:get_node_type() == "ROOT" then
    print("processing", current:get_element_name())
    if not ignored_elements[current:get_element_name()] then
      print("not ignored")
			for _, child in ipairs(self:get_children(current)) do
				traverse_elements(child, ignored_elements, allowed_commands)
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
