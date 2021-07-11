local transform = require "luaxml-transform"

local function load_unicodes(filename, unicodes)
  -- process unicode-math-table.tex to get mapping between unicode and tex commands
  local unicodes = unicodes or {}
  for line in io.lines(filename) do
    -- first matched text is hexa unicode char, second is tex command
    local uni, command = line:match("UnicodeMathSymbol{\"(.-)}{([^%s]+)")
    if uni then
      unicodes[tonumber(uni, 16)] = command
    end
  end
end

local process_children = transform.process_children
local transformer = transform.new()

transformer:add_action("math", "$@<.>$", {collapse_newlines = true})
transformer:add_action("math[display='inline§]", "$@<.>$", {collapse_newlines = true})
transformer:add_action("math[display='block']", "\\[@<.>\\]", {collapse_newlines = true})
transformer:add_action("msup", "{@<1>}^{@<2>}")
transformer:add_action("msub", "{@<1>}_{@<2>}")
transformer:add_action("msubsup", "{@<1>}_{@<2>}^{@<3>}")
transformer:add_action("mrow", "{@<.>}", {collapse_newlines = true})
transformer:add_action("mfrac", "\\frac{@<1>}{@<2>}",{collapse_newlines = true})
transformer:add_action("msqrt", "\\sqrt{@<.>}", {collapse_newlines = true})
transformer:add_action("semantics", "@<1>", {collapse_newlines = true})

transformer:add_action("mtable", "\\begin{matrix}@<.>\\end{matrix}", {collapse_newlines = true})
transformer:add_action("mtr", "@<mtd> \\\\", {collapse_newlines = true, separator = " & "})

transformer:add_custom_action("mtable[columnalign]", function(el)
  local align = el:get_attribute("columnalign")
  -- convert attribute to LaTeX array syntax
  align = align:gsub("left", "l"):gsub("center", "c"):gsub("right", "r")
  local content = process_children(el)
  return "\\begin{array}{" .. align .. "}" .. content .. "\\end{array}"
end)

transformer:add_action("mn", "{@<.>}", {collapse_newlines = true})
transformer:add_action("mi", "{@<.>}", {collapse_newlines = true})
transformer:add_action("mo", "{@<.>}", {collapse_newlines = true})

transformer:add_custom_action("mfenced", function(el)
  local open = el:get_attribute("open") or "."
  local close = el:get_attribute("close") or "."
  local function add_fence(typ, x)
    -- turn ("left", "(") to "\left\(
    if x:match("[{}]") then
      -- add backslash to
      x = "\\" .. x
    end
    return "\\" .. typ .. x
  end
  open = add_fence("left", open)
  close = add_fence("right", close)

  local content = process_children(el)
  return open .. content .. close
end)


transformer.unicodes[0x03C0] = "\\pi"
transformer.unicodes[0x00B1] = "\\pm"
transformer.unicodes[0x222B] = "\\int"
transformer.unicodes[0x1D555] = "\\mathbb{d}"

--- try to load unicode-math data for mapping between unicode and LaTeX commands
local path = kpse.find_file("unicode-math-table.tex", "tex")
if path then
  load_unicodes(path, transformer.unicodes)
end

return {
  transformer = transformer
}
