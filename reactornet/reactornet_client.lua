local component = require("component")
local net = require("libnet")
local event = require("event")
local gui = require("libcgui")
local queue = require("libqueue")

local updateInterval = 0.005
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

local function toggleReactor(reactor_id)

end

local function newReactorButton(x, y, width, height, reactor_id, fgOn, fgOff, bgOn, bgOff, frame)
    local state = {}
    state.reactor_id = reactor_id or ""
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
            gui.drawRect(self.x, self.y, self.width, self.height, self.state.fgOn, self.state.bgOn, self.state.frame)
            gui.drawText(self.x, self.y, self.width, 1, self.state.reactor_id, self.state.fgOn, self.state.bgOn, true)
            gui.drawText(self.x, self.y+1, self.width, 1, tostring(self.state.energyProduced), self.state.fgOn, self.state.bgOn, true)
        else
            gui.drawRect(self.x, self.y, self.width, self.height, self.state.fgOff, self.state.bgOff, self.state.frame)
            gui.drawText(self.x, self.y, self.width, 1, self.state.reactor_id, self.state.fgOff, self.state.bgOff, true)
            gui.drawText(self.x, self.y+1, self.width, 1, "disabled", self.state.fgOff, self.state.bgOff, true)
        end
    end
    local callbackFunc = function(self, x, y)
        toggleReactor(self.state.reactor_id)
        self.state.active = not self.state.active
        self:render()
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
    local mainH = gui.percentY(0.9)
    local botpanelH = gui.height() - mainH
    local monW = gui.percentX(0.7)
    local sidepanelW = gui.width() - monW

    -- FIXME: this is all just template designing stuff
    local powerMax = 100000
    powerQueue:pushright(73500)
    powerQueue:pushright(34600)
    powerQueue:pushright(96500)
    powerQueue:pushright(81200)
    powerQueue:pushright(63000)
    powerQueue:pushright(12300)
    powerQueue:pushright(100000)


    -- Draw power monitor, or a "debug message" if no monitors are available
    if #settings["servers"]["monitor"] > 0 then
        powermonitor_id = gui.newChart(1, 1, monW, mainH, 0x00FF00, 0x000000, powerQueue.values, powerMax, "heavy")
    else
        gui.newContainer(1, 1, monW, mainH, 0xFFFFFF, 0x000000, "heavy")
        gui.newLabel(1, 1, monW, mainH, "No monitors available", 0xFFFFFF, 0x000000, true)
    end

    -- Draw reactor toggles, or a "debug message" if no reactors are available
    gui.newContainer(monW, 1, sidepanelW, mainH, 0xFFFFFF, 0x000000, "heavy")
    if #settings["servers"]["controller"] > 0 then
        local maxReactorCount = math.floor((mainH-2) / 3)
        for i=1, maxReactorCount, 1 do
            local buttonWidth = sidepanelW-2
            local button_y = 2 + (i-1) * 3
            newReactorButton(monW+1, button_y, buttonWidth, 3, "Reactor "..tostring(i), 0xFFFFFF, 0xCCCCCC, 0x22CC55, 0xCC5522, "light")
        end
    end

    -- Draw bottom panel for context buttons
    local botBWidth = gui.width() / 5
    gui.newButton(1, mainH+1, botBWidth, botpanelH, "Monitor", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, contexts.mainScreenGUI)
    gui.newButton(botBWidth*2, mainH+1, botBWidth, botpanelH, "Settings", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, contexts.settingsScreenGUI)
    gui.newButton(botBWidth*4, mainH+1, botBWidth, botpanelH, "Shutdown", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, closeClient)
    gui.renderAll()
end

function contexts.settingsScreenGUI()
    -- Set a network ID for this client
    -- Gather all egilible RNet servers for communication
    -- We need to separate monitors from controllers and toggle GUI features based on them
    gui.clearAll()
    local cX = gui.percentX(0.5)
    local cY = gui.percentY(0.5)
    gui.newLabel(cX-16, cY-9, 32, 1, "ReactorNet Client | Setup", _, _, true)
    gui.newLabel(cX-16, cY-6, 32, 1, "Network ID (1-12 Characters)", _, _, true)
    gui.newInputField(cX-8, cY-5, 16, settings.network_id, 0xFFFFFF, 0xCCCCCC, 0x666666, 0x333333, 12, function(id) settings.network_id = "client_"..id end)

    local mainH = gui.percentY(0.9)
    local botpanelH = gui.height() - mainH
    local botBWidth = gui.width() / 5
    gui.newButton(1, mainH+1, botBWidth, botpanelH, "Monitor", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, contexts.mainScreenGUI)
    gui.newButton(botBWidth*2, mainH+1, botBWidth, botpanelH, "Settings", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, contexts.settingsScreenGUI)
    gui.newButton(botBWidth*4, mainH+1, botBWidth, botpanelH, "Shutdown", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, closeClient)
    gui.renderAll()
end

-- function contexts.launchScreenGUI()
--     local cX = gui.percentX(0.5)
--     local cY = gui.percentY(0.5)
--     gui.clearAll()
--     gui.newLabel(cX-8, cY-9, 16, 3, "ReactorNet Client | Launch", 0xFFFFFF, 0x000000, true)
--     gui.newButton(cX-8, cY-6, 16, 3, "Start", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, contexts.mainScreenGUI)
--     gui.newButton(cX-8, cY-2, 16, 3, "Setup", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, contexts.settingsScreenGUI)
--     gui.newButton(cX-8, cY+2, 16, 3, "Exit", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, closeClient)
--     gui.renderAll()
-- end

-----------------------------------------------
-- MAIN LOOP --
-----------------------------------------------

gui.init(0xFFFFFF, 0x000000, 80, 25)
net.open(1337, "RNet")
contexts.mainScreenGUI()
while event.pull(updateInterval, "interrupted") == nil do
    local _, _, x, y = event.pull(updateInterval, "touch")
    if x and y then
        gui.click(x, y)
    end
end
closeClient()