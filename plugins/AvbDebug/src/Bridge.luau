--!nonstrict
-- Cliente HTTP do bridge local (scripts/debug-bridge.luau).
-- Plugins do Studio podem usar HttpService mesmo com "Allow HTTP Requests"
-- desligado no place; o alvo aqui é sempre 127.0.0.1.

local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Config)

local Bridge = {}

Bridge.online = false
Bridge.lastError = nil :: string?

local function request(method: string, path: string, body: any?): (boolean, any)
	local options = {
		Url = Config.bridgeUrl .. path,
		Method = method,
		Headers = { ["Content-Type"] = "application/json" },
	}
	if body ~= nil then
		local encodeOk, encoded = pcall(function()
			return HttpService:JSONEncode(body)
		end)
		if not encodeOk then
			return false, "falha ao serializar payload: " .. tostring(encoded)
		end
		options.Body = encoded
	end

	local ok, response = pcall(function()
		return HttpService:RequestAsync(options)
	end)
	if not ok then
		Bridge.online = false
		Bridge.lastError = tostring(response)
		return false, tostring(response)
	end
	if not response.Success then
		Bridge.online = false
		Bridge.lastError = string.format("HTTP %d: %s", response.StatusCode, tostring(response.Body))
		return false, Bridge.lastError
	end

	Bridge.online = true
	Bridge.lastError = nil
	if response.Body == nil or response.Body == "" then
		return true, {}
	end
	local decodeOk, decoded = pcall(function()
		return HttpService:JSONDecode(response.Body)
	end)
	if not decodeOk then
		return false, "resposta não-JSON do bridge: " .. tostring(decoded)
	end
	return true, decoded
end

function Bridge.hello(payload: any): (boolean, any)
	return request("POST", "/studio/hello", payload)
end

function Bridge.poll(): (boolean, any)
	return request("GET", "/studio/poll", nil)
end

function Bridge.result(payload: any): (boolean, any)
	return request("POST", "/studio/result", payload)
end

function Bridge.logs(entries: { any }): (boolean, any)
	return request("POST", "/studio/logs", { entries = entries })
end

return Bridge
