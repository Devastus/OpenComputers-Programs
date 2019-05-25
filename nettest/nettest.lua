local component = require("component")
local event = require("event")
local net = require("libnet")
local gui = require("libcgui")

local centerX, centerY = 0
local container_id = -1
local input_id = -1
local messageComps = {}
local name = ""
local message = ""

local function context()
    gui.newLabel(1, 1, gui.width(), 1, "Nettest", _, _, true)
    gui.newLabel(centerX-16, 3, 32, 1, "Name (1-12 Characters)", _, _, true)
    gui.newInputField(centerX-8, 4, 16, 1, name, 0xFFFFFF, 0xCCCCCC, 0x666666, 0x333333, 12, function(id) name = id end)
    container_id = gui.newContainer(2, 5, gui.width()-2, 10, _, _, "heavy")
    input_id = gui.newInputField(centerX-8, gui.height()-3, 16, 1, message, 0xFFFFFF, 0xCCCCCC, 0x666666, 0x333333, 16, function(msg) message = msg end)
    gui.newButton(centerX-8, gui.height()-2, 16, 1, "Send", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, sendMessage)
end

local function renderMessage(remoteAddress, name, message)
    if messageComps[remoteAddress] == nil then
        local len = #messageComps
        local parent = gui.getComponent(container_id)
        messageComps[remoteAddress] = {
            id = gui.newLabel(1, 1+len, parent.width, 1, name..": "..message, _, _)
        }
        parent:render(true)
    else
        local comp = gui.getComponent(messageComps[remoteAddress].id)
        comp:setState({text=name..": "..message})
        comp:render()
    end
end

local function sendMessage()
    net.broadcast(message, {name=name, message=message})
    gui.getComponent(input_id):setState({text=""})
end

local function onMessage(remoteAddress, data)
    renderMessage(remoteAddress, data.name, data.message)
    net.send(remoteAddress, {name=name, message="Message succesfully received"}, "reply")
end

local function onReply(remoteAddress, data)
    renderMessage(remoteAddress, data.name, data.message)
end

net.open(1337)
net.connectEvent("msg", onMessage)
net.connectEvent("reply", onReply)

gui.init(0xFFFFFF, 0x000000, 80, 25)
centerX = gui.percentX(0.5)
centerY = gui.percentY(0.5)

context()
while event.pull(0.01, "interrupted") == nil do
    gui.update(0.01)
end
net.close()
gui.clearAll()