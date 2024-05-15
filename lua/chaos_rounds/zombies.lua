local ROUND = {}
ROUND.Name = "Zombies"
ROUND.Description = "A virus spreads, kills claimed by traitors will be revived as zombies. Survive for 5 minutes!"

local TAG = "ChaosRoundsZombie"

if SERVER then
	function ROUND:Start()
		timer.Simple(1, function()
			for _, ply in ipairs(player.GetAll()) do
				if ply:GetRole() == ROLE_TRAITOR and ply:IsTerror() then
					ply:SetRole(ROLE_ZOMBIE)
					ply:StripWeapons()

					ply:Give("weapon_ttt_zombie")
				end
			end
		end)

		hook.Add("PlayerLoadout", TAG, function(ply)
			ply:Give("weapon_ttt_zombie")
			return true
		end)

		hook.Add("TTT2PostPlayerDeath", TAG, function(victim, _, attacker)
			if victim:GetRole() == ROLE_ZOMBIE then
				victim:Revive(15)
				return
			end

			if victim:GetRole() ~= ROLE_ZOMBIE and IsValid(attacker) and attacker:IsPlayer() and attacker:GetRole() == ROLE_ZOMBIE then
				victim:Revive(15, function(ply)
					ply:SetRole(ROLE_ZOMBIE)
				end)
			end
		end)
	end

	function ROUND:Finish()
		hook.Remove("PlayerLoadout", TAG)
		hook.Remove("TTT2PostPlayerDeath", TAG)
	end
end


return RegisterChaosRound(ROUND)
