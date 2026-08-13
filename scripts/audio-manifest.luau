--!strict
-- Manifesto de upload de áudio — lista exatamente quais arquivos .ogg do
-- catálogo precisam ser publicados no Roblox e quais já têm assetId.
--
-- Uso: lune run scripts/audio-manifest.luau
--
-- Existe porque o Roblox não reproduz arquivo local: Sound.SoundId exige
-- rbxassetid://<id> de asset publicado. Este script transforma "subir os sons"
-- numa lista fechada e conferível, em vez de caçar arquivo por arquivo.

local fs = require("@lune/fs")
local process = require("@lune/process")

-- O catálogo é um módulo Luau puro; o harness resolve os requires relativos.
local CombatAudio = require("../src/shared/Data/CombatAudio")

local ok, reason = CombatAudio.validate()
if not ok then
	print(("catálogo inválido: %s"):format(tostring(reason)))
	process.exit(1)
end

local cues = CombatAudio.all()
table.sort(cues, function(a, b)
	return a.id < b.id
end)

local pending = 0
local published = 0
local missingFiles: { string } = {}

print("# Manifesto de áudio de combate\n")
print(("%-26s  %-10s  %s"):format("DEIXA", "STATUS", "ARQUIVO DE ORIGEM"))
print(string.rep("-", 96))

for _, cue in cues do
	local status
	if cue.assetId ~= "" then
		status = "publicado"
		published += 1
	else
		status = "PENDENTE"
		pending += 1
	end
	print(("%-26s  %-10s  %s"):format(cue.id, status, cue.sourceFile))
	for _, variant in cue.variantFiles do
		print(("%-26s  %-10s  %s"):format("", "", variant .. "  (variante)"))
	end
end

for _, path in CombatAudio.sourceFiles() do
	if not fs.isFile(path) then
		table.insert(missingFiles, path)
	end
end

local files = CombatAudio.sourceFiles()
print("")
print(("Deixas: %d publicadas, %d pendentes"):format(published, pending))
print(("Arquivos distintos a publicar: %d"):format(#files))

if #missingFiles > 0 then
	print("\nARQUIVOS AUSENTES NO DISCO:")
	for _, path in missingFiles do
		print("  " .. path)
	end
	process.exit(1)
end

if pending > 0 then
	print("\nPróximo passo: publicar os arquivos acima e preencher `assetId`")
	print("em src/shared/Data/CombatAudio.luau no formato rbxassetid://<id>.")
	print("Enquanto o assetId estiver vazio a deixa é ignorada em silêncio.")
end
