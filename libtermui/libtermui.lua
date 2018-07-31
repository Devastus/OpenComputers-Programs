local term = require("term")
local event = require("event")
local keyboard = require("keyboard")
local gpu = term.gpu()
local colors = {
    normal = {0xFFFFFF, 0x000000},
    highlight = {0x000000, 0xFFFFFF}
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

function API.write(x, y, msg, highlighted)
    if highlighted == true then
        gpu.setForeground(colors.highlight[1])
        gpu.setBackground(colors.highlight[2])
    else
        gpu.setForeground(colors.normal[1])
        gpu.setBackground(colors.normal[2])
    end
    term.setCursor(x, y)
    term.write(msg)
end

function API.read(x, y, wrap)
    term.setCursor(x, y)
    return term.read({nowrap = not wrap})
end

function API.clear()
    term.clear()
end

function API.selectOptions(x, y, options)
    local selected = 0
    local length = #options-1
    __drawOptions(x, y, options, selected)
    while true do
        local _,_,_,k = event.pull(0.5, "key_down")
        if k == keyboard.keys.down then
            selected = mod(selected + 1, length)
            __drawOptions(x, y, options, 1 + selected)
        elseif k == keyboard.keys.up then
            selected = mod(selected - 1, length)
            __drawOptions(x, y, options, 1 + selected)
        elseif k == keyboard.keys.enter then
            return 1 + selected
        end
    end

    -- while event.pull(0.5, "interrupted") == nil do
    --     if keyboard.isKeyDown(keyboard.keys.down) then
    --         selected = mod(selected + 1, length)
    --         __drawOptions(x, y, options, 1 + selected)
    --     end
    --     if keyboard.isKeyDown(keyboard.keys.up) then
    --         selected = mod(selected - 1, length)
    --         __drawOptions(x, y, options, 1 + selected)
    --     end
    --     if keyboard.isKeyDown(keyboard.keys.enter) then
    --         return 1 + selected
    --     end
    -- end
end

function API.selectToggles(x, y, options, selected)
    options.insert("Continue")
    highlighted = 0
    local length = #options-1
    __drawToggles(x, y, options, selected, highlighted)
    while event.pull(0.5, "interrupted") == nil do
        if keyboard.isKeyDown(keyboard.keys.down) then
            highlighted = mod(highlighted + 1, length)
            __drawToggles(x, y, options, selected, 1 + highlighted)
        end
        if keyboard.isKeyDown(keyboard.keys.up) then
            highlighted = mod(highlighted - 1, length)
            __drawToggles(x, y, options, selected, 1 + highlighted)
        end
        if keyboard.isKeyDown(keyboard.keys.enter) then
            --Either toggle highlighted option, or exit loop if it is the last one on the list
            if highlighted ~= length then
                selected[1 + highlighted] = not selected[1 + highlighted]
                __drawToggles(x, y, options, selected, 1 + highlighted)
            else
                return options
            end
        end
    end
end

return API