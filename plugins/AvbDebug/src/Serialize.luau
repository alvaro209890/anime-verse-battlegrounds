--!nonstrict
-- Serialização JSON-safe para o bridge.
-- HttpService:JSONEncode explode com Instance/Vector3/CFrame/Enum; aqui tudo
-- vira tabela/string previsível para o agente do outro lado consumir.

local Serialize = {}

local MAX_TABLE_DEPTH = 6
local MAX_ARRAY_ITEMS = 400

local function round(value: number, places: number?): number
	local factor = 10 ^ (places or 3)
	return math.floor(value * factor + 0.5) / factor
end

function Serialize.vector3(v: Vector3): { x: number, y: number, z: number }
	return { x = round(v.X), y = round(v.Y), z = round(v.Z) }
end

function Serialize.cframe(cf: CFrame)
	local rx, ry, rz = cf:ToOrientation()
	return {
		position = Serialize.vector3(cf.Position),
		orientationDegrees = {
			x = round(math.deg(rx), 2),
			y = round(math.deg(ry), 2),
			z = round(math.deg(rz), 2),
		},
	}
end

function Serialize.color3(c: Color3)
	return {
		r = math.round(c.R * 255),
		g = math.round(c.G * 255),
		b = math.round(c.B * 255),
		hex = string.format("#%02X%02X%02X", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255)),
	}
end

function Serialize.instanceRef(instance: Instance)
	local ok, fullName = pcall(function()
		return instance:GetFullName()
	end)
	return {
		__type = "Instance",
		path = ok and fullName or instance.Name,
		className = instance.ClassName,
		name = instance.Name,
	}
end

-- Converte qualquer valor Roblox em algo que sobrevive ao JSONEncode.
function Serialize.value(value: any, depth: number?): any
	local level = depth or 0
	local kind = typeof(value)

	if value == nil then
		return nil
	elseif kind == "string" or kind == "boolean" then
		return value
	elseif kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return tostring(value)
		end
		return round(value, 4)
	elseif kind == "Instance" then
		return Serialize.instanceRef(value)
	elseif kind == "Vector3" then
		return Serialize.vector3(value)
	elseif kind == "Vector2" then
		return { x = round(value.X), y = round(value.Y) }
	elseif kind == "CFrame" then
		return Serialize.cframe(value)
	elseif kind == "Color3" then
		return Serialize.color3(value)
	elseif kind == "BrickColor" then
		return { name = value.Name, color = Serialize.color3(value.Color) }
	elseif kind == "UDim2" then
		return {
			x = { scale = round(value.X.Scale, 4), offset = value.X.Offset },
			y = { scale = round(value.Y.Scale, 4), offset = value.Y.Offset },
		}
	elseif kind == "UDim" then
		return { scale = round(value.Scale, 4), offset = value.Offset }
	elseif kind == "EnumItem" then
		return tostring(value)
	elseif kind == "Enum" or kind == "Enums" then
		return tostring(value)
	elseif kind == "NumberRange" then
		return { min = round(value.Min), max = round(value.Max) }
	elseif kind == "Ray" then
		return { origin = Serialize.vector3(value.Origin), direction = Serialize.vector3(value.Direction) }
	elseif kind == "Region3" then
		return { cframe = Serialize.cframe(value.CFrame), size = Serialize.vector3(value.Size) }
	elseif kind == "function" or kind == "thread" or kind == "userdata" then
		return "<" .. kind .. ">"
	elseif kind ~= "table" then
		return tostring(value)
	end

	if level >= MAX_TABLE_DEPTH then
		return "<table: profundidade máxima>"
	end

	local arrayLength = #value
	local isArray = arrayLength > 0
	if isArray then
		for key in value do
			if type(key) ~= "number" then
				isArray = false
				break
			end
		end
	end

	if isArray then
		local out = {}
		local limit = math.min(arrayLength, MAX_ARRAY_ITEMS)
		for index = 1, limit do
			out[index] = Serialize.value(value[index], level + 1)
		end
		if arrayLength > limit then
			out[limit + 1] = string.format("<+%d itens omitidos>", arrayLength - limit)
		end
		return out
	end

	local out = {}
	local count = 0
	for key, item in value do
		count += 1
		if count > MAX_ARRAY_ITEMS then
			out["__truncated"] = true
			break
		end
		out[tostring(key)] = Serialize.value(item, level + 1)
	end
	if next(out) == nil then
		-- JSONEncode transforma tabela vazia em array; marcar para o agente.
		return {}
	end
	return out
end

return Serialize
