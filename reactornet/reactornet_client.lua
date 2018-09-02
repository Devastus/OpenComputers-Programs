local component = require("component")
local net = require("libnet")
local event = require("event")
local gui = require("libcgui")
local queue = require("libqueue")

local updateInterval = 0.01
local contexts = {}
local settings = {servers = {controller={}, monitor={}}}
local powerQueue = queue.new(12)
local powermonitor_id = -1

-----------------------------------------------
-- METHODS --
-----------------------------------------------

local function runClient()
    -- Startup the client
    -- Draw a power monitor chart if RNet monitors are accessible
    -- Possibly buttons to activate/deactivate reactors individually if controllers are accessible
    -- If both are accessible, auto-control activation/deactivation of reactors based on total energy in battery
    
    gui.clearAll()
    contexts.mainScreenGUI()
    gui.renderAll()
end

local function closeClient()
    -- Cleanup the program and shutdown
    net.close()
    gui.clearAll()
    os.exit()
end

local function newReactorButton(x, y, width, height, reactor_id, fgOn, fgOff, bgOn, bgOff, frame, callback)
    local state = {}
    state.reactor_id = reactor_id
    state.energyProduced = 0
    state.averageRotorSpeed = 0
    state.active = false
    state.fgOn = fgOn
    state.fgOff = fgOff
    state.bgOn = bgOn
    state.bgOff = bgOff
    state.frame = frame or nil
    local renderFunc = function(self)
        if self.state.active then
            gui.drawRect(self.x, self.y, self.width, self.height, self.fgOn, self.bgOn, frame)
            gui.drawText(self.x, self.y, self.width, 1, self.state.reactor_id, self.fgOn, self.bgOn, true)
            gui.drawText(self.x, self.y+1, self.width, 1, tostring(self.state.energyProduced), self.fgOn, self.bgOn, true)
        else
            gui.drawRect(self.x, self.y, self.width, self.height, self.fgOff, self.bgOff, frame)
            gui.drawText(self.x, self.y, self.width, 1, self.state.reactor_id, self.fgOff, self.bgOff, true)
            gui.drawText(self.x, self.y+1, self.width, 1, "disabled", self.fgOn, self.bgOn, true)
        end
    end
    local callbackFunc = function(self, x, y)
        if callback ~= nil then callback(reactor_id) end
    end
    return gui.newComponent(x, y, width, height, state, renderFunc, callbackFunc)
end

local function onMonitorUpdate()
    local monitor_component = gui.getComponent(powermonitor_id)
    monitor_component.values = powerQueue.values
    gui.render(powermonitor_id)
end

function contexts.mainScreenGUI()
    -- Draw a Power Chart of total energy numbers from monitors
    -- Draw a list of buttons for reactor controllers
    gui.clearAll()
    local monW = gui.percentX(0.7)
    local sidepanelW = gui.width() - monW
    local powerMax = 100000
    powerQueue:pushright(73500)
    powerQueue:pushright(34600)
    powerQueue:pushright(96500)
    powerQueue:pushright(81200)
    powerQueue:pushright(63000)
    powerQueue:pushright(12300)
    powerQueue:pushright(100000)
    -- FIXME: this is all just template designing stuff

    powermonitor_id = gui.newChart(1, 1, monW, gui.height(), 0x00FF00, 0x000000, powerQueue.values, powerMax, "heavy")
    gui.newContainer(monW, 1, sidepanelW, gui.height(), 0xFFFFFF, 0x000000, "heavy")
    for i=1, 3, 1 do
        local width = monW-2
        local y = (i-1) * 3
        newReactorButton(monW+1, y, width, 3, "Reactor "..tostring(i), 0xFFFFFF, 0xCCCCCC, 0x55CC77, 0xCC7755, "light")
    end
    gui.renderAll()
end

function contexts.setupScreenGUI()
    -- Set a network ID for this client
    -- Gather all egilible RNet servers for communication
    -- We need to separate monitors from controllers and toggle GUI features based on them
    gui.clearAll()
    local cX = gui.percentX(0.5)
    local cY = gui.percentY(0.5)
    gui.newLabel(cX-16, cY-9, 32, 1, "ReactorNet Client | Setup", true)
    gui.newLabel(cX-16, cY-6, 32, 1, "Network ID (1-12 Characters)", true)
    gui.newInputField(cX-8, cY-5, 16, settings.network_id, 0xFFFFFF, 0xCCCCCC, 0x666666, 0x333333, 12, function(id) settings.network_id = "client_"..id end)
    gui.newButton(cX-8, cY+9, 16, 3, "Save", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, contexts.launchScreenGUI)
    gui.renderAll()
end

function contexts.launchScreenGUI()
    local cX = gui.percentX(0.5)
    local cY = gui.percentY(0.5)
    gui.clearAll()
    gui.newLabel(cX-8, cY-9, 16, 3, "ReactorNet Client | Launch", true, 0xFFFFFF, 0x000000)
    gui.newButton(cX-8, cY-6, 16, 3, "Start", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, contexts.mainScreenGUI)
    gui.newButton(cX-8, cY-2, 16, 3, "Setup", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, contexts.setupScreenGUI)
    gui.newButton(cX-8, cY+2, 16, 3, "Exit", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, closeClient)
    gui.renderAll()
end

-----------------------------------------------
-- MAIN LOOP --
-----------------------------------------------

gui.init(0xFFFFFF, 0x000000, 80, 25)
net.open(1337, "RNet")
contexts.launchScreenGUI()
while event.pull(updateInterval, "interrupted") == nil do
    local _, _, x, y = event.pull(updateInterval, "touch")
    if x and y then
        gui.click(x, y)
    end
end
closeClient()