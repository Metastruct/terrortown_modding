local CurTime = CurTime

require("hookextras")

if SERVER then
	AddCSLuaFile()

	util.OnInitialize(function()
		-- Vampire related fixes
		if PIGEON then
			-- Fix vampire bat still showing PACs
			if pac and pac.TogglePartDrawing then
				PIGEON.EnableOriginal = PIGEON.EnableOriginal or PIGEON.Enable
				PIGEON.DisableOriginal = PIGEON.DisableOriginal or PIGEON.Disable

				PIGEON.Enable = function(pl)
					PIGEON.EnableOriginal(pl)

					pac.TogglePartDrawing(pl, false)
				end

				PIGEON.Disable = function(pl)
					PIGEON.DisableOriginal(pl)

					pac.TogglePartDrawing(pl, true)
				end
			end

			-- Fix vampire bat constantly making noises from bloodlust (overwrites the whole Hurt hook func)
			PIGEON.Hooks.Hurt = function(pl, attacker, hp, dmgTaken)
				if pl.pigeon and dmgTaken > 1 then
					pl:EmitSound(PIGEON.sounds.pain)
				end
			end

			-- Fix vampire bloodlust damage applying force from world origin (can only overwrite the whole hook to fix it)
			local playerGetAll = player.GetAll
			hook.Add("Think", "ThinkVampire", function()
				for _, pl in ipairs(playerGetAll()) do
					if pl:IsActive() and pl:GetSubRole() == ROLE_VAMPIRE and pl:GetNWInt("Bloodlust", 0) < CurTime() then
						pl:SetNWBool("InBloodlust", true)
						pl:SetNWInt("Bloodlust", CurTime() + 2)

						local dmg = DamageInfo()
						dmg:SetAttacker(pl)
						dmg:SetDamage(1)
						dmg:SetDamageType(DMG_PREVENT_PHYSICS_FORCE)
						dmg:SetDamageForce(vector_origin)

						pl:TakeDamageInfo(dmg)
					end
				end
			end)
		end
	end)
else
	util.OnInitialize(function()
		-- Fix vampire bat bind not being created in the TTT2FinishedLoading hook by re-running it here
		local hookTable = hook.GetTable().TTT2FinishedLoading
		if hookTable and hookTable.TTTRoleVampireInit then
			hookTable.TTTRoleVampireInit()
		end
	end)
end