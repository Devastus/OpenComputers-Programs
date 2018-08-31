local component = require("component")
local serialization = require("serialization")
local event = require("event")
local modem = component.modem

local API = {}
local driver

local function _writePayload(data, msgType)
    local sdata = serialize(data)
    local payload = driver.headerPrefix..'@'..msgType..'&'..sdata
    return payload 
end

local function _readPayload(address, payload)
    local msg = {}
    local typeCharIndex = string.find(payload, '@')
    local dataCharIndex = string.find(payload, '&')
    msg.header = string.sub(payload, 1, typeCharIndex[1]-1)
    msg.type = string.sub(payload, typeCharIndex[1]+1, dataCharIndex[1]-1)
    msg.data = unserialize(string.sub(payload, dataCharIndex[1]+1))
    return msg
end

local function _handleRecv(eventName, localNetworkCard, remoteAddress, port, distance, payload)
    local message = _readPayload(remoteAddress, payload)
    if message.header == driver.headerPrefix then
        if driver[message.type] ~= nil then
            driver[message.type](remoteAddress, message.data)
        end
    end
end

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

function API.broadcast(data)
    local payload = _writePayload(data)
    modem.broadcast(driver.port, payload)
end

function API.open(port, headerPrefix)
    driver = {}
    driver.port = port
    driver.headerPrefix = headerPrefix
    modem.open(driver.port)
    return event.listen("modem_message", _handleRecv)
end

function API.close()
    modem.close()
    driver = nil
    return event.ignore("modem_message", _handleRecv)
end

return API