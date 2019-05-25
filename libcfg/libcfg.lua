local CFG = {}
local serialization = require("serialization")
local fs = require("filesystem")

function CFG.read(filepath, default)
    local file, emsg = io.open(filepath, "rb")
    if file then
        local data = serialization.unserialize(file:read("*a"))
        file:close()
        return data or default or nil
    else
        io.stderr:write("[Error] libcfg.read(): Cannot read file at path " .. filepath .. ": " .. emsg .. "\n")
        return default or nil
    end
end

function CFG.write(filepath, data)
    if not fs.exists(fs.path(filepath)) then
        fs.makeDirectory(fs.path(filepath))
    end
    local file, emsg = io.open(filepath, "wb")
    if file then
        file:write(serialization.serialize(data))
        file:close()
    else
        error("[Error] libcfg.write(): Cannot write file to path " .. filepath .. ": " .. emsg .. "\n")
    end
end

return CFG