local component = require("component")
local serialization = require("serialization")
local fs = require("filesystem")
local net = require("libnet")
local event = require("event")

local settings = {}
local SETTINGS_PATH = "/etc/reactornet_client.cfg"

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

local function setupClient()

end

local function gatherAllServers()

end

local function runClient()

end

local function closeClient()

end

-----------------------------------------------
-- MAIN LOOP --
-----------------------------------------------

if loadSettings() == false then
    setupClient()
end

while event.pull(0.05, "interrupted") == nil do
    -- Draw launch gui with Start, Setup and Exit
end