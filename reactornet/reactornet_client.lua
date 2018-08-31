local component = require("component")
local serialization = require("serialization")
local fs = require("filesystem")
local net = require("libnet")
local event = require("event")
local gui = require("libcgui")

local settings = {}
local SETTINGS_PATH = "/etc/reactornet_client.cfg"
local updateInterval = 0.1

-----------------------------------------------
-- METHODS --
-----------------------------------------------

local function loadSettings()
    local file, emsg = io.open(SETTINGS_PATH, "rb")
    if not file then
        io.stderr:write("Error: Cannot read settings from path " .. SETTINGS_PATH .. ": " .. emsg)
        settings = {}
        return false
    end
    local sdata = file:read("*a")
    file:close()
    settings = serialization.unserialize(sdata)
    return settings ~= nil
end

local function saveSettings()
    if not fs.exists(SETTINGS_PATH) then
        fs.makeDirectory(fs.path(SETTINGS_PATH))
    end
    local file, emsg = io.open(SETTINGS_PATH, "wb")
    if not file then
        io.stderr:write("Error: Cannot save settings to path " .. SETTINGS_PATH .. ": " .. emsg)
        return
    end
    local sdata = serialization.serialize(settings)
    file:write(sdata)
    file:close()
end

local function launchScreenGUI()
    -- Draw launch gui with Start, Setup and Exit
    local cX = gui.percentX(0.5)
    local cY = gui.percentY(0.5)
    gui.cleanup()
    gui.newButton(cX-8, cY-6, 16, 3, "Start", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, "double", runClient)
    gui.newButton(cX-8, cY-2, 16, 3, "Setup", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, "double", setupClient)
    gui.newButton(cX-8, cY+2, 16, 3, "Exit", 0xCCCCCC, 0xFFFFFF, 0x115599, 0x3399CC, "double", function() os.exit() end)
    gui.renderAll()
end

local function mainScreenGUI()

end

local function setupClient()
    print("SETUP CLIENT")
end

local function runClient()
    print("RUNNING CLIENT")
end

local function closeClient()

end

-----------------------------------------------
-- MAIN LOOP --
-----------------------------------------------

-- if loadSettings() == false then
--     setupClient()
-- end

gui.init()
launchScreenGUI()
while event.pull(0.05, "interrupted") == nil do
    local _, _, x, y = event.pull(updateInterval, "touch")
    if x and y then
        gui.click(x, y)
    end
end