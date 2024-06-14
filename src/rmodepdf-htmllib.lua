local domobject = require "luaxml-domobject"
local languages = require "rmodepdf-languages"
local encodings = require "luaxml-encodings"
local tmpfiles  = require "rmodepdf-tmpfiles"
local log = logging.new "htmllib"

local function array_to_hash(t) 
  local n = {}
  for k,v in ipairs(t) do n[v] = true end
  return n
end

local allowed_url_prefixes = array_to_hash(config.allowed_url_prefixes)

local function file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

local function is_url(url)
  local prefix = url:match("^([^%:]+):")
  if not prefix then return false end
  return allowed_url_prefixes[prefix]
end

local function load_file(url)
  local f = io.open(url, "r")
  if not f then
    log:error("Cannot open file: " .. url)
    return nil, "Cannot open file: " .. url
  end
  log:debug("Loading file: " .. url)
  local content = f:read("*all")
  f:close()
  return content
end

local mime_to_ext = config.mime_to_ext

-- mimetypes of local images
local local_mimetypes = {
 png  = "image/png",
 jpg  = "image/jpeg",
 jpeg  = "image/jpeg",
 svg  = "image/svg+xml",
 gif  = "image/gif",
 webp  = "image/webp",
}

local function local_mimetype(url)
  -- try to emulate status and mimetype for local files
  if not file_exists(url) then
    return 404, "File not exists: " .. url 
  end
  local status = 200
  local extension = url:match("%.(%w+)")
  if not extension then return 404, "Cannot find mimetype for extension: " .. extension end
  local mimetype = local_mimetypes[string.lower(extension)]
  if not mimetype then status = 404; mimetype = "Cannot find mimetype for extension: " .. extension end 
  return status, mimetype
end

local function get_mimetype(url)
  if not is_url(url) then return local_mimetype(url) end
  local command = io.popen("curl -s -I '" .. url .. "'","r")
  local content = command:read("*all")
  command:close()
  status = tonumber(content:match("^%S+%s+(%d+)"))
  mimetype = content:match("[cC]ontent%-[tT]ype:%s*([%a%/]+)")
  return status, mimetype
end

-- download content of URL
local function curl(url)
  if not is_url(url) then return load_file(url) end
  local status, mimetype = get_mimetype(url)
  if status > 400 then return nil, "Cannot open url: " .. url end
  log:debug("curl", url, status, mimetype)
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
  metadata.content = load_file(tmpfile) -- make content available in the metadata
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

--- run the readability command to remove clutter from the HTML page
---@param content string HTML document
---@param baseurl string URL of the document
---@return string new content
---@return table metadata
local function readability(content, baseurl)
  local tmpfile = tmpfiles.tmpname() -- the clean up html content will be saved here
  local metadatafile = tmpfiles.tmpname() -- we can get also some metadata
  local command = io.popen(string.format("rdrview -E utf-8 -P -H -u %s > %s", baseurl, tmpfile), "w")
  if not command then return nil, "cannot load rdrview" end
  command:write(content)
  command:close()
  -- get metadata
  local xcommand = io.popen("rdrview -E utf-8 -M > " .. metadatafile, "w")
  xcommand:write(content)
  xcommand:close()
  local metadata = parse_metadatafile(metadatafile)
  metadata.url = baseurl
  metadata.language = languages.get_babel_name(detect_language(content))
  os.remove(metadatafile) -- we no longer need this file
  html_skeleton(tmpfile, metadata) -- prepare the file for tidy
  -- return HTML string modified by rdrview
  local f = io.open(tmpfile, "r")
  if f then
    local newcontent = f:read("*all")
    f:close()
    return newcontent, metadata
  end
  return content, metadata -- we can use tidy on the tmpfile, so we will keep the content inside
end

