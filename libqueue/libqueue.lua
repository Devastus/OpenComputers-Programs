local QUEUE = {}

function QUEUE.new()
    return {first = 0, last = -1, values={}}
end

function QUEUE.pushleft(self, value)
    local first = self.first - 1
    self.first = first
    self.values[first] = value
end

function QUEUE.pushright(self, value)
    local last = self.last + 1
    self.last = last
    self.values[last] = value
end

function QUEUE.popleft(self)
    local first = self.first
    if first > self.last then error("Queue is empty") return nil end
    local value = self.values[first]
    self.values[first] = nil
    self.first = first + 1
    return value
end

function QUEUE.popright(self)
    local last = self.last
    if last < self.first then error("Queue is empty") return nil end
    local value = self.values[last]
    self.values[last] = nil
    self.last = last - 1
    return value
end

return QUEUE
