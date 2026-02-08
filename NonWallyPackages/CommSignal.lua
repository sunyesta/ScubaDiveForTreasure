local CommSignal = {}

function CommSignal.new(comm) end

function CommSignal:Fire() end

-- You can connect to comm signal from the server or the client

return CommSignal
