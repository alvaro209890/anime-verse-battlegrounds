--!strict
-- InventoryService (server) — mochila F0 (docs/05 §6.5).
-- Só empilháveis. Sem trade, drop, forja ou bônus de combate.
-- Puro (sem Instances) — testável.

export type InventoryDeps = {
	getItem: (string) -> any?,
	capacity: number?,
}

export type Bag = {
	capacity: number,
	stackables: { [string]: number },
	revision: number,
}

export type GrantResult = {
	granted: number,
	reason: string?,
}

local InventoryService = {
	deps = nil :: InventoryDeps?,
	bags = {} :: { [number]: Bag },
}

local DEFAULT_CAPACITY = 30

function InventoryService.init(deps: InventoryDeps): ()
	InventoryService.deps = deps
	table.clear(InventoryService.bags)
end

local function emptyBag(): Bag
	local deps = InventoryService.deps
	return {
		capacity = if deps and deps.capacity then deps.capacity else DEFAULT_CAPACITY,
		stackables = {},
		revision = 0,
	}
end

function InventoryService.registerPlayer(userId: number): ()
	if not InventoryService.bags[userId] then
		InventoryService.bags[userId] = emptyBag()
	end
end

function InventoryService.unregisterPlayer(userId: number): ()
	InventoryService.bags[userId] = nil
end

function InventoryService.getBag(userId: number): Bag?
	return InventoryService.bags[userId]
end

function InventoryService.count(userId: number, itemId: string): number
	local bag = InventoryService.bags[userId]
	if not bag then
		return 0
	end
	return bag.stackables[itemId] or 0
end

function InventoryService.distinctCount(userId: number): number
	local bag = InventoryService.bags[userId]
	if not bag then
		return 0
	end
	local n = 0
	for _ in bag.stackables do
		n += 1
	end
	return n
end

function InventoryService.grant(userId: number, itemId: string, amount: number): GrantResult
	local deps = InventoryService.deps
	local bag = InventoryService.bags[userId]
	if not deps or not bag then
		return { granted = 0, reason = "unknown_player" }
	end
	if amount ~= amount or amount < 1 or amount ~= math.floor(amount) then
		return { granted = 0, reason = "invalid_amount" }
	end
	local def = deps.getItem(itemId)
	if not def or def.enabled ~= true then
		return { granted = 0, reason = "unknown_item" }
	end
	local current = bag.stackables[itemId] or 0
	if current <= 0 and InventoryService.distinctCount(userId) >= bag.capacity then
		return { granted = 0, reason = "bag_full" }
	end
	local room = def.stackLimit - current
	if room <= 0 then
		return { granted = 0, reason = "stack_cap" }
	end
	local granted = math.min(amount, room)
	bag.stackables[itemId] = current + granted
	bag.revision += 1
	return {
		granted = granted,
		reason = if granted < amount then "stack_cap" else nil,
	}
end

function InventoryService.snapshot(userId: number): Bag?
	local bag = InventoryService.bags[userId]
	if not bag then
		return nil
	end
	local stacks: { [string]: number } = {}
	for itemId, count in bag.stackables do
		if count > 0 then
			stacks[itemId] = count
		end
	end
	return {
		capacity = bag.capacity,
		stackables = stacks,
		revision = bag.revision,
	}
end

function InventoryService.restore(userId: number, snapshot: any): ()
	InventoryService.registerPlayer(userId)
	local bag = InventoryService.bags[userId]
	local deps = InventoryService.deps
	if not bag or not deps or type(snapshot) ~= "table" then
		return
	end
	local stacks: { [string]: number } = {}
	if type(snapshot.stackables) == "table" then
		for itemId, count in snapshot.stackables do
			if type(itemId) == "string" and type(count) == "number" and count == count and count >= 1 then
				local def = deps.getItem(itemId)
				if def and def.enabled then
					stacks[itemId] = math.min(def.stackLimit, math.floor(count))
				end
			end
		end
	end
	bag.stackables = stacks
	bag.revision = if type(snapshot.revision) == "number" then math.max(0, math.floor(snapshot.revision)) else 0
end

function InventoryService.list(userId: number): { { id: string, count: number } }
	local bag = InventoryService.bags[userId]
	local out: { { id: string, count: number } } = {}
	if not bag then
		return out
	end
	for itemId, count in bag.stackables do
		if count > 0 then
			table.insert(out, { id = itemId, count = count })
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

return InventoryService
