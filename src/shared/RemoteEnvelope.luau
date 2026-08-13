--!strict
-- Envelope v2 das intenções C→S (docs/13-F0-SLICE.md §13).
-- Timestamp do cliente não faz parte do contrato e nunca autoriza janela.

export type Envelope = {
	protocolVersion: number,
	requestId: string,
	clientSequence: number,
	action: string,
	payload: { [string]: any },
}

local PROTOCOL_VERSION = 2

local RemoteEnvelope = {}

function RemoteEnvelope.version(): number
	return PROTOCOL_VERSION
end

function RemoteEnvelope.create(
	action: string,
	payload: { [string]: any },
	requestId: string,
	clientSequence: number
): Envelope
	return {
		protocolVersion = PROTOCOL_VERSION,
		requestId = requestId,
		clientSequence = clientSequence,
		action = action,
		payload = payload,
	}
end

function RemoteEnvelope.decode(value: any, expectedAction: string?): ({ [string]: any }?, string?)
	if type(value) ~= "table" then
		return nil, "not_table"
	end
	if value.protocolVersion ~= PROTOCOL_VERSION then
		return nil, "protocol_version"
	end
	if type(value.requestId) ~= "string" or value.requestId == "" then
		return nil, "request_id"
	end
	if type(value.clientSequence) ~= "number" or value.clientSequence < 1 or value.clientSequence % 1 ~= 0 then
		return nil, "client_sequence"
	end
	if type(value.action) ~= "string" or value.action == "" then
		return nil, "action"
	end
	if expectedAction and value.action ~= expectedAction then
		return nil, "action_mismatch"
	end
	if type(value.payload) ~= "table" then
		return nil, "payload"
	end
	return value.payload, nil
end

return RemoteEnvelope
