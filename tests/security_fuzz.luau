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

-- Relógio injetado e MUTÁVEL: a janela de rate limit é de 1 s e não dá para
-- exercitar reset com `os.clock` real sem dormir no teste.
local fuzzNow = 100
SecurityService.init({
	decode = RemoteEnvelope.decode,
	now = function()
		return fuzzNow
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

-- ── Envelope hostil: tamanho, sequência e forma ─────────────────────────────

expectRejected(
	"requestId gigante",
	720,
	"AbilityIntent",
	RemoteEnvelope.create("AbilityIntent", {
		abilityId = "comet_shoulder",
		inputMode = "Press",
		executionId = "big-id",
		phase = "press",
	}, string.rep("a", 81), 1),
	"envelope_size"
)
expectRejected(
	"sequência acima do teto seguro",
	721,
	"AbilityIntent",
	RemoteEnvelope.create("AbilityIntent", {
		abilityId = "comet_shoulder",
		inputMode = "Press",
		executionId = "huge-seq",
		phase = "press",
	}, "huge-seq", 9007199254740992),
	"envelope_size"
)
expectRejected(
	"sequência infinita",
	722,
	"AbilityIntent",
	RemoteEnvelope.create("AbilityIntent", {
		abilityId = "comet_shoulder",
		inputMode = "Press",
		executionId = "inf-seq",
		phase = "press",
	}, "inf-seq", math.huge),
	"client_sequence"
)
expectRejected(
	"sequência negativa",
	723,
	"AbilityIntent",
	RemoteEnvelope.create("AbilityIntent", {
		abilityId = "comet_shoulder",
		inputMode = "Press",
		executionId = "neg-seq",
		phase = "press",
	}, "neg-seq", -5),
	"client_sequence"
)

-- ── Fuzz aninhado: tabela onde o schema espera escalar ──────────────────────
-- O padrão hostil clássico é trocar um campo simples por estrutura, contando
-- que a validação só olhe o nome da chave.

expectRejected(
	"abilityId como tabela",
	724,
	"AbilityIntent",
	RemoteEnvelope.create("AbilityIntent", {
		abilityId = { "comet_shoulder" },
		inputMode = "Press",
		executionId = "nested-ability",
		phase = "press",
	}, "nested-ability", 1),
	"payload_schema"
)
expectRejected(
	"mira com terceiro eixo",
	725,
	"AbilityIntent",
	RemoteEnvelope.create("AbilityIntent", {
		abilityId = "comet_shoulder",
		inputMode = "Press",
		executionId = "aim-y",
		phase = "press",
		aim = { x = 0.7, z = 0.7, y = 99 },
	}, "aim-y", 1),
	"payload_schema"
)
expectRejected(
	"mira NaN",
	726,
	"AbilityIntent",
	RemoteEnvelope.create("AbilityIntent", {
		abilityId = "comet_shoulder",
		inputMode = "Press",
		executionId = "aim-nan",
		phase = "press",
		aim = { x = 0 / 0, z = 1 },
	}, "aim-nan", 1),
	"payload_schema"
)
expectRejected(
	"direção do dash aninhada",
	727,
	"DashIntent",
	RemoteEnvelope.create("DashIntent", {
		direction = { x = { 1 }, z = 0 },
	}, "nested-dash", 1),
	"payload_schema"
)
expectRejected(
	"direção do dash com campo extra",
	728,
	"DashIntent",
	RemoteEnvelope.create("DashIntent", {
		direction = { x = 1, z = 0, magnitude = 50 },
	}, "extra-dash", 1),
	"payload_schema"
)
expectRejected(
	"payload com nove chaves",
	729,
	"BasicAttackIntent",
	RemoteEnvelope.create("BasicAttackIntent", {
		kind = "light",
		phase = "press",
		a = 1,
		b = 2,
		c = 3,
		d = 4,
		e = 5,
		f = 6,
		g = 7,
	}, "nine-keys", 1),
	"payload_schema"
)
expectRejected(
	"npcId como tabela na interação",
	730,
	"InteractionIntent",
	RemoteEnvelope.create("InteractionIntent", {
		npcId = { id = "npc_threshold_instructor" },
		phase = "complete",
	}, "nested-npc", 1),
	"payload_schema"
)

-- ── Hold de fronteira adulterado ────────────────────────────────────────────
-- O cliente NUNCA declara que segurou: quem mede os 0,6 s é o servidor
-- (`ZoneService.handleCrossingHold`, coberto em tests/run.luau). O schema do
-- `ZoneCrossingIntent` aceita só `toZoneId` e `phase`, então a tentativa de
-- declarar o hold morre no envelope, antes de qualquer serviço.

expectRejected(
	"hold declarado pelo cliente",
	731,
	"ZoneCrossingIntent",
	RemoteEnvelope.create("ZoneCrossingIntent", {
		toZoneId = "zone_threshold_transition",
		phase = "complete",
		holdConfirmed = true,
	}, "hold-declared", 1),
	"payload_schema"
)
expectRejected(
	"hold com duração declarada",
	732,
	"ZoneCrossingIntent",
	RemoteEnvelope.create("ZoneCrossingIntent", {
		toZoneId = "zone_threshold_transition",
		phase = "complete",
		heldSeconds = 99,
	}, "hold-seconds", 1),
	"payload_schema"
)
expectRejected(
	"zona com caminho hostil",
	733,
	"ZoneCrossingIntent",
	RemoteEnvelope.create("ZoneCrossingIntent", {
		toZoneId = "../../zone_plain_free",
		phase = "complete",
	}, "hold-path", 1),
	"payload_schema"
)
expectRejected(
	"fase de travessia inventada",
	734,
	"ZoneCrossingIntent",
	RemoteEnvelope.create("ZoneCrossingIntent", {
		toZoneId = "zone_threshold_transition",
		phase = "teleport",
	}, "hold-phase", 1),
	"payload_schema"
)
check(
	"travessia bem formada é aceita",
	SecurityService.inspect(
		735,
		"ZoneCrossingIntent",
		RemoteEnvelope.create("ZoneCrossingIntent", {
			toZoneId = "zone_threshold_transition",
			phase = "begin",
		}, "hold-ok", 1)
	) ~= nil
)

-- ── Rate limit por CLASSE, não por contrato ─────────────────────────────────
-- Combate tem 8/s; o resto tem 15/s num orçamento separado. Esgotar o combate
-- não pode calar interação, e vice-versa.

for sequence = 1, 8 do
	local attack = RemoteEnvelope.create(
		"BasicAttackIntent",
		{ kind = "light", phase = "press" },
		("class-combat-%d"):format(sequence),
		sequence
	)
	check(
		("classe combate: %d/8 permitido"):format(sequence),
		SecurityService.inspect(740, "BasicAttackIntent", attack) ~= nil
	)
end
expectRejected(
	"classe combate: 9º recusado",
	740,
	"GuardIntent",
	RemoteEnvelope.create("GuardIntent", { phase = "down" }, "class-combat-9", 9),
	"rate_limited"
)
check(
	"interação continua no orçamento próprio",
	SecurityService.inspect(
		740,
		"InteractionIntent",
		RemoteEnvelope.create("InteractionIntent", {
			npcId = "npc_threshold_instructor",
			phase = "begin",
		}, "class-default-1", 10)
	) ~= nil
)

-- Janela de 1 s: o orçamento reabre sozinho, sem rejoin.
fuzzNow = 101.5
check(
	"janela nova reabre o orçamento de combate",
	SecurityService.inspect(
		740,
		"BasicAttackIntent",
		RemoteEnvelope.create("BasicAttackIntent", { kind = "light", phase = "press" }, "class-window", 11)
	) ~= nil
)
fuzzNow = 100

-- ── Replay combinado (fuzz aninhado de casos) ───────────────────────────────

local crossContract = RemoteEnvelope.create("AbilityIntent", {
	abilityId = "comet_shoulder",
	inputMode = "Press",
	executionId = "cross",
	phase = "press",
}, "cross-contract", 1)
check("primeiro uso do requestId é aceito", SecurityService.inspect(750, "AbilityIntent", crossContract) ~= nil)
expectRejected(
	"mesmo requestId em OUTRO contrato",
	750,
	"BasicAttackIntent",
	RemoteEnvelope.create("BasicAttackIntent", { kind = "light", phase = "press" }, "cross-contract", 2),
	"replay_request"
)

for sequence = 1, 5 do
	local ok = SecurityService.inspect(
		751,
		"BasicAttackIntent",
		RemoteEnvelope.create(
			"BasicAttackIntent",
			{ kind = "light", phase = "press" },
			("ordered-%d"):format(sequence),
			sequence
		)
	)
	check(("sequência crescente %d aceita"):format(sequence), ok ~= nil)
end
expectRejected(
	"volta no tempo depois de cinco válidas",
	751,
	"BasicAttackIntent",
	RemoteEnvelope.create("BasicAttackIntent", { kind = "light", phase = "press" }, "ordered-back", 3),
	"replay_sequence"
)
check(
	"salto para a frente continua aceito",
	SecurityService.inspect(
		751,
		"BasicAttackIntent",
		RemoteEnvelope.create("BasicAttackIntent", { kind = "light", phase = "press" }, "ordered-jump", 5000)
	) ~= nil
)

-- Payload hostil + replay na mesma investida: a recusa de schema NÃO consome a
-- sequência, então o cliente honesto não fica travado por causa do ataque.
expectRejected(
	"schema inválido no meio da sessão",
	751,
	"BasicAttackIntent",
	RemoteEnvelope.create("BasicAttackIntent", { kind = "teleport", phase = "press" }, "hostile-mid", 5001),
	"payload_schema"
)
check(
	"sequência seguinte legítima ainda passa",
	SecurityService.inspect(
		751,
		"BasicAttackIntent",
		RemoteEnvelope.create("BasicAttackIntent", { kind = "light", phase = "press" }, "legit-after", 5001)
	) ~= nil
)

print(("Resultado fuzz: %d passaram, %d falharam"):format(passed, failed))
if failed > 0 then
	error("fuzz de segurança falhou")
end
