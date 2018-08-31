local LIB = {}

-- Return a value wrapped around max and 0
function LIB.mod(value, max)
    return (value + max) % max
end

-- Return a value clamped between min and max
function LIB.clamp(value, min, max)
    return math.max(math.min(value, max), min)
end

-- Return 1 if positive, -1 if negative
function LIB.sign(value)
    if value == math.abs(value) then
        return 1
    else
        return -1
    end
end

-- Return a number rounded to given decimal accuracy
function LIB.round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Linearly interpolate a value
function LIB.lerp(a, b, t)
    return (1-t) * a + t * b
end

-- Return the average of given values
function LIB.average(values)
    local total = 0
    for i = 1, #values, 1 do
        total = total + values[i]
    end
    return total / #values
end

return LIB