local CFG = {}
local serialization = require("serialization")
local fs = require("filesystem")

function CFG.read(filepath, default)
    local file, emsg = io.open(filepath, "rb")
    if not file then
        if default ~= nil then
            return default
        else
            error("[Error] libcfg.read(): Cannot read file at path " .. filepath .. ": " .. emsg .. "\n")
        end
    end
    local data = serialization.unserialize(file:read("*a"))
    file:close()
    return data or default or nil
end

function CFG.write(filepath, data)
    if not fs.exists(fs.path(filepath)) then
        fs.makeDirectory(fs.path(filepath))
    end
    local file, emsg = io.open(filepath, "wb")
    if not file then
        error("[Error] libcfg.write(): Cannot write file to path " .. filepath .. ": " .. emsg .. "\n")
    end
    file:write(serialization.serialize(data))
    file:close()
end

return CFG