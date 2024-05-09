local ROUND = {}
ROUND.Name = "World War 4"
ROUND.Description = "Everyone constantly regenerates Bricks, but guns deal no damage!"

function ROUND:Start()
	if SERVER then
		hook.Add("EntityTakeDamage", "ttt_chaos_worldwar4", function(target, dmginfo)
			local attacker = dmginfo:GetAttacker()
			if IsValid(attacker) and attacker:IsPlayer() then
				if dmginfo:IsBulletDamage() then
					dmginfo:ScaleDamage(0)
				end
			end
		end)
		timer.Create("ttt_chaos_worldwar4", 1, 0, function()
			for _, ply in pairs(player.GetAll()) do
				if ply.IsTerror and ply:IsTerror() and not ply:HasWeapon("weapon_ttt_brick") then
					ply:Give("weapon_ttt_brick")
				end
				-- Removed to allow traitors to buy guns
				-- for _, wep in pairs(ply:GetWeapons()) do
				-- 	local cls = wep:GetClass()
				-- 	if cls ~= "weapon_ttt_brick" and cls ~= "weapon_zm_improvised" then
				-- 		ply:StripWeapon(cls)
				-- 	end
				-- end
			end
		end)
	end
end

function ROUND:Finish()
	if SERVER then
		hook.Remove("EntityTakeDamage", "ttt_chaos_worldwar4")
		timer.Remove("ttt_chaos_worldwar4")
	end
end

RegisterChaosRound("World War 4", ROUND)
return ROUND
