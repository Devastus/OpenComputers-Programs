local QUEUE = {}

local function pushleft(self, value)
    local first = self.first - 1
    self.first = first
    self.values[first] = value
    if self.limit > 0 and #self.values > self.limit then
        return self:popright()
    end
end

local function pushright(self, value)
    local last = self.last + 1
    self.last = last
    self.values[last] = value
    if self.limit > 0 and #self.values > self.limit then
        return self:popleft()
    end
end

local function popleft(self)
    local first = self.first
    if first > self.last then error("Queue is empty") return nil end
    local value = self.values[first]
    self.values[first] = nil
    self.first = first + 1
    return value
end

local function popright(self)
    local last = self.last
    if last < self.first then error("Queue is empty") return nil end
    local value = self.values[last]
    self.values[last] = nil
    self.last = last - 1
    return value
end

local function clear(self)
    self.first = 0
    self.last = -1
    self.values = {}
end

function QUEUE.new(queueLimit)
    local limit = queueLimit or 0
    local newQ = {first = 0, last = -1, limit = limit, values={}}
    newQ.pushright = pushright
    newQ.pushleft = pushleft
    newQ.popright = popright
    newQ.popleft = popleft
    newQ.clear = clear
    return newQ
end

return QUEUE
