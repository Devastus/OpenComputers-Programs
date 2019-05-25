local component = require("component")
local event = require("event")
local gpu = component.gpu
local keyboard = require("keyboard")

local API = {}
local componentMap = {}
local w,h = 0,0
local baseForegroundColor = 0xFFFFFF
local baseBackgroundColor = 0x000000
local frameStyle = {
    light = {
        topleft='┌', horizontal='─',topright='┐',vertical='│',bottomleft='└',bottomright='┘'
    },
    heavy = {
        topleft='┏', horizontal='━',topright='┓',vertical='┃',bottomleft='┗',bottomright='┛'
    },
    double = {
        topleft='╔', horizontal='═',topright='╗',vertical='║',bottomleft='╚',bottomright='╝'
    }
}

function API.width() return w end
function API.height() return h end
function API.percentX(percent) return math.floor(w * percent) end
function API.percentY(percent) return math.floor(h * percent) end
local function clamp(value,min,max) return math.min(math.max(value, min), max) end

--------------------------------------------
-- COMPONENT CLASS --
--------------------------------------------

API.Component = {}
API.Component.__index = API.Component

-- Component Constructor
function API.Component.new(x, y, width, height, state, drawFunc, callbackFunc, visible, parent)
    local self = setmetatable({}, API.Component)
    self.x = x
    self.y = y
    self.width = width or 1
    self.height = height or 1
    self.state = state or {}
    self.visible = visible or true
    self.draw = drawFunc
    self.callback = callbackFunc or nil
    if type(parent) == "number" then
        local p = componentMap[parent]
        self.parent = p or nil
        if p ~= nil then
            if p.children == nil then p.children = {} end
            table.insert(p.children, self)
        end
    else
        self.parent = parent or nil
        if parent ~= nil then
            if parent.children == nil then parent.children = {} end
            table.insert(parent.children, self)
        end
    end
    self.children = nil
    local id = #componentMap + 1
    componentMap[id] = self
    return id
end

-- Render the component, recursively rendering the children if enabled
function API.Component:render(renderChildren)
    self:draw()
    renderChildren = renderChildren or false
    if renderChildren == true and self.children ~= nil and #self.children > 0 then
        for comp in self.children do
            comp:render(true)
        end
    end
end

-- Get a recursive X position based on parents
function API.Component:relativeX()
    if self.parent ~= nil then
        return self.parent:relativeX() + self.x
    end
    return self.x
end

-- Get a recursive Y position based on parents
function API.Component:relativeY()
    if self.parent ~= nil then
        return self.parent:relativeY() + self.y
    end
    return self.y
end

-- Check if Component Rect contains position
function API.Component:contains(x, y)
    local rx = self:relativeX()
    local ry = self:relativeY()
    local xmax = rx + self.width-1
    local ymax = ry + self.height-1
    return x >= rx and x <= xmax and y >= ry and y <= ymax
end

-- Set state values as a table and re-render the component tree
function API.Component:setState(state)
    for k,v in pairs(state) do
        self.state[k] = v
    end
    self:render(true)
end

-- Get state values
function API.Component:getState(key)
    if key == nil then
        return self.state
    else
        return self.state[key]
    end
end

--------------------------------------------
-- CORE FUNCTIONS --
--------------------------------------------

-- Initialize base properties of the GUI
function API.init(foregroundColor, backgroundColor, width, height)
    if width ~= nil and height ~= nil then
        API.setResolution(width, height)
    else
        w, h = gpu.getResolution()
    end
    baseForegroundColor = foregroundColor or 0xFFFFFF
    baseBackgroundColor = backgroundColor or 0x000000
    API.clearAll()
end

-- Set the screen resolution
function API.setResolution(width, height)
    gpu.setResolution(width, height)
    w = width
    h = height
end

-- Clear the screen of content
function API.clearScreen()
    gpu.setForeground(baseForegroundColor, false)
    gpu.setBackground(baseBackgroundColor, false)
    gpu.fill(1,1,w,h," ")
end

-- Clear everything, deleting components
function API.clearAll()
    API.clearScreen()
    componentMap = {}
end

-- Render all components separately
function API.renderAll()
    API.clearScreen()
    for i = 1, #componentMap, 1 do
        componentMap[i]:render(false)
    end
end

-- Render a component, optionally as a recursive tree
function API.render(componentID, renderChildren)
    local comp = componentMap[componentID]
    if comp ~= nil and comp.visible == true then comp:render(renderChildren) end
end

