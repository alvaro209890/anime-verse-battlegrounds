-- Contrato puro para descobrir vínculos de interação em modelos do mundo.
--
-- O WorldService materializa Instances e não é executado pelo Lune. Este módulo
-- mantém a regra de descoberta isolada: qualquer Model que exponha
-- `GetDescendants`, e qualquer BasePart que exponha `IsA`/`GetAttribute`, pode
-- ser verificado em um teste simulado sem Roblox Studio.

export type BindingModel = {
	GetDescendants: (self: any) -> { any },
}

local InteractionBinding = {}

function InteractionBinding.countNpcBindings(model: BindingModel?, npcId: string): (number, string?)
	if not model or type(model.GetDescendants) ~= "function" then
		return 0, nil
	end

	local count = 0
	local boundPartName: string? = nil
	for _, descendant in model:GetDescendants() do
		if
			descendant
			and type(descendant.IsA) == "function"
			and descendant:IsA("BasePart")
			and type(descendant.GetAttribute) == "function"
			and descendant:GetAttribute("InteractionNpcId") == npcId
		then
			count += 1
			boundPartName = descendant.Name
		end
	end
	return count, boundPartName
end

function InteractionBinding.isUniqueNpcBinding(model: BindingModel?, npcId: string): (boolean, number, string?)
	local count, boundPartName = InteractionBinding.countNpcBindings(model, npcId)
	return count == 1, count, boundPartName
end

return InteractionBinding
