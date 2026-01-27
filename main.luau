local task = require("@lune/task")
local process = require("@lune/process")
local utils = require("./utils")
local config = require("./config")

local exthelper = process.create("python3", {("%s/xmlhelper.py"):format(process.cwd)})

while true do
  utils.post.post(config.RSS_FEED_URL, config.EXTHELPER_URL, config.HOMESERVER_URL, config.OAUTH_TOKEN, 430, config.GUID_CACHE_FILE)
  task.wait(21600)
end