-- Check if a Component contains the click position, launch a callback if it exists
function API.click(x, y)
    local id = -1
    for i = 1, #componentMap, 1 do
        local comp = componentMap[i]
        if comp ~= nil then
            if comp.visible then
                if comp:contains(x, y) then
                    if comp.callback ~= nil then comp:callback(x, y) end
                    --comp.focused = true
                    id = i
                --else
                    --comp.focused = false
                end
            end
        end
    end
    return id
end

function API.update(updateInterval, updateFunc)
    local interrupted = false
    while interrupted == false do
        local ev, p1, p2, p3, p4, p5 = event.pull(updateInterval or 0.01)
        if ev == "interrupted" then
            interrupted = true
        elseif ev == "touch" then
            if p2 and p3 then
                API.click(p2, p3)
            end
        end
        if (updateFunc ~= nil) updateFunc()
    end
    -- local _, _, x, y = event.pull(updateInterval or 0.01, "touch")
    -- if x and y then
    --     API.click(x, y)
    -- end
end

-- Set a Component's visibility
function API.setVisible(componentID, visible)
    if componentMap[componentID] ~= nil then
        componentMap[componentID].visible = visible
        API.renderAll()
    end
end

-- Get a Component from the map
function API.getComponent(componentID)
    return componentMap[componentID]
end

--------------------------------------------
-- PRIMITIVE DRAW METHODS --
--------------------------------------------

function API.drawRect(x, y, width, height, fgColor, bgColor, frame)
    local oldFG = gpu.getForeground()
    local oldBG = gpu.getBackground()
    gpu.setForeground(fgColor, false)
    gpu.setBackground(bgColor, false)

    if frame ~= nil and frameStyle[frame] ~= nil then
        -- HORIZONTAL
        local rwidth = width - 2
        local rheight = height - 2
        gpu.fill(x+1, y, rwidth, 1, frameStyle[frame]["horizontal"])
        gpu.fill(x+1, y+height-1, rwidth, 1, frameStyle[frame]["horizontal"])

        -- VERTICAL
        gpu.fill(x, y+1, 1, rheight, frameStyle[frame]["vertical"])
        gpu.fill(x+width-1, y+1, 1, rheight, frameStyle[frame]["vertical"])

        -- DIAGONALS
        gpu.fill(x, y, 1, 1, frameStyle[frame]["topleft"])
        gpu.fill(x+width-1, y, 1, 1, frameStyle[frame]["topright"])
        gpu.fill(x, y+height-1, 1, 1, frameStyle[frame]["bottomleft"])
        gpu.fill(x+width-1, y+height-1, 1, 1, frameStyle[frame]["bottomright"])

        -- FILL
        gpu.fill(x+1, y+1, rwidth, rheight, " ")
    else
        gpu.fill(x, y, width, height, " ")
    end

    gpu.setForeground(oldFG, false)
    gpu.setBackground(oldBG, false)
end

function API.drawText(x, y, width, height, text, fgColor, bgColor, centered)
    local oldFG = gpu.getForeground()
    local oldBG = gpu.getBackground()
    gpu.setForeground(fgColor, false)
    gpu.setBackground(bgColor, false)
    if #text > width then
        local diff = #text - width
        text = text:sub(1, -diff)
    end
    if centered then
        local px = (x+width/2)-string.len(text)/2
        local py = (y+height/2)
        gpu.set(px, py, text)
    else
        gpu.set(x, y, text)
    end
    gpu.setForeground(oldFG, false)
    gpu.setBackground(oldBG, false)
end

--------------------------------------------
-- UTILITY METHODS --
--------------------------------------------

local function isAlphanumeric(char)
    local alphanumeric = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    for i = 1, #alphanumeric, 1 do
        local c = string.char(alphanumeric:byte(i))
        if char == c then return true end
    end
    return false
end

--------------------------------------------
-- DEFAULT COMPONENTS --
--------------------------------------------

-- Create a simple Label
function API.newLabel(x, y, width, height, label, fgColor, bgColor, centered, parent)
    local state = {}
    state.text = label
    state.centered = centered
    state.fgColor = fgColor or baseForegroundColor
    state.bgColor = bgColor or baseBackgroundColor
    local renderFunc = function(self)
        API.drawText(self:relativeX(), self:relativeY(), self.width, self.height, self.state.text, self.state.fgColor, self.state.bgColor, self.state.centered)
    end
    return API.Component.new(x, y, width, height, state, renderFunc, nil, true, parent)
end

