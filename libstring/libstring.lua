function string:split(separator)
    if separator ~= nil then
        local fields = {}
        local pattern = string.format("([^%s]+)", separator)
        message:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
    else
        io.stderr:write("string:split(): separator is nil!")
    end
end