
local log = logging.new "tmpfiles"
local tmpfiles = {}

local function register_tmpname(name)
  -- register tmp name, so it can be removed later
  tmpfiles[#tmpfiles+1] = name
end

local function tmpname()
  -- return tmp file name and register it in the list of tmp files
  local name = os.tmpname()
  register_tmpname(name)
  return name
end

local function clean()
  -- remove all registered tmp files
  for _, name in ipairs(tmpfiles) do
    log:debug("removing tmp file: ", name)
    os.remove(name)
  end
end

return {
  tmpname = tmpname,
  register_tmpname = register_tmpname,
  clean = clean,
}

