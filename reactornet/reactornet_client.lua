local component = require("component")
local net = require("libnet")
local event = require("event")
local gui = require("libcgui")

local updateInterval = 0.05
local servers = {controller={}, monitor={}}

-----------------------------------------------
-- METHODS --
-----------------------------------------------

local function launchScreenGUI()
    local cX = gui.percentX(0.5)
    local cY = gui.percentY(0.5)
    gui.clearAll()
    gui.newLabel(cX-8, cY-9, 16, 3, "ReactorNet Client | Launch", true)
    gui.newButton(cX-8, cY-6, 16, 3, "Start", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, "double", runClient)
    gui.newButton(cX-8, cY-2, 16, 3, "Setup", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, "double", setupClient)
    gui.newButton(cX-8, cY+2, 16, 3, "Exit", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, "double", closeClient)
    gui.renderAll()
end

local function mainScreenGUI()
    -- Draw a Power Chart of total energy numbers from monitors
    -- Draw a list of buttons for reactor controllers
    gui.clearAll()

    gui.renderAll()
end

local function setupClient()
    -- Set a network ID for this client
    -- Gather all egilible RNet servers for communication
    -- We need to separate monitors from controllers and toggle GUI features based on them
    gui.clearAll()
    local cX = gui.percentX(0.5)
    local cY = gui.percentY(0.5)
    gui.newLabel(cX-16, cY-2, 32, 1, "ReactorNet Client | Setup", true)
    gui.newLabel(cX-16, cY, 32, 1, "Network ID", true)
    local networkID_inputfield = gui.newInputField(cX-16, cY+1, 32, 0xFFFFFF, 0xCCCCCC, 0x444444, 0x222222, 16)
    gui.renderAll()
end

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

-----------------------------------------------
-- MAIN LOOP --
-----------------------------------------------

gui.init()
net.open(1337, "RNet")
launchScreenGUI()
while event.pull(0.05, "interrupted") == nil do
    local _, _, x, y = event.pull(updateInterval, "touch")
    if x and y then
        gui.click(x, y)
    end
end