local component = require("component")
local serialization = require("serialization")
local event = require("event")
local termUI = require("libtermui")
local lmath = require("libmath")
local net = require("libnet")
local fs = require("filesystem")

local __SERVER_TYPES = {"controller", "monitor"}
local __COMPONENT_TYPES = {
    [__SERVER_TYPES[1]] = {"br_reactor", "br_turbine"},
    [__SERVER_TYPES[2]] = {"induction_matrix"},
}
local __TARGET_ROTOR_SPEED = {
    900, 1800
}

local SETTINGS_PATH = "/etc/reactornet_server.cfg"
local settings = {headless=false, targetRotorSpeed=1800, steamPerTurbine=2000}
local reactorInfo = {}
local turbinesInfo = {}
local monitorInfo = {}
local JtoRFmult = 0.4
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
    local sdata = serialization.serialize(settings)
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
        local type = component[2]
        if settings.components[type] == nil then
            settings.components[type] = {}
        end
        table.insert(settings.components[type], address)
    else
        io.stderr:write("reactornet_server: Component does not exist!")
    end
end

local function setTurbines(functionName, args)
    -- print(arg)
    -- for a in arg do print(a) end
    for i,v in ipairs(settings.components["br_turbine"]) do
        component.invoke(v, functionName, table.unpack(args))
    end
end

--Displays long numbers with commas
function fancyNumber(n)
    return tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):gsub("%D$",""):reverse()
end

local function setupServer()
    --Select server type
    settings = {headless=false, targetRotorSpeed=1800, steamPerTurbine=2000}
    termUI.clear()
    termUI.write(1, 1, "ReactorNet Server | Setup - Server Type")
    termUI.write(1, 2, "Select Server type: \n")
    settings.server_type = __SERVER_TYPES[termUI.selectOptions(2, 3,__SERVER_TYPES)]
    
    -- Hook up all components loop
    settings.components = {}
    local componentList = listAvailableComponents()
    if not componentList or #componentList == 0 then
        termUI.clear()
        termUI.write(1, 1, "ReactorNet Server | Setup - Available Components")
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
    termUI.write(1, 1, "ReactorNet Server | Setup - Available Components")
    termUI.write(1, 2, "Select components to connect to:")
    termUI.selectToggles(2, 3, componentLabels, selected)
    for i=1, #selected, 1 do
        if selected[i] == true then
            connectComponent(componentList[i])
        end
    end

    -- Write a network ID
    termUI.clear()
    termUI.write(1, 1, "ReactorNet Server | Setup - Network ID")
    local validID = false
    local id_postfix = ""
    while validID == false do
        termUI.write(1, 2, "Give a network ID (1-12 characters):\n")
        id_postfix = termUI.read(1, 3, false)
        if #id_postfix > 0 and #id_postfix <= 12 then 
            validID = true
        else
            termUI.write(1, 2, "Error: Invalid ID", "error")
            os.sleep(2)
        end
    end
    settings.network_id = "RNet_" .. settings.server_type .. "_" .. id_postfix

    -- Set Turbine settings if this is a controller
    if settings.server_type == "controller" then
        termUI.clear()
        termUI.write(1, 1, "ReactorNet Server | Setup - Turbine Rotor Speed")
        termUI.write(1, 2, "Select target Turbine Rotor Speed (900/1800 RPM):")
        settings.targetRotorSpeed = __TARGET_ROTOR_SPEED[termUI.selectOptions(2, 3,__TARGET_ROTOR_SPEED)]

        termUI.clear()
        termUI.write(1, 1, "ReactorNet Server | Setup - Steam per Turbine")
        termUI.write(1, 2, "Specify target Steam per Turbine (0-2000 mb/t):\n")
        local steamValue = termUI.read(1, 3, false)
        settings.steamPerTurbine = lmath.clamp(tonumber(steamValue), 0, 2000)
        setTurbines("setFluidFlowRateMax", {settings.steamPerTurbine})
    end

    termUI.clear()
    termUI.write(1, 1, "ReactorNet Server | Setup - Verbosity")
    termUI.write(1, 2, "Select server verbosity mode:\n")
    local modenum = termUI.selectOptions(2, 3, {"normal", "headless"})
    settings.headless = modenum == 2

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
        turbinesInfo.averageRotorSpeed = 0
        turbinesInfo.totalEnergyProduced = 0
        turbinesInfo.turbineCount = #settings.components["br_turbine"]
        for i = 1, turbinesInfo.turbineCount, 1 do
            local turbineProxy = component.proxy(settings.components["br_turbine"][i])
            if turbinesInfo[i] == nil then
                turbinesInfo[i] = {}
            end
            turbinesInfo[i].active = turbineProxy.getActive()
            turbinesInfo[i].energyStored = turbineProxy.getEnergyStored()
            turbinesInfo[i].rotorSpeed = turbineProxy.getRotorSpeed()
            turbinesInfo[i].inputAmount = turbineProxy.getInputAmount()
            turbinesInfo[i].outputAmount = turbineProxy.getOutputAmount()
            turbinesInfo[i].fluidAmountMax = turbineProxy.getFluidAmountMax()
            turbinesInfo[i].fluidFlowRate = turbineProxy.getFluidFlowRate()
            turbinesInfo[i].fluidFlowRateMax = turbineProxy.getFluidFlowRateMax()
            turbinesInfo[i].fluidFlowRateMaxMax = turbineProxy.getFluidFlowRateMaxMax()
            turbinesInfo[i].energyProduced = turbineProxy.getEnergyProducedLastTick()
            turbinesInfo[i].inductorEngaged = turbineProxy.getInductorEngaged()
            turbinesInfo.averageRotorSpeed = turbinesInfo.averageRotorSpeed + turbinesInfo[i].rotorSpeed
            turbinesInfo.totalEnergyProduced = turbinesInfo.totalEnergyProduced + turbinesInfo[i].energyProduced
        end
        turbinesInfo.averageRotorSpeed = turbinesInfo.averageRotorSpeed / turbinesInfo.turbineCount

        -- Reactor active (turbines) autocontrol
        local diff = settings.targetRotorSpeed - turbinesInfo.averageRotorSpeed
        if math.abs(diff) > 50 then
            local sign = 10 * lmath.sign(diff)
            reactorInfo.controlRodLevel = lmath.clamp(reactorInfo.controlRodLevel - sign, 0, 100)
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