-- Create a Container rect
function API.newContainer(x, y, width, height, fgColor, bgColor, frame, parent)
    local state = {}
    state.fgColor = fgColor or baseForegroundColor
    state.bgColor = bgColor or baseBackgroundColor
    state.frame = frame
    local renderFunc = function(self)
        API.drawRect(self:relativeX(), self:relativeY(), self.width, self.height, self.state.fgColor, self.state.bgColor, self.state.frame)
    end
    return API.Component.new(x, y, width, height, state, renderFunc, nil, true, parent)
end

-- Create a Button that can be pressed
function API.newButton(x, y, width, height, label, fgOff, fgOn, bgOff, bgOn, frame, callbackFunc, parent)
    local state = {}
    state.text = label
    state.fgOn = fgOn
    state.fgOff = fgOff
    state.bgOn = bgOn
    state.bgOff = bgOff
    state.frame = frame or nil
    state.active = false
    local renderFunc = function(self)
        local rx = self:relativeX()
        local ry = self:relativeY()
        if self.state.active then
            API.drawRect(rx, ry, self.width, self.height, self.state.fgOn, self.state.bgOn, self.state.frame)
            API.drawText(rx, ry, self.width, self.height, self.state.text, self.state.fgOn, self.state.bgOn, true)
        else
            API.drawRect(rx, ry, self.width, self.height, self.state.fgOff, self.state.bgOff, self.state.frame)
            API.drawText(rx, ry, self.width, self.height, self.state.text, self.state.fgOff, self.state.bgOff, true)
        end
    end
    local callback = function(self, x, y)
        self.state.active = true
        self:render()
        os.sleep(0.2)
        self.state.active = false
        self:render()
        if callbackFunc ~= nil then callbackFunc() end
    end
    return API.Component.new(x, y, width, height, state, renderFunc, callback, true, parent)
end

-- Create a Button that will keep it's state (and toggle it upon press)
function API.newToggle(x, y, width, height, label, fgOff, fgOn, bgOff, bgOn, frame, callbackFunc, parent)
    local state = {}
    state.text = label
    state.fgOn = fgOn
    state.fgOff = fgOff
    state.bgOn = bgOn
    state.bgOff = bgOff
    state.frame = frame or nil
    state.active = false
    local renderFunc = function(self)
        local rx = self:relativeX()
        local ry = self:relativeY()
        if self.state.active then
            API.drawRect(rx, ry, self.width, self.height, self.state.fgOn, self.state.bgOn, self.state.frame)
            API.drawText(rx, ry, self.width, self.height, self.state.text, self.state.fgOn, self.state.bgOn, true)
        else
            API.drawRect(rx, ry, self.width, self.height, self.state.fgOff, self.state.bgOff, self.state.frame)
            API.drawText(rx, ry, self.width, self.height, self.state.text, self.state.fgOff, self.state.bgOff, true)
        end
    end
    local callback = function(self, x, y)
        self.state.active = not self.state.active
        self:render()
        if callbackFunc ~= nil then callbackFunc(self, x, y) end
    end
    return API.Component.new(x, y, width, height, state, renderFunc, callback, true, parent)
end

-- Create a Horizontal/Vertical bar that represents a percentage between value/maxValue
function API.newValueBar(x, y, width, height, value, maxValue, fillColor, bgColor, horizontal, frame, parent)
    local state = {}
    state.value = value or 0
    state.maxValue = maxValue or 100
    state.fillColor = fillColor
    state.bgColor = bgColor
    state.frame = frame
    state.horizontal = horizontal
    local renderFunc = function(self)
        local rx = self:relativeX()
        local ry = self:relativeY()
        API.drawRect(rx, ry, self.width, self.height, baseForegroundColor, self.state.bgColor, self.state.frame)
        if self.state.horizontal then
            local valLength = self.width * (self.value / self.maxValue)
            API.drawRect(rx+1, ry+1, valLength+1, self.height-2, baseForegroundColor, self.state.fillColor, nil)
        else
            local valLength = self.height * (self.value / self.maxValue)
            API.drawRect(rx+1, ry+self.height-valLength, self.width-2, valLength+1, baseForegroundColor, self.state.fillColor, nil)
        end
    end
    return API.Component.new(x, y, width, height, state, renderFunc, nil, true, parent)
end

