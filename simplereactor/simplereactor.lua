local component = require("component")

if not component.isAvailable("br_reactor") then
    io.stderr:write("No connected Reactor Computer Port found.", "This program requires a connected Reactor Computer Port to run.")
    os.exit()
end

--API = require("buttonAPI")
local event = require("event")
local keyboard = require("keyboard")
local term = require("term")
local gpu = component.gpu
local reactor = component.br_reactor
local computer = component.computer
local w, h = gpu.maxResolution()
local hw = math.floor(w * 0.5)
local hh = math.floor(h * 0.5)
local buttons = {}

local colors = {black = 0x000000, white = 0xFFFFFF, red = 0xCC2440, green = 0x33DB40, blue = 0x3366FF, gray = 0x333333}

local maxEnergy = 10000000
local maxTemperature = 2000
local updateInterval = 2
local controlRodMinValue = 0.5
local silent = not term.isAvailable()

local reactorState = "0ffline"
local autoControl = true
local maxFuelAmount = 0
local turnOnValue = 0.1
local turnOffValue = 0.9

local curEnergyStored = 0
local curEnergyPercent = 0
local curEnergyProduction = 0
local curFuelAmount = 0
local curFuelPercent = 0
local curTemperature = 0
local curTemperaturePercent = 0
local curFuelConsumption = 0.0
local curReactivity = 0
local curControlRodLevel = 0

local lastEnergyStored = 0
local deltaEnergy = 0

gpu.setResolution(w, h)
gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
gpu.fill(1, 1, w, h, " ")

function handleReactor()
    --Get Reactor info
    local active = reactor.getActive()
    local maxFuel = reactor.getFuelAmountMax()
    if active then
        reactorState = "Online"
    else
        reactorState = "Offline"
    end
    curEnergyStored = reactor.getEnergyStored()
    curEnergyPercent = curEnergyStored/maxEnergy
    curEnergyProduction = reactor.getEnergyProducedLastTick()
    curFuelAmount = reactor.getFuelAmount()
    curFuelPercent = curFuelAmount / maxFuel
    curFuelConsumption = round(reactor.getFuelConsumedLastTick(),3)
    curReactivity = math.floor(reactor.getFuelReactivity())
    curTemperature = math.floor(reactor.getFuelTemperature())
    curTemperaturePercent = math.min(curTemperature / maxTemperature, 1)
    deltaEnergy = math.floor((curEnergyStored - lastEnergyStored) / updateInterval)

    --Auto-control
    if autoControl then
        --Control Rods
        if active then
            local threshold = math.min(math.max(curEnergyPercent - controlRodMinValue, 0.0001) / (turnOffValue - controlRodMinValue),1)
            curControlRodLevel = math.floor(90 * threshold)
            reactor.setAllControlRodLevels(curControlRodLevel)
        end
        --Reactor state
        if curEnergyPercent <= turnOnValue and not active then
            reactor.setActive(true)
        elseif curEnergyPercent >= turnOffValue and active then
            reactor.setActive(false);
        end
    end

    --Draw the GUI
    if not silent then
        drawGUI()
    end

    lastEnergyStored = curEnergyStored
end

function drawGUI()
    gpu.fill(1,1,w,h," ")
    local title = "Reactor Control 0.0.1"
    drawTextArea(1, 1, w, 1, true, title, nil)

    --BARS
    drawBar(2,3,w-3,2,curEnergyPercent, colors.gray, colors.green)
    if autoControl then drawAutoControlBlips(2, w-3) end
    drawTextArea(2,5,w-3,1,true,"Currently stored: "..fancyNumber(curEnergyStored), "RF")

    drawBar(2,6,w-3,2,curTemperaturePercent, colors.gray, colors.red)
    drawTextArea(2,8,w-3,1,true,"Temperature: "..curTemperature, "°C")

    drawBar(2,9,w-3,2,curFuelPercent, colors.gray, colors.green)
    drawTextArea(2,11,w-3,1,true,"Fuel: "..fancyNumber(curFuelAmount), "mB")

    --INFO AREA
    drawTextArea(2,hh+1,hw-3,1,false,"Delta: "..deltaEnergy, "RF/sec")
    drawTextArea(2,hh+2,hw-3,1,false,"Producing: "..fancyNumber(curEnergyProduction), "RF/tick")
    drawTextArea(2,hh+3,hw-3,1,false,"Consuming: "..curFuelConsumption, "mB/tick")
    drawTextArea(2,hh+4,hw-3,1,false,"Reactivity: "..curReactivity, "%")
    drawTextArea(2,hh+5,hw-3,1,false,"Control Rods: "..curControlRodLevel, "%")

    --CONTROLS
    drawButton(1, reactor.getActive())
    drawButton(2, autoControl)
    drawButton(3, autoControl)
    drawButton(4, autoControl)
    drawButton(5, autoControl)
    drawButton(6, autoControl)
end

