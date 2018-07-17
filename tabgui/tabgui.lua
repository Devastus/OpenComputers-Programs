local component = require("component")
local colors = require("colors")

local API = {}
local appBar = {}
local tabs = {}
local elements = {}
local currentTab = 1

local gpu = component.gpu
local w,h = 0,0
local fgColor = 0xFFFFFF
local bgColor = 0x000000
local exitButtonWidth = 3
local tabWidth = 0

function API.clearScreen()
    gpu.setForeground(fgColor)
    gpu.setBackground(bgColor)
    gpu.fill(1,1,w,h," ")
end

function API.clearTab()
    API.clearScreen()
    elements = {}
end

function API.clearAll()
    API.clearScreen()
    tabs = {}
    elements = {}
    currentTab = 1
end

function API.setColors(fore, back)
    API.fgColor = fore
    API.bgColor = back
    API.clearScreen()
end

function API.width() return w end
function API.height() return h end
function API.getRelativeX(percent) return math.floor(w * percent) end
function API.getRelativeY(percent) return math.floor(h * percent) end
function API.clamp(n,min,max) return math.min(math.max(n, min), max) end

-------------------------------------------------------------------------
--                  BASE METHODS
-------------------------------------------------------------------------

function API.init(appName, bgColor, fgColor, appBarStyle)
    appBar = {}
    w, h = gpu.getResolution()
    API.setColors(fgColor, bgColor)
    appBar["name"] = appName
    appBar["bgColor"] = appBarStyle["bgColor"]
    appBar["fgColor"] = appBarStyle["fgColor"]
    appBar["tabBarColor"] = appBarStyle["tabBarColor"]
    appBar["tabOffBGColor"] = appBarStyle["tabOffBGColor"]
    appBar["tabOnBGColor"] = appBarStyle["tabOnBGColor"]
    appBar["tabOffFGColor"] = appBarStyle["tabOffFGColor"]
    appBar["tabOnFGColor"] = appBarStyle["tabOnFGColor"]
    appBar["tabOffStyle"] = appBarStyle["tabOffStyle"]
    appBar["tabOnStyle"] = appBarStyle["tabOnStyle"]
    API.clearAll()
end

function API.newTab(name, createContextFunc)
    local tab = tab or {}
    tab.name = name
    tab.createContext = createContextFunc
    local ID = #tabs+1
    tabs[ID] = tab
    tabWidth = w / ID
end

function API.newElement(x, y, width, height, elementParams, elementDrawFunc, elementCallbackFunc)
    local element = {}
    element.ID = #elements+1
    element.x = x
    element.y = y
    element.width = width
    element.height = height
    element.params = elementParams
    element.draw = elementDrawFunc
    element.callback = function(element, touchX, touchY) 
        if elementCallbackFunc ~= nil then elementCallbackFunc(element, touchX, touchY) end
        return element.ID
    end
    elements[element.ID] = element
    return element.ID
end

function API.showTab(index)
    if index > 0 and index <= #tabs then
        currentTab = index
        API.clearTab()
        if tabs[index].createContext ~= nil then tabs[index].createContext() end
        API.drawCurrentTab()
    end
end

function API.queryClick(x,y)
    if y <= 2 then
        if y == 2 and tabWidth > 0 then
            local tabIndex = math.floor(x / tabWidth + 1)
            API.showTab(tabIndex)
        elseif y == 1 and x >= (w - (exitButtonWidth-1)) then
            API.clearAll()
            os.exit()
        end
        return nil
    else
        for ID = 1, #elements do
            local element = elements[ID]
            local xmax = element.x+element.width-1
            local ymax = element.y+element.height-1
            if x >= element.x and x <= xmax then
                if y >= element.y and y <= ymax  then
                    if element.callback ~= nil then return element.callback(element, x, y) end
                    return ID
                end
            end
        end
        return nil
    end
end

function API.getElement(elementID)
    local element = elements[elementID]
    if element ~= nil then return element end
end

function API.redrawElement(elementID)
    local element = elements[elementID]
    if element ~= nil then element.draw(element) end
end

-------------------------------------------------------------------------
--                  APP BAR METHODS
-------------------------------------------------------------------------

function API.drawAppBar()
    --APPLICATION TITLE--
    gpu.setForeground(appBar["fgColor"], false)
    gpu.setBackground(appBar["bgColor"], false)
    gpu.fill(1,1,w,1, " ")
    gpu.set((1 + w/2)-string.len(appBar["name"])/2, 1, appBar["name"])

    --EXIT BUTTON--
    gpu.setForeground(0xFFFFFF, false)
    gpu.setBackground(0xCC3333, false)
    gpu.fill(w-(exitButtonWidth-1),1,exitButtonWidth,1," ")
    gpu.set(w-math.floor(exitButtonWidth*0.5),1,"X")

    --TAB BAR--
    gpu.setBackground(appBar["tabBarColor"], false)
    gpu.fill(1,2,w,1, " ")
    local tabStyle = " "
    for index = 1, #tabs do
        if index == currentTab then
            gpu.setBackground(appBar["tabOnBGColor"], false)
            gpu.setForeground(appBar["tabOnFGColor"], false)
            tabStyle = appBar["tabOnStyle"]
        else
            gpu.setBackground(appBar["tabOffBGColor"], false)
            gpu.setForeground(appBar["tabOffFGColor"], false)
            tabStyle = appBar["tabOffStyle"] 
        end
        local x = 1 + tabWidth * (index-1)
        gpu.fill(x,2,tabWidth+1, 1, tabStyle)
        gpu.set((x+tabWidth/2)-string.len(tabs[index].name)/2, 2, tabs[index].name)
    end

    gpu.setForeground(fgColor, false)
    gpu.setBackground(bgColor, false)
