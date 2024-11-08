local ROUND = {}
ROUND.Name = "Speed Demons"
ROUND.Description = "Everyone moves at hyperspeed and jumps higher!"

local TAG = "ChaosRoundSpeedDemons"

-- Configuration
local SPEED_MULTIPLIER = 2
local DAMAGE_MULTIPLIER = 0.7

if SERVER then
	function ROUND:Start()
		-- Increase player speeds
		for _, ply in ipairs(player.GetAll()) do
			if not ply:IsTerror() then continue end

			local baseWalk = ply:GetWalkSpeed()
			local baseRun = ply:GetRunSpeed()

			ply:SetWalkSpeed(baseWalk * SPEED_MULTIPLIER)
			ply:SetRunSpeed(baseRun * SPEED_MULTIPLIER)
			ply:SetLadderClimbSpeed(baseRun * SPEED_MULTIPLIER)
			ply:SetJumpPower(200 * SPEED_MULTIPLIER)
		end

		-- Modify weapon fire rates and damage
		hook.Add("EntityTakeDamage", TAG, function(target, dmginfo)
			if IsValid(target) and target:IsPlayer() then
				dmginfo:ScaleDamage(DAMAGE_MULTIPLIER)
			end
		end)
	end

	-- Handle player respawns/revives to reapply speed benefits
	hook.Add("PlayerSpawn", TAG, function(ply)
		if IsValid(ply) and ply:IsTerror() then
			local baseWalk = ply:GetWalkSpeed()
			local baseRun = ply:GetRunSpeed()

			ply:SetWalkSpeed(baseWalk * SPEED_MULTIPLIER)
			ply:SetRunSpeed(baseRun * SPEED_MULTIPLIER)
			ply:SetLadderClimbSpeed(baseRun * SPEED_MULTIPLIER)
			ply:SetJumpPower(200 * SPEED_MULTIPLIER)
		end
	end)

	function ROUND:Finish()
		-- Reset player speeds
		for _, ply in ipairs(player.GetAll()) do
			ply:SetWalkSpeed(220) -- Default TTT walk speed
			ply:SetRunSpeed(220) -- Default TTT run speed
			ply:SetLadderClimbSpeed(220)
			ply:SetJumpPower(200)
		end

		hook.Remove("EntityTakeDamage", TAG)
		hook.Remove("PlayerSpawn", TAG)
	end
end

if CLIENT then
	function ROUND:Start()
		-- Add motion blur effect
		hook.Add("RenderScreenspaceEffects", TAG, function()
			if LocalPlayer():GetVelocity():Length() > 100 then
				DrawMotionBlur(0.2, 0.8, 0.01)
			end
		end)
	end

	function ROUND:Finish()
		hook.Remove("RenderScreenspaceEffects", TAG)
	end
end

return RegisterChaosRound(ROUND)