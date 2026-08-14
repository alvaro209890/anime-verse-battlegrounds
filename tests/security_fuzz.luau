--!strict
-- Fuzz determinístico dos contratos de segurança F0.
-- Uso: lune run tests/security_fuzz.luau
-- Este arquivo não simula Instances, rede ou física; ele procura regressões nos
-- limites puros de envelope, schema, replay, sequência e rate limit.

require("./harness")

local RemoteEnvelope = require("../src/shared/RemoteEnvelope")
local SecurityService = require("../src/server/Services/SecurityService")

local passed = 0
local failed = 0

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		print(("[ok]   %s"):format(name))
	else
		failed += 1
		print(("[FAIL] %s — %s"):format(name, detail or "condição falsa"))
	end
end

local function expectRejected(name: string, userId: number, contract: string, envelope: any, expectedReason: string)
	local payload, reason = SecurityService.inspect(userId, contract, envelope)
	check(
		name,
		payload == nil and reason == expectedReason,
		("esperado %s, obtido %s"):format(expectedReason, tostring(reason))
	)
end

SecurityService.init({
	decode = RemoteEnvelope.decode,
	now = function()
		return 100
	end,
})

expectRejected("não-tabela", 700, "AbilityIntent", "hostile", "envelope_schema")
expectRejected("versão antiga", 701, "AbilityIntent", {
	protocolVersion = 1,
	requestId = "v1",
	clientSequence = 1,
	action = "AbilityIntent",
	payload = {},
}, "protocol_version")
expectRejected("request vazio", 702, "AbilityIntent", RemoteEnvelope.create("AbilityIntent", {}, "", 1), "request_id")
expectRejected(
	"sequência zero",
	703,
	"AbilityIntent",
	RemoteEnvelope.create("AbilityIntent", {}, "zero", 0),
	"client_sequence"
)
expectRejected(
	"sequência fracionária",
	704,
	"AbilityIntent",
	RemoteEnvelope.create("AbilityIntent", {}, "fraction", 1.5),
	"client_sequence"
)
expectRejected("ação vazia", 705, "AbilityIntent", RemoteEnvelope.create("", {}, "action", 1), "action")
expectRejected(
	"ação divergente",
	706,
	"AbilityIntent",
	RemoteEnvelope.create("BasicAttackIntent", {}, "mismatch", 1),
	"action_mismatch"
)
expectRejected("payload não-tabela", 707, "AbilityIntent", {
	protocolVersion = 2,
	requestId = "payload",
	clientSequence = 1,
	action = "AbilityIntent",
	payload = "hostile",
}, "payload")

local extraEnvelope = RemoteEnvelope.create("AbilityIntent", {
	abilityId = "comet_shoulder",
	inputMode = "Press",
	executionId = "fuzz-extra-envelope",
	phase = "press",
}, "extra-envelope", 1)
extraEnvelope.clientTimestamp = 999999
expectRejected("campo extra no envelope", 708, "AbilityIntent", extraEnvelope, "envelope_schema")

local extraPayload = RemoteEnvelope.create("AbilityIntent", {
	abilityId = "comet_shoulder",
	inputMode = "Press",
	executionId = "fuzz-extra-payload",
	phase = "press",
	damage = 999999,
}, "extra-payload", 1)
expectRejected("campo extra no payload", 709, "AbilityIntent", extraPayload, "payload_schema")

expectRejected(
	"ability desconhecida",
	710,
	"AbilityIntent",
	RemoteEnvelope.create("AbilityIntent", {
		abilityId = "../../admin",
		inputMode = "Press",
		executionId = "unknown",
		phase = "press",
	}, "bad-ability", 1),
	"payload_schema"
)
expectRejected(
	"input mode inválido",
	711,
	"AbilityIntent",
	RemoteEnvelope.create("AbilityIntent", {
		abilityId = "comet_shoulder",
		inputMode = "Execute",
		executionId = "bad-mode",
		phase = "press",
	}, "bad-mode", 1),
	"payload_schema"
)
expectRejected(
	"mira impossível",
	712,
	"AbilityIntent",
	RemoteEnvelope.create("AbilityIntent", {
		abilityId = "comet_shoulder",
		inputMode = "Press",
		executionId = "bad-aim",
		phase = "press",
		aim = { x = 9, z = 0 },
	}, "bad-aim", 1),
	"payload_schema"
)
expectRejected(
	"dash neutro",
	713,
	"DashIntent",
	RemoteEnvelope.create("DashIntent", {
		direction = { x = 0, z = 0 },
	}, "neutral-dash", 1),
	"payload_schema"
)
expectRejected(
	"interação ambígua",
	714,
	"InteractionIntent",
	RemoteEnvelope.create("InteractionIntent", {
		npcId = "npc_threshold_instructor",
		anchorId = "anchor_return",
		phase = "complete",
	}, "ambiguous-interaction", 1),
	"payload_schema"
)

local valid = RemoteEnvelope.create("AbilityIntent", {
	abilityId = "comet_shoulder",
	inputMode = "Press",
	executionId = "valid",
	phase = "press",
}, "valid-request", 1)
check("intenção válida aceita", SecurityService.inspect(715, "AbilityIntent", valid) ~= nil)
local replayRequest = RemoteEnvelope.create("AbilityIntent", valid.payload, "valid-request", 2)
expectRejected("requestId repetido", 715, "AbilityIntent", replayRequest, "replay_request")
local replaySequence = RemoteEnvelope.create("AbilityIntent", valid.payload, "new-request", 1)
expectRejected("sequência atrasada", 715, "AbilityIntent", replaySequence, "replay_sequence")

for sequence = 1, 8 do
	local attack = RemoteEnvelope.create(
		"BasicAttackIntent",
		{ kind = "light", phase = "press" },
		("burst-%d"):format(sequence),
		sequence
	)
	check(("burst permitido %d"):format(sequence), SecurityService.inspect(716, "BasicAttackIntent", attack) ~= nil)
end
local burstRejected = RemoteEnvelope.create("BasicAttackIntent", { kind = "light", phase = "press" }, "burst-9", 9)
expectRejected("burst acima de 8/s", 716, "BasicAttackIntent", burstRejected, "rate_limited")
local otherUser = RemoteEnvelope.create("BasicAttackIntent", { kind = "light", phase = "press" }, "other-user", 1)
check("rate limit isolado por usuário", SecurityService.inspect(717, "BasicAttackIntent", otherUser) ~= nil)
SecurityService.clearPlayer(716)
local rejoin = RemoteEnvelope.create("BasicAttackIntent", { kind = "light", phase = "press" }, "rejoin", 1)
check("clearPlayer libera novo burst", SecurityService.inspect(716, "BasicAttackIntent", rejoin) ~= nil)

print(("Resultado fuzz: %d passaram, %d falharam"):format(passed, failed))
if failed > 0 then
	error("fuzz de segurança falhou")
end
