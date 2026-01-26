local function trim(s: string): string
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function html_to_text(html: string): string
	if not html then
		return ""
	end

	html = html:gsub("<script.-</script>", "")
	html = html:gsub("<style.-</style>", "")

	html = html:gsub("<%s*[bB][rR]%s*/?>", "\n")
	html = html:gsub("</p>", "\n\n")

	html = html:gsub("<[^>]+>", "")

	html = html
		:gsub("&nbsp;", " ")
		:gsub("&amp;", "&")
		:gsub("&lt;", "<")
		:gsub("&gt;", ">")
		:gsub("&#(%d+);", function(n)
			return utf8.char(tonumber(n))
		end)

	html = html:gsub("\r", "")
	html = html:gsub("\n%s+\n", "\n\n")

	return trim(html)
end

local function format_pubdate(date_str: string): string
	local _, _, d, mon, y = date_str:find("%a+, (%d+) (%a+) (%d+)")

	local months = {
		Jan = "January",
		Feb = "February",
		Mar = "March",
		Apr = "April",
		May = "May",
		Jun = "June",
		Jul = "July",
		Aug = "August",
		Sep = "September",
		Oct = "October",
		Nov = "November",
		Dec = "December",
	}

	if d and mon and y then
		return string.format(
			"%s %d, %s",
			months[mon] or mon,
			tonumber(d),
			y
		)
	end

	-- fallback if parsing fails
	return date_str
end

function parse_rss_to_portable(data)
  if not data or not data.rss or not data.rss.channel then
    return {}
  end

  local items = data.rss.channel.item
  if not items then
    return {}
  end

  -- Normalize: make sure it's always a list
  if type(items) ~= "table" or items[1] == nil then
    items = { items }
  end

  local posts = {}
  for _, item in ipairs(items) do
    table.insert(posts, {
      title = item.title or "",
      link = item.link or "",
      author = item["dc:creator"] or "",
      pubDate = format_pubdate(item.pubDate) or "",
      description = html_to_text(item.description) or "",
      content = html_to_text(item["content:encoded"]) or "",
      categories = item.category or {},
      guid = item.guid and item.guid["#text"] or "",
    })
  end

  return posts
end

return {
	parse_rss_to_portable = parse_rss_to_portable
}

