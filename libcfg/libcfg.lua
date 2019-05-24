local CFG = {}
local serialization = require("serialization")
local fs = require("filesystem")

function CFG.read(filepath, default)
    local file, emsg = io.open(filepath, "rb")
    if not file then
        if default ~= nil then
            return default
        else
            io.stderr:write("[Error] libcfg.read(): Cannot read file at path " .. filepath .. ": " .. emsg .. "\n")
            return nil
        end
    end
    local sdata = file:read("*a")
    file:close()
    if sdata == nil or string.len(sdata) <= 0 then
        return default or nil
    else
        return serialization.unserialize(sdata) or default or nil
    end
end

function CFG.write(filepath, data)
    if not fs.exists(fs.path(filepath)) then
        fs.makeDirectory(fs.path(filepath))
    end
    local file, emsg = io.open(filepath, "wb")
    if not file then
        io.stderr:write("[Error] libcfg.write(): Cannot write file to path " .. filepath .. ": " .. emsg .. "\n")
        return
    end
    local sdata = serialization.serialize(data)
    file:write(sdata)
    file:close()
end

return CFG