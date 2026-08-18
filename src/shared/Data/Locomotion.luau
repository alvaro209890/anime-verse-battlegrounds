--!strict
-- Velocidades de locomoção F0-BASELINE (docs/13-F0-SLICE.md §5).
-- Caminhada 16 / corrida 22 studs/s. O cliente troca Humanoid.WalkSpeed ao
-- segurar Shift/L3 ou ao travar o botão CORRER; o servidor NUNCA confia no
-- WalkSpeed replicado acima de `runSpeed` para o envelope de movimento.

local Locomotion = {
	walkSpeed = 16,
	runSpeed = 22,
}

function Locomotion.clampAuthorizedSpeed(claimedSpeed: number): number
	if type(claimedSpeed) ~= "number" or claimedSpeed ~= claimedSpeed or claimedSpeed < 0 then
		return Locomotion.walkSpeed
	end
	if claimedSpeed > Locomotion.runSpeed then
		return Locomotion.runSpeed
	end
	return claimedSpeed
end

function Locomotion.speedForSprinting(sprinting: boolean): number
	return if sprinting then Locomotion.runSpeed else Locomotion.walkSpeed
end

function Locomotion.validate(): (boolean, string?)
	if Locomotion.walkSpeed <= 0 or Locomotion.runSpeed <= 0 then
		return false, "speeds_must_be_positive"
	end
	if Locomotion.runSpeed < Locomotion.walkSpeed then
		return false, "run_slower_than_walk"
	end
	if Locomotion.clampAuthorizedSpeed(100) ~= Locomotion.runSpeed then
		return false, "clamp_failed"
	end
	if Locomotion.clampAuthorizedSpeed(-1) ~= Locomotion.walkSpeed then
		return false, "invalid_fallback_failed"
	end
	if Locomotion.speedForSprinting(true) ~= Locomotion.runSpeed then
		return false, "sprint_speed_mismatch"
	end
	if Locomotion.speedForSprinting(false) ~= Locomotion.walkSpeed then
		return false, "walk_speed_mismatch"
	end
	return true, nil
end

return Locomotion
