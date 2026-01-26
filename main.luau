local net = require("@lune/net")
local serde = require("@lune/serde")
local masto = require("./utils/masto")
local rss = require("./utils/rss")
local config = require("./config")

local function fetchRSS()
	local ws = net.socket(config.EXTHELPER_URL)

	local req = net.request(config.RSS_FEED_URL)
	if not req.ok then
		ws:close()
		return nil, "RSS request failed"
	end

	ws:send(req.body)
	local msg = ws:next()

	ws:close()
	return msg
end

local function getpostable(json: string)
  local postables = rss.parse_rss_to_portable(json)
  return postables or nil
end

local function cleanText(text)
  if not text then return "" end
  text = text:gsub("\nThe post * appeared first on PRWC | Philippine Revolution Web Central.", "")
  text = text:gsub("The post * appeared first on PRWC | Philippine Revolution Web Central.", "")
  return text
end

local function post()
  local json = fetchRSS()
  if not json then return end
  local posts = getpostable(serde.decode("json", json))
  local post = posts[1]
  local mastocharmax = 400

  local text
  local content = cleanText(post.content)
  local description = cleanText(post.description)
  local link = post.link
  local maxchar = (mastocharmax - #link + 1)

  if #content > mastocharmax then
    text = description
  else
    text = content
  end
  if #text > maxchar then
    text = text:sub(1, maxchar) .. "..."
  end
  if link ~= "" then
    text = text .. "\n" .. link
  end

  local formatedcontent = ("%s\n%s\n\n%s"):format(post.title, post.pubDate, text)
  print(formatedcontent)

  masto.post(config.HOMESERVER_URL, config.OAUTH_TOKEN, {
    status = formatedcontent
  })
end

post()
