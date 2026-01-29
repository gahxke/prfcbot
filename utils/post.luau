local net = require("@lune/net")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local rss = require("./rss")
local masto = require("./masto")

local function read_guid_cache(file: string): {[string]: boolean}
  if not fs.isFile(file) then
    fs.writeFile(file, "{}")
  end

  local raw = fs.readFile(file)
  if not raw or raw == "" then
    return {}
  end

  local ok, decoded = pcall(function()
    return serde.decode("json", raw)
  end)

  if not ok or type(decoded) ~= "table" then
    warn("GUID cache corrupted, resetting")
    fs.writeFile(file, "{}")
    return {}
  end

  return decoded
end

local function write_guid_cache(cache: {[string]: boolean}, file: string)
  fs.writeFile(file, serde.encode("json", cache))
end

local function add_guid(cache: {[string]: boolean}, guid: string, file: string)
  cache[guid] = true
  write_guid_cache(cache, file)
end


local function fetchrss(rss_feed_url: string, helper_url: string)
	local ws = net.socket(helper_url)
  print(("Fetching feed from %s."):format(rss_feed_url))
	local req = net.request(rss_feed_url)
	if not req.ok then
		ws:close()
		error("Fetch failed!")
    return nil, "RSS request failed"
	end

	ws:send(req.body)
	local msg = ws:next()

	ws:close()
	return msg
end

local function is_today(pubDate: string): boolean
  if not pubDate or pubDate == "" then
    return false
  end

  local month, day, year =
    pubDate:match("(%a+)%s+(%d+),%s*(%d+)")

  if not month then
    return false
  end

  local months = {
    January = 1, February = 2, March = 3, April = 4,
    May = 5, June = 6, July = 7, August = 8,
    September = 9, October = 10, November = 11, December = 12
  }

  local post_time = os.time({
    year = tonumber(year),
    month = months[month],
    day = tonumber(day),
    hour = 0,
    min = 0,
    sec = 0,
  })

  local now = os.date("*t")
  local today_time = os.time({
    year = now.year,
    month = now.month,
    day = now.day,
    hour = 0,
    min = 0,
    sec = 0,
  })

  return post_time == today_time
end

local function date_to_time(pubDate: string): number
  local month, day, year =
    pubDate:match("(%a+)%s+(%d+),%s*(%d+)")

  local months = {
    January = 1, February = 2, March = 3, April = 4,
    May = 5, June = 6, July = 7, August = 8,
    September = 9, October = 10, November = 11, December = 12
  }

  return os.time({
    year = tonumber(year),
    month = months[month],
    day = tonumber(day),
    hour = 0,
  })
end

local function getpostable(json: string)
  local postables = rss.parse_rss_to_portable(json)
  return postables or nil
end

local function cleantext(text)
  if not text then return "" end
  text = text:gsub("\nThe post.-appeared first on PRWC | Philippine Revolution Web Central%.?","")
  return text
end

local function post(rss_feed_url, helper_url, homeserver_url, oauth, maxchars, guid_cache)
  local json = fetchrss(rss_feed_url, helper_url)
  if not json then return end

  local posts = getpostable(serde.decode("json", json))
  local guid_cache_tbl = read_guid_cache(guid_cache)
  local mastocharmax = maxchars or 400

  -- post oldest → newest
  table.sort(posts, function(a, b)
    return date_to_time(a.pubDate) < date_to_time(b.pubDate)
  end)

  for _, post in ipairs(posts) do
    if post.guid ~= "" and not guid_cache_tbl[post.guid] and is_today(post.pubDate) then
      local content = cleantext(post.content)
      local description = cleantext(post.description)
      local link = post.link

      local text = (#content > mastocharmax) and description or content
      local maxchar = mastocharmax - #link - 1

      if #text > maxchar then
        text = text:sub(1, maxchar) .. "..."
      end

      if link ~= "" then
        text ..= "\n" .. link
      end
      local formatted = ("%s\n%s\n\n%s"):format(
        post.title,
        post.pubDate,
        text
      )
      print(("Post %s fetched, posting..."):format(post.title))
      local postreq = masto.post(homeserver_url, oauth, { status = formatted })
      if not postreq then return end
      print(("Posted %s! | %s | %s characters"):format(post.title, postreq.url, tostring(#formatted)))
      add_guid(guid_cache_tbl, post.guid, guid_cache)
    end
  end
end

return {
  post = post
}
