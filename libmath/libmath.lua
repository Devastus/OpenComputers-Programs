local LIB = {}

function LIB.mod(value, max)
    return (value + max) % max
end

function LIB.clamp(value, min, max)
    return math.max(math.min(value, max), min)
end

function LIB.sign(value)
    if value == math.abs(value) then
        return 1
    else
        return -1
    end
end

function LIB.round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

function LIB.lerp(a, b, t)
    return (1-t) * a + t * b
end

return LIB