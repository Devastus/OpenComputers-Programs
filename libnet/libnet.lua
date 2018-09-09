local component = require("component")
local serialization = require("serialization")
local event = require("event")
local modem = component.modem

local API = {}
local driver

----------------------------------------------------
--- INTERNAL ---
----------------------------------------------------

local function _writePayload(data, msgType)
    if data ~= nil then
        local sdata = serialization.serialize(data)
        return driver.headerPrefix..'#'..msgType..'#'..sdata
    else
        return driver.headerPrefix..'#'..msgType
    end
end

local function _readPayload(payload)
    local msg = {}
    local data = string.match(payload, '([^#])')
    msg.header = data[1]
    msg.type = data[2]
    msg.data = data[3] or nil
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
    end
end

function API.disconnectEvent(msgType)
    if driver ~= nil and msgType ~= nil then
        driver[msgType] = nil
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

function API.open(port, headerPrefix)
    modem.open(port)
    driver = {}
    driver.port = port
    driver.headerPrefix = headerPrefix
    event.listen("modem_message", _handleRecv)
end

function API.close()
    modem.close(driver.port)
    driver = nil
    event.ignore("modem_message", _handleRecv)
end

return API