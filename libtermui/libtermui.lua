local term = require("term")
local gpu = term.gpu()
local keyboard = term.keyboard()
local colors = {
    normal = {0xFFF, 0x000},
    highlight = {0x000, 0xFFF}
}

local API = {}

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

function __drawOptions(x, y, options, selected)
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

function __drawToggles(x, y, options, selected, highlighted)
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

function API.selectOptions(x, y, options)
    local selected = 1
    local length = #options+1
    __drawOptions(x, y, options, selected)
    while event.pull(0.05, "interrupted") == nil do
        if keyboard.isKeyDown(keyboard.keys.down) then
            selected = ((selected + 1) % length) + 1
            __drawOptions(x, y, options, selected)
        end
        if keyboard.isKeyDown(keyboard.keys.up) then
            selected = (((selected - 1)+length) % length) + 1
            __drawOptions(x, y, options, selected)
        end
        if keyboard.isKeyDown(keyboard.keys.enter) then
            return selected
        end
    end
end

function API.selectToggles(x, y, options, selected)
    options.insert("Continue")
    highlighted = 1
    local length = #options+1
    __drawToggles(x, y, options, selected, highlighted)
    while event.pull(0.05, "interrupted") == nil do
        if keyboard.isKeyDown(keyboard.keys.down) then
            highlighted = ((highlighted + 1) % length) + 1
            __drawToggles(x, y, options, selected, highlighted)
        end
        if keyboard.isKeyDown(keyboard.keys.up) then
            highlighted = (((highlighted - 1)+length) % length) + 1
            __drawToggles(x, y, options, selected, highlighted)
        end
        if keyboard.isKeyDown(keyboard.keys.enter) then
            --Either toggle highlighted option, or exit loop if it is the last one on the list
            if highlighted ~= length then
                selected[highlighted] = not selected[highlighted]
                __drawToggles(x, y, options, selected, highlighted)
            else
                return options
            end
        end
    end
end

return API