function drawTextArea(x,y,width,height,centered,msg,unit)
    local txt = msg
    if unit ~= nil then
        txt = txt.." "..unit
    end
    if centered then
        local halfLen = math.floor(string.len(txt) * 0.5)
        local halfW = math.floor(width * 0.5)
        local halfH = math.floor(height * 0.5)
        gpu.set(x + halfW - halfLen, y + halfH, txt)
    else
        gpu.set(x,y,txt)
    end
end

function drawBar(x,y,w,h,percent, bgColor, fillColor)
    local iw = math.floor(w * percent)
    local bg = gpu.getBackground()
    gpu.setBackground(fillColor)
    gpu.fill(x,y,iw,h," ")
    gpu.setBackground(bgColor)
    gpu.fill(x+iw,y,w-iw,h," ")
    gpu.setBackground(bg)
end

function drawAutoControlBlips(x, barWidth)
    local oldColor = gpu.getBackground()
    gpu.setBackground(colors.blue)
    gpu.set(x + math.floor(turnOffValue * barWidth), 4, " ")
    gpu.setBackground(colors.red)
    gpu.set(x + math.floor(turnOnValue * barWidth), 4, " ")
    gpu.setBackground(oldColor)
end

function drawButton(ID, active)
    buttons[ID]["active"] = active
    local oldColor = gpu.getBackground()
    local drawColor = oldColor
    if active then
        drawColor = buttons[ID]["onColor"]
    else
        drawColor = buttons[ID]["offColor"]
    end
    local x = buttons[ID]["x"]
    local y = buttons[ID]["y"]
    local width = buttons[ID]["width"]
    local height = buttons[ID]["height"]
    gpu.setBackground(drawColor,false)
    gpu.fill(x,y,width,height," ")
    gpu.set((x+width/2)-string.len(buttons[ID]["label"])/2,y+height/2,buttons[ID]["label"])
    gpu.setBackground(oldColor)
end

function processClick(x, y)
    for ID, data in pairs(buttons) do
        local xmax = data["x"]+data["width"]-1
        local ymax = data["y"]+data["height"]-1
        if x >= data["x"] and x <= xmax then
            if y >= data["y"] and y <= ymax then
                buttons[ID]["func"](buttons[ID]["params"])
                computer.beep(400, 0.1)
            end
        end
    end
end

function setup()
    local hhw = hw/2
    newButton(1, "Online", hw+1, hh+1, hw-1, 3, colors.blue, colors.gray, toggleActive, nil, true)
    newButton(2, "Auto-Control", hw+1, hh+5, hw-1, 3, colors.blue, colors.gray, toggleAutoControl, nil, true)
    newButton(3, "Min+", hw+1, hh+9, hhw-1, 1, colors.blue, colors.gray, increaseMinEnergyLimit, 0.05, true)
    newButton(4, "Max+", hw+hhw+1, hh+9, hhw-1, 1, colors.blue, colors.gray, increaseMaxEnergyLimit, 0.05, true)
    newButton(5, "Min-", hw+1, hh+11, hhw-1, 1, colors.blue, colors.gray, decreaseMinEnergyLimit, 0.05, true)
    newButton(6, "Max-", hw+hhw+1, hh+11, hhw-1, 1, colors.blue, colors.gray, decreaseMaxEnergyLimit, 0.05, true)
end

--Displays long numbers with commas
function fancyNumber(n)
    return tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):gsub("%D$",""):reverse()
end

function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

function clamp(value, min, max)
    return math.max(math.min(value, max), min)
end

function newButton(ID, label, x, y, width, height, onColor, offColor, func, params, active)
    local table = {}
    table["label"] = label
    table["x"] = x
    table["y"] = y
    table["width"] = width
    table["height"] = height
    table["onColor"] = onColor
    table["offColor"] = offColor
    table["func"] = func
    table["params"] = params
    table["active"] = active
    buttons[ID] = table
end

function toggleActive()
    local active = reactor.getActive()
    reactor.setActive(not active)
    drawGUI()
end

function toggleAutoControl()
    autoControl = not autoControl
    if autoControl == false then reactor.setAllControlRodLevels(0) end
    drawGUI()
end

function increaseMinEnergyLimit(value)
    turnOnValue = turnOnValue + value
    if turnOnValue > turnOffValue then turnOnValue = turnOffValue-0.1 end
end

function decreaseMinEnergyLimit(value)
    turnOnValue = turnOnValue - value
    if turnOnValue < 0 then turnOnValue = 0 end
end

function increaseMaxEnergyLimit(value)
    turnOffValue = turnOffValue + value
    if turnOffValue > 1 then turnOffValue = 1 end
end

function decreaseMaxEnergyLimit(value)
    turnOffValue = turnOffValue - value
    if turnOffValue < turnOnValue then turnOffValue = turnOnValue+0.1 end
end


--MAIN
setup()

while event.pull(0.05, "interrupted") == nil do
    handleReactor()
    if keyboard.isKeyDown(keyboard.keys.w) and keyboard.isControlDown() then
        reactor.setActive(false)
        if not silent then
            gpu.fill(1, 1, w, h, " ")
        end
        os.exit()
    end
    local _, _, x, y = event.pull(updateInterval, "touch")
    if x and y then
        processClick(x,y)
    end
    --os.sleep(2)
end