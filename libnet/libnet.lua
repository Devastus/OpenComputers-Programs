local component = require("component")
local serialization = require("serialization")
local event = require("event")
local modem = component.modem

local API = {}
local driver

----------------------------------------------------
--- INTERNAL ---
----------------------------------------------------

local function _split(message, separator)
    if separator ~= nil then
        local fields = {}
        local pattern = string.format("([^%s]+)", separator)
        message:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
    else
        error("[Error] libnet._split(): separator is nil!")
    end
end

local function _writePayload(data, msgType)
    local msg = ""
    if driver.header ~= nil then msg = driver.header.."#" end
    msg = msg..msgType
    if data ~= nil then
        local sdata = serialization.serialize(data)
        msg = msg.."#"..sdata
    end
    return msg
end

local function _readPayload(payload)
    local msg = {}
    local data = _split(payload, "#")
    if #data == 1 then
        msg.header = nil
        msg.type = data[1]
        msg.data = nil
    elseif #data == 2 then
        msg.header = nil
        msg.type = data[1]
        msg.data = serialization.unserialize(data[2]) or nil
    else
        msg.header = data[1]
        msg.type = data[2]
        msg.data = serialization.unserialize(data[3]) or nil
    end
    return msg
end

local function _handleRecv(_, _, remoteAddress, port, distance, payload)
    local message = _readPayload(payload)
    if message.header == driver.headerPrefix then
        if driver[message.type] ~= nil then
            driver[message.type](remoteAddress, message.data)
        end
    end
end

----------------------------------------------------
--- PUBLIC ---
----------------------------------------------------

function API.connectEvent(msgType, callbackFunc)
    if driver ~= nil and msgType ~= nil and callbackFunc ~= nil then
        driver[msgType] = callbackFunc
    else
        error("[Error] libnet.connectEvent(): invalid event registration!")
    end
end

function API.disconnectEvent(msgType)
    if driver ~= nil and msgType ~= nil then
        driver[msgType] = nil
    else
        error("[Error] libnet.disconnectEvent(): event or driver doesn't exist!")
    end
end

function API.send(address, data, msgType)
    local payload = _writePayload(data, msgType)
    modem.send(address, driver.port, payload)
end

function API.broadcast(data, msgType)
    local payload = _writePayload(data, msgType)
    modem.broadcast(driver.port, payload)
end

function API.open(port)
    modem.open(port)
    driver = {port = port}
    return event.listen("modem_message", _handleRecv)
end

function API.close()
    modem.close(driver.port)
    driver = nil
    return event.ignore("modem_message", _handleRecv)
end

function API.setHeader(header)
    driver.header = header or nil
end

return API