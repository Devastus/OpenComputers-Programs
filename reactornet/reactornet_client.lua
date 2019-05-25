local component = require("component")
local net = require("libnet")
local event = require("event")
local gui = require("libcgui")
local tbl = require("libtbl")
local queue = require("libqueue")

local updateInterval = 0.01
local contexts = {}
local settings = {servers = {controller = {}, monitor = {}}}
local powerQueue = queue.new(12)

local powermonitor_id = -1
local reactorToggleIds = {}
local serverList_id = -1
local settingsDebug_id = -1

local centerX, centerY = 0
local serverList = {}
local updateRequestEventID = -1
local monitorUpdateEventID = -1

-----------------------------------------------
-- METHODS --
-----------------------------------------------

local function runClient()
    -- Startup the client
    -- Draw a power monitor chart if RNet monitors are accessible
    -- Possibly buttons to activate/deactivate reactors individually if controllers are accessible
    -- If both are accessible, auto-control activation/deactivation of reactors based on total energy in battery
    
    net.open(1337)
    net.connectEvent("fetch", onFetchServers)
    gui.init(0xFFFFFF, 0x000000, 80, 25)
    centerX = gui.percentX(0.5)
    centerY = gui.percentY(0.5)
    gui.clearAll()
    contexts.mainScreenGUI()
    gui.renderAll()
end

local function closeClient()
    -- Cleanup the program and shutdown
    net.close()
    event.cancel(updateRequestEventID)
    event.cancel(monitorUpdateEventID)
    gui.clearAll()
    os.exit()
end

local function toggleReactor(reactor_id)

end

local function newReactorButton(x, y, width, height, reactor_id, fgOn, fgOff, bgOn, bgOff, frame, parent)
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
    return gui.Component.new(x, y, width, height, state, renderFunc, callbackFunc, true, parent)
end

local function saveSelectedServers()
    for serv in serverList do
        if serv.selected == true then
            settings.servers[serv.server_type][serv.address] = {network_id = serv.network_id}
        end
    end
end

----------------------------------------------------
--- EVENTS ---
----------------------------------------------------

local function onPowerMonitorUpdate()
    local totalValue = 0
    local totalMax = 0
    for mon in settings.servers.monitor do
        totalValue = totalValue + mon.totalEnergy
        totalMax = totalMax + mon.totalEnergyMax
    end
    powerQueue.pushright(totalValue)
    gui.getComponent(powermonitor_id):setState({values = powerQueue.values, maxValue = totalMax})
end

local function onUpdateRequest()
    for address,_ in pairs(settings.servers.monitor) do
        net.send(address, settings.network_id, "update")
    end
    for address,_ in pairs(settings.servers.controller) do
        net.send(address, settings.network_id, "update")
    end
end

local function onUpdateReply(remoteAddress, data)
    if data.server_type ~= nil then
        for k,v in pairs(data) do
            settings.servers[data.server_type][remoteAddress][k] = v
        end
        if data.server_type == "controller" then
            for i,v in ipairs(serverList) do
                if serverList[i].address == remoteAddress then
                    gui.getComponent(reactorToggleIds[i]):setState({active=data.active})
                end
            end
        end
    end
    -- gui.renderAll()
end

local function onFetchServers(remoteAddress, data)
    --DEBUG
    gui.getComponent(settingsDebug_id):setState({text = "Response from "..remoteAddress})
    table.insert(serverList, {id = data.network_id, server_type=data.server_type, address = remoteAddress, selected = false})
    local i = #serverList
    local serverListComp = gui.getComponent(serverList_id)
    local y = #serverListComp.children
    local reactorToggle_id = gui.newToggle(1, 1+y, serverListComp.width, 1, serverList[i].id, 0xFFFFFF, 0x000000, 0x000000, 0xFFFFFF, nil, function() serverList[i].selected = not serverList[i].selected end, serverList_id)
    table.insert(reactorToggleIds, reactorToggle_id)
    -- gui.render(serverList_id, true)
    -- gui.renderAll()
end

----------------------------------------------------
--- CONTEXTS ---
----------------------------------------------------

