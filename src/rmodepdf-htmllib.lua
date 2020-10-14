
-- download content of URL
local function curl(url)
  local command = io.popen("curl -sS ".. url,"r")
  if not command then return nil, "Cannot execute curl" end
  local content = command:read("*all")
  command:close()
  return content
end

local function parse_metadatafile(metadatafile)
  local metadata = {}
  for line in io.lines(metadatafile) do
    local key, value = line:match("(.-)%s*:%s*(.+)")
    metadata[key] = value
  end
  return metadata
end

local htmltemplate = [[<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8" />
<title>${Title}</title>
<meta name="author" content="${Byline}" />
</head>
<body>
${content}
</body>
</html>
]]


-- update the cleaned html file with a full HTML template
-- we use this to suppress some tidy errors and to pass 
-- the metadata to the generated page
local function html_skeleton(tmpfile, metadata)
  local function expand(str, tbl)
    return str:gsub("${(.-)}", tbl)
  end
  local f = io.open(tmpfile, "r")
  local content = f:read("*all")
  metadata.content = content -- make content available in the template
  f:close()
  -- insert metadata and html to the template and update the tmpfile
  local newcontent = expand(htmltemplate, metadata)
  f = io.open(tmpfile, "w")
  f:write(newcontent)
  f:close()
end

-- run the readability command to remove clutter from the HTML page
local function readability(content, baseurl)
  local tmpfile = os.tmpname() -- the clean up html content will be saved here
  local metadatafile = os.tmpname() -- we can get also some metadata
  local command = io.popen(string.format("rdrview -H -u %s > %s", baseurl, tmpfile), "w")
  if not command then return nil, "cannot load rdrview" end
  command:write(content)
  command:close()
  -- get metadata
  local xcommand = io.popen("rdrview -M > " .. metadatafile, "w")
  xcommand:write(content)
  xcommand:close()
  local metadata = parse_metadatafile(metadatafile)
  os.remove(metadatafile) -- we no longer need this file
  html_skeleton(tmpfile, metadata) -- prepare the file for tidy
  return tmpfile, metadata -- we can use tidy on the tmpfile, so we will keep the content inside
end

local function tidy(tmpfile)
  local status = os.execute("tidy -q -asxml -m " .. tmpfile)
  return status
end



return {
  curl = curl,
  readability = readability,
  tidy = tidy,

}
