-- Queues visual effects and sends them to every client once per frame.
-- The server only decides what happened; clients draw it (see client/Effects.lua).
local Fx = {}
local queue = {}
local remote

function Fx.init(r)
	remote = r
end

function Fx.emit(kind, data)
	data.k = kind
	table.insert(queue, data)
end

function Fx.flush()
	if #queue > 0 then
		remote:FireAllClients(queue)
		queue = {}
	end
end

return Fx
