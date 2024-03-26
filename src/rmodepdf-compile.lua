
local tmpfiles = require "rmodepdf-tmpfiles"
-- this library provides log parsing function
local error_logparser = require "make4ht-errorlogparser"


local function run_latex(content, jobname)
  local devnull =  "> /dev/null 2>&1" 
  if os.type == "windows" then
    devnull = " > nul 2>&1"
  end
  local cmd = io.popen("lualatex --interaction=bathmode -j " .. jobname .. " " .. devnull, "w")
  cmd:write(content)
  return {cmd:close()}
end

local function test_log_file(jobname)
  local log_file_name = jobname .. ".log"

  
end





local function compile(content, jobname)
  local res = run_latex(content, jobname)
  print("res: " .. res[3])
  for _, ext in ipairs(config.aux_files) do
    tmpfiles.register_tmpname(jobname .. "." .. ext)
  end
end


return {
  compile = compile
}