function contexts.bottomPanel()
    local mainH = gui.percentY(0.9)
    local botpanelH = gui.height() - mainH
    local botBWidth = gui.width() / 4
    gui.newLabel(1, mainH+1, botBWidth, botpanelH, "|ReactorNet|", 0xFFFFFF, 0x113366, true)
    gui.newButton(botBWidth, mainH+1, botBWidth, botpanelH, "Monitor", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, contexts.mainScreenGUI)
    gui.newButton(botBWidth*2, mainH+1, botBWidth, botpanelH, "Settings", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, contexts.settingsScreenGUI)
    gui.newButton(botBWidth*3, mainH+1, botBWidth, botpanelH, "Shutdown", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, closeClient)
end

function contexts.mainScreenGUI()
    -- Draw a Power Chart of total energy numbers from monitors
    -- Draw a list of toggles for reactor controllers
    -- net.disconnectEvent("fetch")
    net.connectEvent("update", onUpdateReply)
    updateRequestEventID = event.timer(2, onUpdateRequest, math.huge)
    monitorUpdateEventID = event.timer(5, onPowerMonitorUpdate, math.huge)
    gui.clearAll()
    local mainH = gui.percentY(0.9)
    local botpanelH = gui.height() - mainH
    local monW = gui.percentX(0.7)
    local sidepanelW = gui.width() - monW

    -- Draw power monitor, or a "debug message" if no monitors are available
    if #settings.servers.monitor > 0 then
        powermonitor_id = gui.newChart(1, 1, monW, mainH, 0x00FF00, 0x000000, powerQueue.values, powerMax, "heavy")
    else
        gui.newContainer(1, 1, monW, mainH, 0xFFFFFF, 0x000000, "heavy")
        gui.newLabel(1, 1, monW, mainH, "No monitors available", 0xFFFFFF, 0x000000, true)
    end

    -- Draw reactor toggles, or a "debug message" if no reactors are available
    local reactorContainer_id = gui.newContainer(monW, 1, sidepanelW, mainH, 0xFFFFFF, 0x000000, "heavy")
    if #settings.servers.controller > 0 then
        local maxReactorCount = math.floor((mainH-2) / 3)
        for i=1, maxReactorCount, 1 do
            local buttonWidth = sidepanelW-2
            local button_y = 2 + (i-1) * 3
            newReactorButton(monW+1, button_y, buttonWidth, 3, "Reactor "..tostring(i), 0xFFFFFF, 0xCCCCCC, 0x22CC55, 0xCC5522, "light", reactorContainer_id)
        end
    end

    contexts.bottomPanel()
    gui.renderAll()
end

function contexts.settingsScreenGUI()
    -- Set a network ID for this client
    -- Gather all egilible RNet servers for communication
    net.disconnectEvent("update")
    
    event.cancel(updateRequestEventID)
    event.cancel(monitorUpdateEventID)
    gui.clearAll()
    gui.newLabel(centerX-16, 1, 32, 1, "ReactorNet Client | Setup", _, _, true)
    settingsDebug_id = gui.newLabel(centerX-16, 2, 32, 1, "No response", 0xFFFFFF, 0x000000, true) 
    gui.newLabel(centerX-16, 3, 32, 1, "Network ID (1-12 Characters)", _, _, true)
    gui.newInputField(centerX-8, 4, 16, settings.network_id, 0xFFFFFF, 0xCCCCCC, 0x666666, 0x333333, 12, function(id) settings.network_id = "client_"..id end)

    gui.newLabel(centerX-16, 6, 32, 1, "Available servers:", _, _, true)
    local containerH = centerY
    serverList_id = gui.newContainer(centerX-16, 7, 32, containerH, 0xFFFFFF, 0x000000, "heavy")
    gui.newButton(centerX-8, containerH+7, 16, 1, "Save Selections", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, saveSelectedServers)

    contexts.bottomPanel()
    gui.renderAll()
    net.broadcast(settings.network_id, "fetch")
end

-----------------------------------------------
-- MAIN LOOP --
-----------------------------------------------

net.open(1337)
net.connectEvent("fetch", onFetchServers)
gui.init(0xFFFFFF, 0x000000, 80, 25)
centerX = gui.percentX(0.5)
centerY = gui.percentY(0.5)
contexts.mainScreenGUI()
while event.pull(updateInterval, "interrupted") == nil do
    gui.update(updateInterval)
end
closeClient()