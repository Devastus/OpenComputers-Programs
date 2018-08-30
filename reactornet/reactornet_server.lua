local component = require("component")
local event = require("event")
local termUI = require("libtermui")
local fs = require("filesystem")

local __SERVER_TYPES = {"controller", "monitor"}
local __COMPONENT_TYPES = {
    [__SERVER_TYPES[1]] = {"br_reactor", "br_turbine"},
    [__SERVER_TYPES[2]] = {},
}
local __TARGET_ROTOR_SPEED = {
    900, 1800
}

local SETTINGS_PATH = "/etc/reactornet_server.cfg"
local settings = {headless=false, targetRotorSpeed=1800, steamPerTurbine=2000}
local reactorInfo = {}
local turbinesInfo = {}
local updateTimerID = 0

-----------------------------------------------
-- METHODS --
-----------------------------------------------

local function loadSettings()
    local file, emsg = io.open(SETTINGS_PATH, "rb")
    if not file then
        io.stderr:write("Error: Cannot read settings from path " .. SETTINGS_PATH .. ": " .. emsg)
        settings = {headless=false, targetRotorSpeed=1800, steamPerTurbine=2000}
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
    local sdata = serialization.serialize(data)
    file:write(sdata)
    file:close()
end

local function listAvailableComponents()
    local componentList = {}
    local i = 0
    for f = 1, #__COMPONENT_TYPES[settings.server_type], 1 do
        for address,type in component.list(__COMPONENT_TYPES[settings.server_type][f]) do
            i = i + 1
            componentList[i] = {address, type}
        end
    end
    return componentList
end

local function connectComponent(component)
    if settings.components == nil then
        settings.components = {}
    end
    if component ~= nil then
        local address = component[1]
        local type = component[2]
        print(type)
        if settings.components[type] == nil then
            settings.components[type] = {}
        end
        table.insert(settings.components[type], address)
    else
        io.stderr:write("reactornet_server: Component does not exist!")
    end
end

local function setTurbines(functionName, ...)
    for i,v in ipairs(settings.components["br_turbine"]) do
        component.invoke(v, functionName, unpack(arg))
    end
end

local function setupServer()
    --Select server type
    termUI.clear()
    termUI.write(1, 1, "ReactorNet Server | Setup - Server Type (1/6)")
    termUI.write(1, 2, "Select Server type: \n")
    settings.server_type = __SERVER_TYPES[termUI.selectOptions(2, 3,__SERVER_TYPES)]
    
    -- Hook up all components loop
    settings.components = {}
    local componentList = listAvailableComponents()
    if not componentList or #componentList == 0 then
        termUI.clear()
        termUI.write(1, 1, "ReactorNet Server | Setup - Available Components (2/6)")
        termUI.write(1, 2, "Error: no available components found! Aborting...", "error")
        os.exit()
    end
    local selected = {}
    local componentLabels = {}
    for i = 1, #componentList, 1 do
         selected[i] = false 
         componentLabels[i] = componentList[i][2].."("..string.sub(componentList[i][1],1,8).."...)"
    end
    termUI.clear()
    termUI.write(1, 1, "ReactorNet Server | Setup - Available Components (2/6)")
    termUI.write(1, 2, "Select components to connect to:")
    termUI.selectToggles(2, 3, componentLabels, selected)
    for i=1, #selected, 1 do
        if selected[i] == true then
            connectComponent(componentList[i])
        end
    end

    -- Write a network ID
    termUI.clear()
    termUI.write(1, 1, "ReactorNet Server | Setup - Network ID (3/6)")
    local validID = false
    local id_postfix = ""
    while validID == false do
        termUI.write(1, 2, "Give a network ID (1-12 characters):\n")
        id_postfix = io.read("*line")
        if #id_postfix > 0 and #id_postfix <= 12 then 
            validID = true
        else
            termUI.write(1, 2, "Error: Invalid ID", "error")
            os.sleep(2)
        end
    end
    settings.network_id = "ReactorNet_" .. __SERVER_TYPES[settings.server_type] .. "_" .. id_postfix

    termUI.clear()
    termUI.write(1, 1, "ReactorNet Server | Setup - Turbine Rotor Speed (4/6)")
    termUI.write(1, 2, "Select target Turbine Rotor Speed (900/1800 RPM):")
    settings.targetRotorSpeed = __TARGET_ROTOR_SPEED[termUI.selectOptions(2, 3,__TARGET_ROTOR_SPEED)]

    termUI.clear()
    termUI.write(1, 1, "ReactorNet Server | Setup - Steam per Turbine (5/6)")
    termUI.write(1, 2, "Specify target Steam per Turbine (0-2000 mb/t):\n")
    local steamValue = io.read("*line")
    settings.steamPerTurbine = clamp(tonumber(steamValue), 0, 2000)
    setTurbines("setFluidFlowRateMax", settings.steamPerTurbine)

    saveSettings()
end

