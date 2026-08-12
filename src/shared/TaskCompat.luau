--!strict
-- TaskCompat — compatibilidade de task entre Roblox e testes Lune.
--
-- No Roblox, `task` é uma global nativa (spawn/defer/wait/delay).
-- No Lune (testes), `task` é declarada local nil em cada módulo — este módulo
-- faz fallback para _G.task (polyfill injetado pelo tests/harness.luau).
-- Se nem um nem outro existir, usa implementação mínima síncrona.

local nativeTask = task

local TaskCompat = nativeTask

if not TaskCompat then
	local polyfill: any = _G.task
	TaskCompat = polyfill
end

if not TaskCompat then
	TaskCompat = {
		spawn = function(fn: () -> ())
			fn()
			return nil
		end,
		defer = function(fn: () -> ())
			fn()
			return nil
		end,
		wait = function(seconds: number): number
			local start = os.clock()
			while os.clock() - start < seconds do
				-- busy-wait mínimo (só fora do Roblox)
			end
			return seconds
		end,
		delay = function(seconds: number, fn: () -> ())
			TaskCompat.wait(seconds)
			fn()
		end,
	}
end

return TaskCompat