local function get_metadata(dom, baseurl)
  local metadata = {}
  metadata.url = baseurl
  metadata.author = ""
  metadata.Byline = ""
  metadata["Site name"] = ""

  dom:traverse_elements(function(el)
    local name = string.lower(el:get_element_name())
    if name == "title" then 
      metadata.Title = el:get_text()
    elseif name == "meta" then
      local property = el:get_attribute("property")
      local prop_name = el:get_attribute("name")
      local content = el:get_attribute("content")
      if property == "og:title" then
        metadata.Title = content
      elseif property == "og:description" then
      elseif prop_name == "author" then
        metadata.Byline = content
      elseif property == "og:site_name" then
        metadata["Site name"] = content
      end
    end
    if not metadata.language and el:get_attribute("lang") then
      metadata.language = languages.get_babel_name(el:get_attribute("lang"))
      el:set_attribute("lang", metadata.language)
    end
  end)

  return metadata
end

local function to_utf8(content)
  local enc = encodings.find_html_encoding(content)
  if enc then
    local mapping = encodings.load_mapping(enc)
    if mapping then
      content = encodings.recode(content, mapping)
    end
  end
  return content
end

-- in the future, we should convert HTML to XML ourselves, because tidy removes spaces when we want them
local function tidy(tmpfile)
  -- os type is provided by LuaTeX. we use it to get correct location of the null file
  local nul = os.type == "windows" and "nul" or "/dev/null"
  -- we want to surppress all warnings from tidy
  local status = os.execute("tidy -q -asxml -m --tidy-mark no --wrap-attributes no" .. tmpfile .. " 2>" ..nul )
  return status
end



local function hash_img_name(imgdir, url, mimetype)
  -- normalize imgdir
  log:debug("imgdir: " .. imgdir .. ";")
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
  log:debug("new image name: " .. imgname)
  return imgname
end

local function get_bouding_box(imgname)
  local function calculate(lower, higher)
    return tonumber(higher) - tonumber(lower)
  end
  local ebb, msg = io.popen("ebb -x -O " .. imgname, "r")
  if not ebb then return nil, msg end
  local result = ebb:read("*all")
  ebb:close()
  local x, y, w, h = result:match("%%BoundingBox: (%d+) (%d+) (%d+) (%d+)")
  if not x then return nil, "Cannot read image dimensions: " .. imgname end 
  return calculate(x, w), calculate(y,h)
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
    log:debug("image mimetype", status, mimetype)
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
        -- I am not using this, because LuaTeX reads image dimensions directly, and I've even found a way how
        -- to set the max-width, to prevent image width larger than the \textwidth
        -- local width, height = get_bouding_box(newname)
        -- if not width then
        --   -- height contains error message
        --   log:error(height)
        -- else
        --   if not img:get_attribute("width") then img:set_attribute("width", width) end
        --   if not img:get_attribute("height") then img:set_attribute("height", height) end
        -- end
      else
        -- remove unsupported images
        img:remove_node()
      end
    else
      -- remove images that cannot be downloaded
      log:warning("% Cannot download image: " .. src)
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
  title = title:gsub("[%.%,%?%!%:%/%~]", ""):gsub("%s+", "_")
  return title
end

--- get string with page dimensions suitable for the Geometry package
--- @param format string 
local function get_geometry(format)
  local pageformat = config.page_formats[format]
  if pageformat then
    -- construct keyval argument for the geometry package
    local s = {}
    for k,v in pairs(pageformat) do
      if type(k) == "number" then
        s[#s+1] = v
      else
        s[#s+1] =  k .. "=" .. v
      end
    end
    return table.concat(s, ",")
  end
end


local function set_page_dimensions(dom, format, pagestyle)
  -- save information for the geometry package and \pageformat as attributes for the <html> element,
  -- so the tranform library can use them in the template for the page
  local html = dom:query_selector("html")[1]
  if not html then return nil, "cannot find the html element" end
  html:set_attribute("pagestyle", pagestyle)
  -- now get information for the specified page format from the configuration
  -- each format should have corresponding table in the form of {paperwidth=...,paperheight=...,margin=...}
  local geometry = get_geometry(format)
  if geometry then
    html:set_attribute("geometry", geometry)
  else
    html:set_attribute("geometry", "")
  end
  return html:get_attribute("geometry"), pagestyle

end

return {
  load_file = load_file,
  curl = curl,
  readability = readability,
  tidy = tidy,
  download_images = download_images,
  clean_title = clean_title,
  get_geometry = get_geometry,
  set_page_dimensions=set_page_dimensions,
  file_exists = file_exists,
  get_metadata = get_metadata,
  to_utf8 = to_utf8,
}
