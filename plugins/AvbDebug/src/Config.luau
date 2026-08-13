--!nonstrict
-- Configuração do plugin de debug (AVB Debug Bridge).
-- Tudo local: a ponte só fala com 127.0.0.1, nunca com a internet.

local Config = {
	version = "1.0.0",
	-- Porta do bridge (scripts/debug-bridge.luau). Trocar aqui e no bridge.
	bridgeUrl = "http://127.0.0.1:34873",
	pollIntervalSeconds = 0.5,
	-- Backoff quando o bridge está desligado (evita spam de erro no Output).
	offlineIntervalSeconds = 3,
	logFlushIntervalSeconds = 0.5,
	logBufferSize = 800,
	logBatchSize = 120,
	maxTreeNodes = 4000,
	maxDepth = 6,
}

return Config
