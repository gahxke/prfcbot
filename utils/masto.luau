local serde = require("@lune/serde")
local net = require("@lune/net")

type mastoPostData = {
  status: string,
  visibility: string?,
  spoiler_text: string?,
  in_reply_to_id: string?,
  sensitive: boolean?,
}

type mastoStatus = {
    id: string;
    url: string?;
    content: string;
    visibility: string;
    sensitive: boolean;
    spoiler_text: string;
}

local masto = {}

function masto.post(url: string, oauth: string, body: mastoPostData): mastoStatus?
  local req = net.request({
    url = ("%s/api/v1/statuses"):format(url),
    method = "POST",
    headers = {
        ["Authorization"] = ("Bearer %s"):format(oauth),
        ["Content-Type"] = "application/json",
    },
    body = serde.encode("json", body)
  })
  if req.ok then 
    local data = serde.decode("json", req.body)
    return data :: mastoStatus
  elseif not req.ok then
    warn(req.statusCode, req.statusMessage, req.body)
  end
  return nil
end

return masto