end

function API.draw(elementID)
    local element = elements[elementID]
    if element ~= nil then element.draw(element) end
end

function API.drawCurrentTab()
    API.drawAppBar()
    for ID = 1, #elements do
        API.draw(ID)
    end
end

-------------------------------------------------------------------------
--                  GUI DRAW UTILITY METHODS
-------------------------------------------------------------------------

function API.drawFrame(x, y, width, height, style, fill)
    if style ~= nil then
        local oldBG = gpu.getBackground()
        local oldFG = gpu.getForeground()
        gpu.setBackground(style["bgColor"], false)
        gpu.setForeground(style["fgColor"], false)
        
        --HORIZONTAL--
        local rwidth = width - 2
        local rheight = height - 2
        gpu.fill(x+1, y, rwidth, 1, style["horizontal"])
        gpu.fill(x+1, y+height-1, rwidth, 1, style["horizontal"])

        --VERTICAL--
        if style["vertical"] ~= nil then
        gpu.fill(x, y+1, 1, rheight, style["vertical"])
        gpu.fill(x+width-1, y+1, 1, rheight, style["vertical"])
        end

        --DIAGONALS--
        gpu.fill(x, y, 1, 1, style["topleft"])
        gpu.fill(x+width-1, y, 1, 1, style["topright"])
        gpu.fill(x, y+height-1, 1, 1, style["bottomleft"])
        gpu.fill(x+width-1, y+height-1, 1, 1, style["bottomright"])

        --FILL--
        if fill then
            gpu.fill(x+1, y+1, rwidth, rheight, style["fill"])
        end

        gpu.setBackground(oldBG, false)
        gpu.setForeground(oldFG, false)
    end
end

function API.drawBar(x, y, width, height, value, maxValue, bgColor, fgColor, horizontal)
    local oldBG = gpu.getBackground()
    local oldFG = gpu.getForeground()
    
    if horizontal then
        local valLength = width * (value / maxValue)
        if valLength < width then
            gpu.setBackground(bgColor)
            gpu.fill(x,y,width,height, " ")
        end
        gpu.setBackground(fgColor)
        gpu.fill(x,y,valLength+1,height, " ")
    else
        local valLength = height * (value / maxValue)
        if valLength < height then
            gpu.setBackground(bgColor)
            gpu.fill(x,y,width,height, " ")
        end
        gpu.setBackground(fgColor)
        gpu.fill(x,y,width,valLength+1, " ")
    end

    gpu.setBackground(oldBG, false)
    gpu.setForeground(oldFG, false)
end

function API.drawRect(x, y, width, height, label, bgColor, fgColor)
    local oldBG = gpu.getBackground()
    local oldFG = gpu.getForeground()
    gpu.setBackground(bgColor, false)
    gpu.setForeground(fgColor, false)

    gpu.fill(x,y,width,height, " ")
    local px = (x+width/2)-string.len(label)/2
    local py = (y+height/2)
    gpu.set(px, py, label)

    gpu.setBackground(oldBG, false)
    gpu.setForeground(oldFG, false)
end

function API.drawLabel(x, y, width, height, label, centered)
    if centered then
        local px = (x+width/2)-string.len(label)/2
        local py = (y+height/2)
        gpu.set(px, py, label)
    else
        gpu.set(x, y, label)
    end
end

function API.drawChart(x, y, width, height, bgColor, fgColor, barColor, values, limitValue)
    local asciiBox = {"▁", "▄", "█"}
    local oldBG = gpu.getBackground()
    local oldFG = gpu.getForeground()
    gpu.setBackground(bgColor, false)
    gpu.setForeground(fgColor, false)
    gpu.fill(x, y, 1, height, "│")
    gpu.fill(x+width, y, 1, height, "│")
    gpu.fill(x,y+height,1,1, "└")
    gpu.fill(x+1,y+height,width-1,1, "─")
    gpu.fill(x+width,y+height,1,1, "┘")
    

    gpu.setForeground(barColor, false)
    local vHeight = height
    for i = 1, width-1 do
        if values[i] ~= nil and values[i] ~= 0 then
            local v = API.clamp(values[i] / limitValue, 0, 1) * vHeight
            local vfloor = math.floor(v)
            gpu.fill(x+i, y + (vHeight-vfloor), 1, vfloor, asciiBox[3])
            local frac = v - vfloor
            if frac > 0.00 then
                local halfs = math.floor(frac / 0.5) + 1
                gpu.fill(x+i, y + (vHeight-vfloor-1), 1, 1, asciiBox[halfs])
            end
        else
            gpu.fill(x+i,y,1,vHeight," ")
        end
    end
    gpu.setBackground(oldBG, false)
    gpu.setForeground(oldFG, false)
