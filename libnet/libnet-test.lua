local component = require("component")
local event = require("event")
local net = require("libnet")
local termui = require("libtermui")

local TYPE = {"server", "client"}
local settings = {}
local replies = 0

local function onRequest(remoteAddress, data)
    termui.clearLine(2)
    termui.set(1,2,"Request: "..tostring(data))
    local upper = string.upper(tostring(data))
    replies = replies + 1
    net.send(remoteAddress, {message=upper, numberOfReplies=replies}, "reply")
end

local function onReply(remoteAddress, data)
    termui.clearLine(2)
    termui.set(1,2,"Reply: "..tostring(data))
end

-- Select program mode
local w, h = termui.resolution()
termui.clear()
termui.write(1, 1, "LibNet Test")
termui.write(1, 2, "Select mode:")
settings.type = TYPE[termui.selectOptions(2,3,TYPE)]

net.open(3000)
if settings.type == "server" then
    net.connectEvent("request", onRequest)
else
    net.connectEvent("reply", onReply)
end

termui.clear()
termui.write(1, 1, "LibNet Test: "..settings.type)
while event.pull(0.01, "interrupted") == nil do
    if settings.type == "client" then
        local message = termui.read(1,h,false)
        if message ~= "" then
            net.broadcast(message, "request")
            termui.clearLine(h)
        end
    end
end
net.close()
os.exit()