-- Create a Bar Chart of given values
function API.newChart(x, y, width, height, fillColor, bgColor, values, maxValue, frame, parent)
    local state = {}
    state.fillColor = fillColor
    state.bgColor = bgColor
    state.frame = frame
    state.values = values
    state.maxValue = maxValue
    local renderFunc = function(self)
        local rx = self:relativeX()
        local ry = self:relativeY()
        local asciiBox = {"▁", "▄", "█"}
        local oldBG = gpu.getBackground()
        local oldFG = gpu.getForeground()
        local segwidth = math.floor((self.width-2) / #values)
        local chartH = self.height-2
        API.drawRect(rx, ry, self.width, self.height, baseForegroundColor, self.state.bgColor, self.state.frame)
        gpu.setForeground(self.state.fillColor, false)
        gpu.setBackground(self.state.bgColor, false)
        for i=1, #values, 1 do
            local seg = rx+1+((i-1)*segwidth)
            if self.state.values[i] ~= nil and self.state.values[i] > 0 then
                local v = clamp(self.state.values[i] / self.state.maxValue, 0, 1) * chartH
                local vfloor = math.floor(v)
                local frac = v - vfloor
                gpu.fill(seg, ry + 1 + (chartH-vfloor), segwidth, vfloor, asciiBox[3])
                if frac > 0.0 then
                    local halfs = 1 + math.floor(frac / 0.5)
                    gpu.fill(seg, ry + 1 + (chartH-vfloor-1), segwidth, 1, asciiBox[halfs])
                end
            else
                gpu.fill(seg, ry, segwidth, chartH, " ")
            end
        end
        gpu.setForeground(oldFG, false)
        gpu.setBackground(oldBG, false)
    end
    return API.Component.new(x, y, width, height, state, renderFunc, nil, true, parent)
end

-- Create a single-line Text Input Field that can take in keyboard input
function API.newInputField(x, y, width, text, fgOn, fgOff, bgOn, bgOff, characterLimit, onChangeCallback, parent)
    local state = {}
    state.text = text or ""
    state.characterLimit = characterLimit
    state.fgOn = fgOn
    state.fgOff = fgOff
    state.bgOn = bgOn
    state.bgOff = bgOff
    state.active = false
    local renderFunc = function(self)
        -- Render a textbox that encapsulates text
        -- Upon being activated redraws constantly and displays an additional "cursor" appended to text
        local rx = self:relativeX()
        local ry = self:relativeY()
        if self.state.active then
            API.drawRect(rx, ry, self.width, 1, self.state.fgOn, self.state.bgOn, nil)
            local widthDiff = math.max((#self.state.text+1) - self.width, 0)
            local shownText = string.sub(self.state.text.."|", 1+widthDiff)
            API.drawText(rx, ry, self.width, 1, shownText, self.state.fgOn, self.state.bgOn, false)
        else
            API.drawRect(rx, ry, self.width, 1, self.state.fgOff, self.state.bgOff, nil)
            local widthDiff = math.max(#self.state.text - self.width, 0)
            local shownText = string.sub(self.state.text, 1+widthDiff)
            API.drawText(rx, ry, self.width, 1, shownText, self.state.fgOff, self.state.bgOff, false)
        end
    end
    local callbackFunc = function(self, x, y)
        -- Probably launches a blocking while loop that expects keyboard OR touch input
        -- Enter, ESC or clicking away from the input field will end the input sequence
        -- Clicking inside while activated will take the x-value and place "cursor" close to it
        if not self.state.active then
            self.state.active = true
            self:render()
            while self.state.active do
                local ev, p1, p2, p3, p4, p5 = event.pull()
                if ev == "interrupted" then
                    self.state.active = false
                    self:render()
                    if onChangeCallback ~= nil then onChangeCallback(self.state.text) end
                    break
                elseif ev == "key_down" then
                    local space_char = 32
                    local enter_char = 13
                    local backspace_char = 8
                    local char = string.char(p2)
                    if keyboard.isShiftDown() then
                        char = string.upper(char)
                    end
                    if isAlphanumeric(char) then
                        if #self.state.text < self.state.characterLimit then
                            self.state.text = self.state.text..char
                        end
                    elseif p2 == space_char then
                        if #self.state.text < self.state.characterLimit then
                            self.state.text = self.state.text.." "
                        end
                    elseif p2 == backspace_char then
                        self.state.text = self.state.text:sub(1, -2)
                    elseif p2 == enter_char then
                        self.state.active = false
                        self:render()
                        if onChangeCallback ~= nil then onChangeCallback(self.state.text) end
                        break
                    end
                    self:render()
                elseif ev == "touch" then
                    if not self:contains(p2, p3) then
                        self.state.active = false
                        self:render()
                        if onChangeCallback ~= nil then onChangeCallback(self.state.text) end
                        break
                    end
                end
            end
        end
    end
    return API.Component.new(x, y, width, 1, state, renderFunc, callbackFunc, true, parent)
end

return API