end

-------------------------------------------------------------------------
--                  GUI DEFAULT ELEMENTS METHODS
-------------------------------------------------------------------------

function API.newLabel(x, y, width, height, label, centered)
    local params = {}
    params["label"] = label
    params["centered"] = centered
    local drawFunc = function(element) API.drawLabel(element.x, element.y, element.width, element.height, element.params["label"], element.params["centered"]) end
    return API.newElement(x, y, width, height, params, drawFunc, nil);
end

function API.newButton(x, y, width, height, label, bgColorOff, bgColorOn, fgColorOff, fgColorOn, callbackFunc)
    local params = {}
    params["label"] = label
    params["bgColorOff"] = bgColorOff
    params["bgColorOn"] = bgColorOn
    params["fgColorOff"] = fgColorOff
    params["fgColorOn"] = fgColorOn
    params["active"] = false
    local drawFunc =  function(element) 
        if element.params["active"] == true then
            API.drawRect(element.x, element.y, element.width, element.height, element.params["label"], element.params["bgColorOn"], element.params["fgColorOn"]) 
        else
            API.drawRect(element.x, element.y, element.width, element.height, element.params["label"], element.params["bgColorOff"], element.params["fgColorOff"]) 
        end
    end
    local callback = function(element, touchX, touchY)
        element.params["active"] = true
        element.draw(element)
        os.sleep(0.2)
        element.params["active"] = false
        element.draw(element)
        if callbackFunc ~= nil then callbackFunc(element, touchX, touchY) end
    end
    return API.newElement(x, y, width, height, params, drawFunc, callback)
end

function API.newToggle(x, y, width, height, label, bgColorOff, bgColorOn, fgColorOff, fgColorOn, active, callbackFunc)
    local params = {}
    params["label"] = label
    params["bgColorOff"] = bgColorOff
    params["bgColorOn"] = bgColorOn
    params["fgColorOff"] = fgColorOff
    params["fgColorOn"] = fgColorOn
    params["active"] = active
    local drawFunc =  function(element) 
        if element.params["active"] == true then
            API.drawRect(element.x, element.y, element.width, element.height, element.params["label"], element.params["bgColorOn"], element.params["fgColorOn"]) 
        else
            API.drawRect(element.x, element.y, element.width, element.height, element.params["label"], element.params["bgColorOff"], element.params["fgColorOff"]) 
        end
    end
    local callback = function(element, touchX, touchY)
        element.params["active"] = not element.params["active"]
        element.draw(element)
        if callbackFunc ~= nil then callbackFunc(element, touchX, touchY) end
    end
    return API.newElement(x, y, width, height, params, drawFunc, callback)
end

function API.newValueBar(x, y, width, height, value, maxValue, bgColor, fgColor, horizontal)
    local params = {}
    params["value"] = value
    params["maxValue"] = maxValue
    params["bgColor"] = bgColor
    params["fgColor"] = fgColor
    params["horizontal"] = horizontal
    local drawFunc = function(element) 
        API.drawBar(element.x, element.y, element.width, element.height, element.params["value"], element.params["maxValue"], element.params["bgColor"], element.params["fgColor"], element.params["horizontal"]) 
    end
    return API.newElement(x, y, width, height, params, drawFunc, nil)
end

function API.newSlider(x, y, width, height, value, maxValue, bgColor, fgColor, horizontal, callbackFunc)
    local params = {}
    params["value"] = value
    params["maxValue"] = maxValue
    params["bgColor"] = bgColor
    params["fgColor"] = fgColor
    params["horizontal"] = horizontal
    local drawFunc = function(element) 
        API.drawBar(element.x, element.y, element.width, element.height, element.params["value"], element.params["maxValue"], element.params["bgColor"], element.params["fgColor"], element.params["horizontal"]) 
    end
    local callback = function(element, touchX, touchY)
        local newValue = math.floor(((touchX - element.x) / element.width) * element.params["maxValue"])
        element.params["value"] = newValue
        element.draw(element)
        if callbackFunc ~= nil then callbackFunc(element, touchX, touchY) end
    end
    return API.newElement(x, y, width, height, params, drawFunc, callback)
end

function API.newChart(x, y, width, height, bgColor, fgColor, barColor, values, limitValue)
    local params = {}
    params["values"] = values
    params["limitValue"] = limitValue
    params["bgColor"] = bgColor
    params["fgColor"] = fgColor
    params["barColor"] = barColor
    local drawFunc = function(element) API.drawChart(element.x, element.y, element.width, element.height, element.params["bgColor"], element.params["fgColor"], element.params["barColor"], element.params["values"], element.params["limitValue"]) end
    return API.newElement(x, y, width, height, params, drawFunc, nil)
end

return API