-- Update the total energy amount in the network
local function updateMonitor()
    monitorInfo.totalEnergy = 0
    monitorInfo.totalEnergyMax = 0
    monitorInfo.input = 0
    monitorInfo.output = 0

    -- Mekanism Induction Matrix
    for i = 1, #settings.components["induction_matrix"], 1 do
        local proxy = component.proxy(settings.components["induction_matrix"][i])
        monitorInfo.totalEnergy = math.floor(monitorInfo.totalEnergy + (proxy.getEnergy() * JtoRFmult))
        monitorInfo.totalEnergyMax = math.floor(monitorInfo.totalEnergyMax + (proxy.getMaxEnergy() * JtoRFmult))
        monitorInfo.input = math.floor(monitorInfo.input + (proxy.getInput() * JtoRFmult))
        monitorInfo.output = math.floor(monitorInfo.output + (proxy.getOutput() * JtoRFmult))
    end
end

local function setActive(active)
    local proxy = component.proxy(settings.components["br_reactor"][1])
    reactorInfo.controlRodLevel = 0
    proxy.setAllControlRodLevels(reactorInfo.controlRodLevel)
    proxy.setActive(active)
    for i,v in ipairs(settings.components["br_turbine"]) do
        proxy = component.proxy(v)
        proxy.setActive(active)
    end
end

local function closeServer()
    event.cancel(updateTimerID)
    termUI.clear()
    termUI.write(1,1, "ReactorNet Server | Closing...")
    os.sleep(1)
    os.exit()
end

local function runServer()
    termUI.clear()
    if settings.server_type == "controller" then
        setActive(true)
        updateControl()
        updateTimerID = event.timer(2, updateControl, math.huge)
        while event.pull(2, "interrupted") == nil do
            --do reactor controlling stuff
            if not settings.headless then
                termUI.write(1,1, settings.network_id.." | Running...")
                termUI.write(1,2,"Reactor Steam: "..tostring(reactorInfo.hotFluidProduced))
                termUI.write(1,3,"Reactor Fuel: "..tostring(reactorInfo.fuelAmount).."/"..tostring(reactorInfo.fuelAmountMax))
                termUI.write(1,4,"Reactor Control Rods: "..tostring(reactorInfo.controlRodLevel))
                if reactorInfo.isActivelyCooled then
                    termUI.write(1,5,"Turbines: "..tostring(turbinesInfo.turbineCount))
                    termUI.write(1,6,"Turbine Rotor Speed: "..tostring(math.floor(turbinesInfo.averageRotorSpeed)).."/"..tostring(settings.targetRotorSpeed))
                    termUI.write(1,7,"Turbine RF/tick: "..tostring(lmath.round(turbinesInfo.totalEnergyProduced, 2)))
                end
            end
        end
        setActive(false)
    else
        updateMonitor()
        updateTimerID = event.timer(2, updateMonitor, math.huge)
        while event.pull(2, "interrupted") == nil do
            -- do monitoring stuff
            if not settings.headless then
                termUI.write(1,1, settings.network_id.." | Running...")
                termUI.write(1,2, "Total RF: "..tostring(monitorInfo.totalEnergy).."/"..tostring(monitorInfo.totalEnergyMax))
                termUI.write(1,3, "RF/t Input: "..tostring(monitorInfo.input))
                termUI.write(1,4, "RF/t Output: "..tostring(monitorInfo.output))
            end
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
    termUI.write(1, 2, settings.network_id)
    local option = termUI.selectOptions(2, 3, {"Start", "Setup", "Exit"})
    if option == 1 then 
        return runServer()
    elseif option == 2 then 
        setupServer()
    else 
        os.exit()
    end
end
