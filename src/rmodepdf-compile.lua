
local log = logging.new "compile"
local tmpfiles = require "rmodepdf-tmpfiles"
-- this library provides log parsing function
local error_logparser = require "make4ht-errorlogparser"


local function run_latex(content, jobname)
  local devnull =  "> /dev/null 2>&1" 
  if os.type == "windows" then
    devnull = " > nul 2>&1"
  end
  local cmd, msg = io.popen("lualatex --interaction=bathmode -j " .. jobname .. " " .. devnull, "w")
  if not cmd then return nil, msg end
  cmd:write(content)
  return {cmd:close()}, ""
end

local function test_log_file(jobname)
  local log_file_name = jobname .. ".log"
end

local hashes = {}

local function get_hash(filename)
  local f = io.open(filename, "r")
  local content = f:read("*all")
  f:close()
  return md5.sumhexa(content)
end

local function compare_hashes(jobname, extensions)
  local changed = false
  for _, ext in ipairs(extensions) do
    if ext ~= "log" then
      local filename = jobname .. "." .. ext
      local hash = get_hash(filename)
      log:debug("filename hash", filename, hash, hashes[filename])
      if hashes[filename] ~= hash then changed = true end
      hashes[filename] = hash
    end
  end
  return changed
end



local function compile(content, jobname, run_count)
  local run_count = run_count or 1
  log:debug("Compilation number: " .. run_count)
  if run_count > config.max_runs  then return nil, "maximum number of compilations" end
  local res, msg = run_latex(content, jobname)
  if not res  then 
    log:error("Compilation error")
    log:error(msg)
    return nil, msg
  elseif  res[3] > 0 then
    log:error("Compilation error")
    log:error("Status code: " .. res[3])
    return nil, "Non-zero status code from the compilation"
  end
  log:debug("res: " .. res[3])
  if run_count == 1 then
    for _, ext in ipairs(config.aux_files) do
      tmpfiles.register_tmpname(jobname .. "." .. ext)
    end
  end
  if compare_hashes(jobname, config.aux_files) then
    return compile(content, jobname, run_count + 1)
  end
end


return {
  compile = compile
}
