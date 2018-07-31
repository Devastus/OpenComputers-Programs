local term = require("term")
local event = require("event")
local keyboard = require("keyboard")
local gpu = term.gpu()
local colors = {
    normal = {0xFFFFFF, 0x000000},
    highlight = {0x000000, 0xFFFFFF},
    warning = {0x00FFFF, 0x000000},
    error = {0xFF0000, 0x000000},
    affirmation = {0x00FF00, 0x000000}
}

local API = {}

local function mod(value, max)
    return (value + max) % max
end

local function __drawOptions(x, y, options, selected)
    for i = 1, #options, 1 do
        if i == selected then
            gpu.setForeground(colors.highlight[1])
            gpu.setBackground(colors.highlight[2])
        else
            gpu.setForeground(colors.normal[1])
            gpu.setBackground(colors.normal[2])
        end
        term.setCursor(x, y+i-1)
        term.write(options[i])
    end
end

local function __drawToggles(x, y, options, selected, highlighted)
    for i = 1, #options, 1 do
        if i == highlighted then
            gpu.setForeground(colors.highlight[1])
            gpu.setBackground(colors.highlight[2])
        else
            gpu.setForeground(colors.normal[1])
            gpu.setBackground(colors.normal[2])
        end
        term.setCursor(x, y+i-1)
        if i < #options then
            if selected[i] == true then
                term.write("■ "..options[i])
            else
                term.write("□ "..options[i])
            end
        else
            term.write(options[i])
        end
    end
end

function API.isAvailable()
    return term.isAvailable()
end

function API.write(x, y, msg, msgtype)
    msgtype = msgtype or "normal"
    gpu.setForeground(colors[msgtype][1])
    gpu.setBackground(colors[msgtype][2])
    term.setCursor(x, y)
    term.write(msg)
end

function API.read(x, y, wrap, msgtype)
    msgtype = msgtype or "normal"
    gpu.setForeground(colors[msgtype][1])
    gpu.setBackground(colors[msgtype][2])
    term.setCursor(x, y)
    return term.read({nowrap = not wrap})
end

function API.clear()
    term.clear()
end

function API.selectOptions(x, y, options)
    local selected = 0
    local length = #options
    __drawOptions(x, y, options, 1 + selected)
    while true do
        local e,_,_,k = event.pull(0.5)
        if e == "key_down" then
            if k == keyboard.keys.down then
                selected = mod(selected + 1, length)
                __drawOptions(x, y, options, 1 + selected)
            elseif k == keyboard.keys.up then
                selected = mod(selected - 1, length)
                __drawOptions(x, y, options, 1 + selected)
            elseif k == keyboard.keys.enter then
                return 1 + selected
            end
        elseif e == "interrupted" then
            io.stderr:write("Error: interrupted\n")
            os.exit()
        end
    end
end

function API.selectToggles(x, y, options, selected)
    options.insert("Continue")
    highlighted = 0
    local length = #options
    __drawToggles(x, y, options, selected, 1 + highlighted)
    while true do
        local e,_,_,k = event.pull(0.5)
        if e == "key_down" then
            if k == keyboard.keys.down then
                highlighted = mod(highlighted + 1, length)
                __drawToggles(x, y, options, selected, 1 + highlighted)
            end
            if k == keyboard.keys.up then
                highlighted = mod(highlighted - 1, length)
                __drawToggles(x, y, options, selected, 1 + highlighted)
            end
            if k == keyboard.keys.enter then
                --Either toggle highlighted option, or exit loop if it is the last one on the list
                if highlighted+1 < length then
                    selected[1 + highlighted] = not selected[1 + highlighted]
                    __drawToggles(x, y, options, selected, 1 + highlighted)
                else
                    return options
                end
            end
        elseif e == "interrupted" then
            io.stderr:write("Error: interrupted\n")
            os.exit()
        end
    end
end

return API