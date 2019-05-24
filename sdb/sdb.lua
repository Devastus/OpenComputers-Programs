local component = require("component")
local sdb = require("libsdb")
local net = require("libnet")

local function up(port)
    sdb.init()
    net.open(port or 27017)
    net.connectEvent("sdb_read", read)
    net.connectEvent("sdb_write", write)
    net.connectEvent("sdb_update", update)
    net.connectEvent("sdb_delete", delete)
end

local function down()
    net.close()
end

local function read(remoteAddress, request)
    local data, errormsg = sdb.read(request.collection, request.options)
    if data ~= nil then
        net.send(remoteAddress, data, "sdb_read")
    else
        net.send(remoteAddress, {message = errormsg}, "error")
    end
end

local function write(remoteAddress, request)
    local success, errormsg = sdb.write(request.collection, request.data)
    if success == true then
        net.send(remoteAddress, {success = true}, "sdb_write")
    else
        net.send(remoteAddress, {message = errormsg}, "error")
    end
end

local function update(remoteAddress, request)
    local success, errormsg = sdb.update(request.collection, request.id, request.data)
    if success == true then
        net.send(remoteAddress, {success = true}, "sdb_update")
    else
        net.send(remoteAddress, {message = errormsg}, "error")
    end
end

local function delete(remoteAddress, request)
    local success, errormsg = sdb.update(request.collection, request.id)
    if success == true then
        net.send(remoteAddress, {success = true}, "sdb_delete")
    else
        net.send(remoteAddress, {message = errormsg}, "error")
    end
end

--------------------------------------------------
--- MAIN ---
--------------------------------------------------

local args, options = shell.parse(...)
if args[1] == "up" or args[1] == nil then
    up(args[2] or nil)
elseif args[1] == "down" || args[1] == nil then
    down()
end