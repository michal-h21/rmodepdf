local domobject = require "luaxml-domobject"
local languages = require "rmodepdf-languages"
local tmpfiles  = require "rmodepdf-tmpfiles"

local function get_mimetype(url)
  local command = io.popen("curl -s -I '" .. url .. "'","r")
  local content = command:read("*all")
  command:close()
  status = tonumber(content:match("^%S+%s+(%d+)"))
  mimetype = content:match("[cC]ontent%-[tT]ype:%s*([%a%/]+)")
  return status, mimetype
end

-- download content of URL
local function curl(url)
  local status, mimetype = get_mimetype(url)
  if status > 400 then return nil, "Cannot open url: " .. url end
  print("jsme tu", status, mimetype)
  local command = io.popen("curl --compressed -A 'Mozilla/5.0 rdrview/0.1' -sS '".. url.. "'","r")
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
<html lang="${language}">
<head>
<title>${Title}</title>
<meta name="author" content="${Byline}" />
<meta name="description" content="${Excerpt}" />
<meta name="url" content="${url}" />
<meta name="site" content="${Site name}" />
</head>
<body>
${content}
</body>
</html>
]]


local html_escapes = {
  [38] = "&amp;",
  [60] = "&lt;",
  [62] = "&gt;",
}
local function escape_html(text)
  local t = {}
  -- process all Unicode characters and find if they should be replaced
  for _, char in utf8.codes(text) do
    -- construct new string with replacements or original char
    t[#t+1] = html_escapes[char] or utf8.char(char)
  end
  return table.concat(t)
end

-- update the cleaned html file with a full HTML template
-- we use this to suppress some tidy errors and to pass 
-- the metadata to the generated page
local function html_skeleton(tmpfile, metadata)
  local function expand(str, tbl)
    -- we don't want to escape HTML tags in content
    -- but we must escape % to avoid issues with Lua patterns
    local content = metadata.content:gsub("%%", "%%%%")
    local str =  str:gsub("${content}", content)
    return str:gsub("${(.-)}", function(a)
      if metadata[a] then return escape_html(metadata[a]) end
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

local function detect_language(str)
  -- detect main document language
  return str:match("<html[^>]+lang=['\"](.-)['\"]") or "en"
end

-- run the readability command to remove clutter from the HTML page
local function readability(content, baseurl)
  local tmpfile = tmpfiles.tmpname() -- the clean up html content will be saved here
  local metadatafile = tmpfiles.tmpname() -- we can get also some metadata
  local command = io.popen(string.format("rdrview -H -u %s > %s", baseurl, tmpfile), "w")
  if not command then return nil, "cannot load rdrview" end
  command:write(content)
  command:close()
  -- get metadata
  local xcommand = io.popen("rdrview -M > " .. metadatafile, "w")
  xcommand:write(content)
  xcommand:close()
  local metadata = parse_metadatafile(metadatafile)
  metadata.url = baseurl
  metadata.language = languages.get_babel_name(detect_language(content))
  os.remove(metadatafile) -- we no longer need this file
  html_skeleton(tmpfile, metadata) -- prepare the file for tidy
  return tmpfile, metadata -- we can use tidy on the tmpfile, so we will keep the content inside
end

-- in the future, we should convert HTML to XML ourselves, because tidy removes spaces when we want them
local function tidy(tmpfile)
  -- os type is provided by LuaTeX. we use it to get correct location of the null file
  local nul = os.type == "windows" and "nul" or "/dev/null"
  -- we want to surppress all warnings from tidy
  local status = os.execute("tidy -q -asxml -m --tidy-mark no --wrap-attributes no" .. tmpfile .. " 2>" ..nul )
  return status
end


local mime_to_ext = {
  ["image/png"] = {ext = "png"},
  ["image/jpeg"] = {ext = "jpg"},
  ["image/svg+xml"] = {ext = "pdf", convert = config.img_convert.svg},
  ["image/gif"] = {ext = "png", convert = config.img_convert.gif},
  ["image/webp"] = {ext = "png", convert = config.img_convert.webp},
}

local function hash_img_name(imgdir, url, mimetype)
  -- normalize imgdir
  print("imgdir: " .. imgdir .. ";")
  if imgdir == '""' or imgdir == "" then 
    imgdir = "" 
  else
    imgdir = imgdir:match("/$") and imgdir or imgdir .. "/"
  end
  local extension = mime_to_ext[ mimetype ] 
  if not extension then return nil, "Cannot find extension for mimetype: " .. mimetype end
  -- md5 should be enough for this purpose
  local hash = md5.sumhexa(url)
  local imgname =  imgdir .. hash .. "." .. extension.ext
  if imgdir == "" and not config.args.print then
    -- if user didn't specify the img dir, we will remove all images
    tmpfiles.register_tmpname(imgname)
  end
  print("new image name: " .. imgname)
  return imgname
end

local function download_images(dom, imgdir)
  local images = dom:query_selector("img")
  -- stop process if the page doesn't contain any images
  if #images == 0 then return dom end
  -- create directory for images
  if imgdir and imgdir ~= "" then
    local status, msg = lfs.mkdir(imgdir)
  end
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
          local content = curl(src)
          local command = mime_to_ext[mimetype].convert
          if content then 
            -- test if we need to convert the source image (for example WEBP, SVG or GIF) to a format supported by LuaTeX
            if command then
              command = command:gsub("%${dest}", newname)
              local exec = io.popen(command, "w")
              exec:write(content)
              exec:close()
            -- else load image from server and save it to a local file
            else
              local f = io.open(newname, "w")
              f:write(content) 
              f:close()
            end
          end
        end
        img:set_attribute("src", newname)
      else
        -- remove unsupported images
        img:remove_node()
      end
    else
      -- remove images that cannot be downloaded
      print("% Cannot download image: " .. src)
      img:remove_node()
    end
  end
  -- remove generator meta
  for _, meta in ipairs(dom:query_selector("meta")) do
    local name = meta:get_attribute("name") 
    local charset = meta:get_attribute("charset")
    if (name  and name == "generator") or charset then meta:remove_node() end
  end

  return dom
end

local function clean_title(title)
  if not title then return nil, "no title given" end
  title = title:gsub("[%.%,%?%!%:]", ""):gsub("%s+", "_")
  return title
end


local function set_page_dimensions(dom, format, pagestyle)
  -- save information for the geometry package and \pageformat as attributes for the <html> element,
  -- so the tranform library can use them in the template for the page
  local html = dom:query_selector("html")[1]
  if not html then return nil, "cannot find the html element" end
  html:set_attribute("pagestyle", pagestyle)
  -- now get information for the specified page format from the configuration
  -- each format should have corresponding table in the form of {paperwidth=...,paperheight=...,margin=...}
  local pageformat = config.page_formats[format]
  if pageformat then
    -- construct keyval argument for the geometry package
    local s = {} 
    for k,v in pairs(pageformat) do
      s[#s+1] =  k .. "=" .. v
    end
    html:set_attribute("geometry", table.concat(s, ","))
  else 
    html:set_attribute("geometry", "")
  end

end

return {
  curl = curl,
  readability = readability,
  tidy = tidy,
  download_images = download_images,
  clean_title = clean_title,
  set_page_dimensions=set_page_dimensions,
}
