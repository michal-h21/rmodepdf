local domobject = require "luaxml-domobject"

-- download content of URL
local function curl(url)
  local command = io.popen("curl -sS ".. url,"r")
  if not command then return nil, "Cannot execute curl" end
  local content = command:read("*all")
  command:close()
  return content
end

local function get_mimetype(url)
  local command = io.popen("curl -sS -I " .. url,"r")
  local content = command:read("*all")
  command:close()
  status = tonumber(content:match("^%S+%s+(%d+)"))
  mimetype = content:match("content%-type:%s*([%a%/]+)")
  return status, mimetype
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
<meta name="description" content="${Excerpt}" />
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
    return str:gsub("${(.-)}", function(a)
      if metadata[a] then return metadata[a] end
      return ""
    end)

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
  -- os type is provided by LuaTeX. we use it to get correct location of the null file
  local nul = os.type == "windows" and "nul" or "/dev/null"
  -- we want to surppress all warnings from tidy
  local status = os.execute("tidy -q -asxml -m " .. tmpfile .. " 2>" ..nul )
  return status
end


local mime_to_ext = {
  ["image/png"] = "png",
  ["image/jpeg"] = "jpg"
}

local function hash_img_name(imgdir, url, mimetype)
  -- normalize imgdir
  local imgdir = imgdir:match("/$") and imgdir or imgdir .. "/"
  local extension = mime_to_ext[ mimetype ] 
  if not extension then return nil, "Cannot find extension for mimetype: " .. mimetype end
  -- md5 should be enough for this purpose
  local hash = md5.sumhexa(url)
  return imgdir .. hash .. "." .. extension
end

local function download_images(contents, imgdir)
  local dom = domobject.parse(contents)
  local images = dom:query_selector("img")
  -- stop process if the page doesn't contain any images
  if #images == 0 then return contents end
  -- create 
  local status, msg = lfs.mkdir(imgdir)
  for _, img in ipairs(images) do
    local src = img:get_attribute("src")
    local status, mimetype = get_mimetype(src)
    -- process only accessible images
    if status == 200 then
      -- we want to hash image names, in order to save them to the destination directory
      local newname = hash_img_name(imgdir, src, mimetype)
      if newname then
        -- don't save the same image multiple times
        -- test if the file already exists
        local status = io.open(newname, "r")
        if status then
          status:close()
        else
          local f = io.open(newname, "w")
          -- load image from server and save it to a local file
          local content = curl(src)
          if content then f:write(content) end
          f:close()
          print(src, status, mimetype, newname, status)
        end
        img:set_attribute("src", newname)
      end
    end
  end
  return dom:serialize()
end

return {
  curl = curl,
  readability = readability,
  tidy = tidy,
  download_images = download_images,

}
