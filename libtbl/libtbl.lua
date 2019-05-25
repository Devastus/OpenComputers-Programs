function table:tostring()
    local result = ""
    for k,v in pairs(self) do
        
    end
    return result
end

function table:spread(table)
    for k,v in pairs(table) do
        self[k] = v
    end
    return self
end