local function updateControl()
    -- Get the first one, as there shouldn't really be any other reactors connected
    local reactorProxy = component.proxy(settings.components["br_reactor"][1])
    reactorInfo.active = reactorProxy.getActive()
    reactorInfo.isActivelyCooled = reactorProxy.isActivelyCooled()
    reactorInfo.energyStoredMax = 10000000
    reactorInfo.energyStored = reactorProxy.getEnergyStored()
    reactorInfo.energyProduced = reactorProxy.getEnergyProducedLastTick()
    reactorInfo.fuelConsumed = reactorProxy.getFuelConsumedLastTick()
    reactorInfo.fuelAmountMax = reactorProxy.getFuelAmountMax()
    reactorInfo.fuelAmount = reactorProxy.getFuelAmount()
    reactorInfo.wasteAmount = reactorProxy.getWasteAmount()
    reactorInfo.reactivity = reactorProxy.getFuelReactivity()
    reactorInfo.temperature = reactorProxy.getFuelTemperature()
    reactorInfo.casingTemperature = reactorProxy.getCasingTemperature()
    reactorInfo.hotFluidProduced = reactorProxy.getHotFluidProducedLastTick()
    reactorInfo.hotFluidAmount = reactorProxy.getHotFluidAmount()
    reactorInfo.hotFluidAmountMax = reactorProxy.getHotFluidAmountMax()
    reactorInfo.coolantAmount = reactorProxy.getCoolantAmount()
    reactorInfo.coolantAmountMax = reactorProxy.getCoolantAmountMax()

    if reactorInfo.isActivelyCooled then
        turbineInfo.averageRotorSpeed = 0
        turbineInfo.turbineCount = #settings.components["br_turbine"]
        for i,v in ipairs(settings.components["br_turbine"]) do
            local turbineProxy = component.proxy(v)
            turbineInfo[i].active = turbineProxy.getActive()
            turbineInfo[i].energyStored = turbineProxy.getEnergyStored()
            turbineInfo[i].rotorSpeed = turbineProxy.getRotorSpeed()
            turbineInfo[i].inputAmount = turbineProxy.getInputAmount()
            turbineInfo[i].outputAmount = turbineProxy.getOutputAmount()
            turbineInfo[i].fluidAmountMax = turbineProxy.getFluidAmountMax()
            turbineInfo[i].fluidFlowRate = turbineProxy.getFluidFlowRate()
            turbineInfo[i].fluidFlowRateMax = turbineProxy.getFluidFlowRateMax()
            turbineInfo[i].fluidFlowRateMaxMax = turbineProxy.getFluidFlowRateMaxMax()
            turbineInfo[i].energyProduced = turbineProxy.getEnergyProducedLastTick()
            turbineInfo[i].inductorEngaged = turbineProxy.getInductorEngaged()
            turbineInfo.averageRotorSpeed = turbineInfo.averageRotorSpeed + turbineInfo[i].rotorSpeed
            turbineInfo.totalEnergyProduced = turbineInfo.totalEnergyProduced + turbineInfo[i].energyProduced
        end
        turbineInfo.averageRotorSpeed = turbineInfo.averageRotorSpeed / turbineInfo.turbineCount

        -- Reactor active (turbines) autocontrol
        -- Every turbine connected should be getting a maximum of 2000mb/t steam
        local totalSteamPerTurbine = turbineInfo.turbineCount * settings.steamPerTurbine
        local steamDifference = totalSteamPerTurbine - reactorInfo.hotFluidProduced
        if steamDifference < 0 then
            reactorInfo.controlRodLevel = math.min(reactorInfo.controlRodLevel + 1, 100)
            reactorProxy.setAllControlRodLevels(reactorInfo.controlRodLevel)
        elseif steamDifference > 100 then
            reactorInfo.controlRodLevel = math.max(reactorInfo.controlRodLevel - 1, 0)
            reactorProxy.setAllControlRodLevels(reactorInfo.controlRodLevel)
        end
    else
        -- Reactor passive autocontrol
        local energyPerc = reactorInfo.energyStored / reactorInfo.energyStoredMax
        local threshold = math.min(math.max(energyPerc - 0.5, 0.0001) / (0.9 - 0.5), 1)
        reactorInfo.controlRodLevel = math.floor(100 * threshold)
        reactorProxy.setAllControlRodLevels(reactorInfo.controlRodLevel)
    end
end

local function setActive(active)
    local proxy = component.proxy(settings.components["br_reactor"][1])
    proxy.setActive(active)
    for i,v in ipairs(settings.components["br_turbine"]) do
        proxy = component.proxy(v)
        proxy.setActive(active)
    end
end

local function closeServer()
    setActive(false)
    event.cancel(updateTimerID)
    os.exit()
end

local function runServer()
    termUI.clear()
    setActive(true)
    updateTimerID = event.timer(2, updateControl, math.huge)
    while event.pull(2, "interrupted") == nil do
        --do server stuff
        if not settings.headless then
            termUI.write(1,1,"ReactorNet Server | Running...")
            termUI.write(1,2,"Reactor Steam: "..reactorInfo.hotFluidProduced)
            termUI.write(1,3,"Reactor Fuel: "..reactorInfo.fuelAmount.."/"..reactorInfo.fuelAmountMax)
            termUI.write(1,4,"Reactor Control Rods: "..reactorInfo.controlRodLevel)
            termUI.write(1,5,"Turbines: "..turbineInfo.turbineCount)
            termUI.write(1,6,"Turbine Rotor Speed: "..turbineInfo.averageRotorSpeed.."/"..settings.targetRotorSpeed)
            termUI.write(1,7,"Turbine RF/tick: "..turbineInfo.totalEnergyProduced)
        end
    end
    closeServer()
end

-----------------------------------------------
-- MAIN LOOP --
-----------------------------------------------

if loadSettings() == false then
    -- We need a terminal to setup the server
    if termUI.isAvailable() == false then
        io.stderr:write("Error: terminal required to setup the ReactorNet server")
        os.exit()
    end
    setupServer()
else
    -- If we have an existing settings file and no terminal, run headless
    if termUI.isAvailable() == false then
        return runServer()
    end
end 

-- Present the launch screen
while event.pull(0.05, "interrupted") == nil do
    termUI.clear()
    termUI.write(1, 1, "ReactorNet Server | Launch \n")
    local option = termUI.selectOptions(2, 3, {"Start", "Setup", "Exit"})
    if option == 1 then 
        return runServer()
    elseif option == 2 then 
        setupServer()
    else 
        os.exit()
    end
end
