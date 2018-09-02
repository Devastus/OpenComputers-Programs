local component = require("component")
local net = require("libnet")
local event = require("event")
local gui = require("libcgui")

local updateInterval = 0.01
local contexts = {}
local settings = {servers = {controller={}, monitor={}}}

-----------------------------------------------
-- METHODS --
-----------------------------------------------

local function runClient()
    -- Startup the client
    -- Draw a power monitor chart if RNet monitors are accessible
    -- Possibly buttons to activate/deactivate reactors individually if controllers are accessible
    -- If both are accessible, auto-control activation/deactivation of reactors based on total energy in battery
    
    gui.clearAll()

    gui.renderAll()
end

local function closeClient()
    -- Cleanup the program and shutdown
    net.close()
    gui.clearAll()
    os.exit()
end

function contexts.mainScreenGUI()
    -- Draw a Power Chart of total energy numbers from monitors
    -- Draw a list of buttons for reactor controllers
    gui.clearAll()
    local monW = gui.percentX(0.7)
    local sidepanelW = gui.width() - monW
    gui.drawRect(1, 1, monW, gui.height(), 0xFFFFFF, 0x000000, "heavy")
    gui.drawRect(monW, 1, sidepanelW, gui.height(), 0xFFFFFF, 0x000000, "heavy")
    gui.newLabel(1,1,monW,1,"Monitor",0xFFFFFF,0x000000,true)
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
    gui.newButton(cX-8, cY-6, 16, 3, "Start", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, runClient)
    gui.newButton(cX-8, cY-2, 16, 3, "Setup", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, contexts.setupScreenGUI)
    gui.newButton(cX-8, cY+2, 16, 3, "Exit", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, nil, closeClient)
    gui.renderAll()
end

-----------------------------------------------
-- MAIN LOOP --
-----------------------------------------------

gui.init()
net.open(1337, "RNet")
contexts.launchScreenGUI()
while event.pull(updateInterval, "interrupted") == nil do
    local _, _, x, y = event.pull(updateInterval, "touch")
    if x and y then
        gui.click(x, y)
    end
end