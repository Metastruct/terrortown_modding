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

		self.BaseWalkSpeed = Entity(1):GetWalkSpeed()
		self.BaseRunSpeed = Entity(1):GetRunSpeed()
		self.BaseLadderClimbSpeed = Entity(1):GetLadderClimbSpeed()
		self.BaseJumpPower = Entity(1):GetJumpPower()

		for _, ply in ipairs(player.GetAll()) do
			if not ply:IsTerror() then continue end

			ply:SetWalkSpeed(self.BaseWalkSpeed * SPEED_MULTIPLIER)
			ply:SetRunSpeed(self.BaseRunSpeed * SPEED_MULTIPLIER)
			ply:SetLadderClimbSpeed(self.BaseLadderClimbSpeed * SPEED_MULTIPLIER)
			ply:SetJumpPower(self.BaseJumpPower * SPEED_MULTIPLIER)
		end

		-- Modify weapon fire rates and damage
		hook.Add("EntityTakeDamage", TAG, function(target, dmginfo)
			if IsValid(target) and target:IsPlayer() then
				dmginfo:ScaleDamage(DAMAGE_MULTIPLIER)
			end
		end)

		-- Handle player respawns/revives to reapply speed benefits
		hook.Add("PlayerSpawn", TAG, function(ply)
			ply:SetWalkSpeed(self.BaseWalkSpeed * SPEED_MULTIPLIER)
			ply:SetRunSpeed(self.BaseRunSpeed * SPEED_MULTIPLIER)
			ply:SetLadderClimbSpeed(self.BaseLadderClimbSpeed * SPEED_MULTIPLIER)
			ply:SetJumpPower(self.BaseJumpPower * SPEED_MULTIPLIER)
		end)
	end

	function ROUND:Finish()
		-- Reset player speeds
		for _, ply in ipairs(player.GetAll()) do
			ply:SetWalkSpeed(self.BaseWalkSpeed)
			ply:SetRunSpeed(self.BaseRunSpeed)
			ply:SetLadderClimbSpeed(self.BaseLadderClimbSpeed)
			ply:SetJumpPower(self.BaseJumpPower)
		end

		hook.Remove("EntityTakeDamage", TAG)
		hook.Remove("PlayerSpawn", TAG)
	end
end

if CLIENT then
	function ROUND:Start()
		-- Add motion blur effect
		hook.Add("RenderScreenspaceEffects", TAG, function()
			if LocalPlayer():GetVelocity():Length() > 200 then
				DrawMotionBlur(0.2, 0.25, 0.01)
			end
		end)
	end

	function ROUND:Finish()
		hook.Remove("RenderScreenspaceEffects", TAG)
	end
end

return RegisterChaosRound(ROUND)