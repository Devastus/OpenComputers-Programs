local fs = require("filesystem")
local API = {}

local DIRECTORY = "/etc/"
local EXTENSION = ".cfg"

local function _fileExists(path)
  local file = io.open(path)
  if file == nil then return false end
  file:close()
  return true
end

function API.readConfig(filename) 
    local data, section, key, value, temp = {}
    local path = DIRECTORY..filename..EXTENSION
    if not _fileExists(path) then
        io.stderr:write("Error: file not found at path '"..path.."'")
        return nil 
    end
    for line in io.lines(path) do
        temp = line:match('^%[(.+)%]$')
        if temp ~= nil and section ~= temp then section = temp end
        key, value = line:match('^([^=]+)=(.+)$')
        if section ~= nil then
            data[section] = data[section] or {}
            if key ~= nil then
            data[section][key] = value
            end
        end
    end
    return data
end

function API.writeConfig(filename, data)
    local path = DIRECTORY..filename..EXTENSION
    local file = io.open(path,'w')
    for section, table in pairs(data) do
        file:write('['..section..']\n')
      for key, value in pairs(table) do
        file:write(key..'='..value..'\n')
      end
      file:write('\n')
    end
    file:close()
end

function API.writeConfigSection(filename, section, key, value)
    if section == nil and key == nil and value == nil then return end
    -- Read existing config for editing (if any exists)
    local data = API.readConfig(filename)       
    
    if section ~= nil and value == nil then
        if key == nil then
            -- Delete whole section
            data[section] = nil                  
        else
            -- Delete key/value pair
            data[section][key] = nil             
        end
        API.writeConfig(filename, data)
        return
    end
    
    if key:match '=' then
        io.stderr:write('An equals sign is not expected inside key')
    end
    
    -- Create section if not present and update key value
    data[section] = data[section] or {}
    data[section][key] = value       
    API.writeConfig(filename, data)
    return data
end

return API

-- local function _writeToFile(filename, t)
--     local path = DIRECTORY..filename..EXTENSION
--     local fo = io.open(path,'w')
--     for k,v in pairs(t) do
--       fo:write('['..k..']\n')
--       for k2,v2 in pairs(v) do
--         fo:write(k2..'='..v2..'\n')
--       end
--       fo:write('\n')
--     end
--     fo:close()
-- end

-- function API.writeConfig(filename, section, key, value)
--     if section == nil and key == nil and value == nil then return end
--     local t = read_config(filename)       -- read existing configuration, if any
  
--     if section ~= nil and value == nil then
--       if key == nil then
--         t[section] = nil                  --eliminate whole section
--       else
--         t[section][key] = nil             --eliminate key/value pair
--       end
--       _writeToFile(filename, t)
--       return
--     end
  
--     if key:match '=' then
--       io.stderr:write('An equals sign is not expected inside key')
--     end
  
--     t[section] = t[section] or {}         --create section if not present
--     t[section][key] = value               --update key value
  
--     _writeToFile(filename, t)                          -- write to file
--     return t                              --return updated configuration table
-- end