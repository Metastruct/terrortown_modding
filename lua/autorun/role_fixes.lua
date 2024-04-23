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

		-- Gambler related fixes
		if ROLE_GAMBLER then
			-- The ONLY way to apply this fix is to copy the whole snippet of code and make our own little amends :D
			-- This means ~90% of the below code is from the Gambler addon itself
			local randomAmountConvar = GetConVar("ttt2_gambler_randomitems")

			local function SendItemsToGambler(gambler)
				local subrole = ROLE_TRAITOR
				local buyCount = randomAmountConvar and randomAmountConvar:GetInt() or 3

				-- gather all items buyable for role
				local roleItems = {}
				for k, v in ipairs(items.GetList()) do
					if v and v.CanBuy and table.HasValue(v.CanBuy, subrole) then
						roleItems[#roleItems + 1] = v
					end
				end

				-- gather all weapons buyable for role (exclude built-in grenades)
				local roleWeapons = {}
				for k, v in ipairs(weapons.GetList()) do
					if v and not (v.builtin and v.IsGrenade) and v.CanBuy and table.HasValue(v.CanBuy, subrole) then
						roleWeapons[#roleWeapons + 1] = v
					end
				end

				local randomWeapons = math.random(math.ceil(buyCount * 0.33), math.max(buyCount - 1, 1))
				local randomItems = buyCount - randomWeapons

				local giveItems = {}
				local giveWeapons = {}

				-- collect items to give
				if randomItems > 0 then
					for i = 1, randomItems do
						local newItem = roleItems[math.random(#roleItems)]

						while giveItems[newItem.id] != nil do
							newItem = roleItems[math.random(#roleItems)]
						end

						giveItems[newItem.id] = newItem
					end
				end

				-- collect weapons to give
				if randomWeapons > 0 then
					for i = 1, randomWeapons do
						local newWeapon = roleWeapons[math.random(#roleWeapons)]

						while giveWeapons[newWeapon.id] != nil do
							newWeapon = roleWeapons[math.random(#roleWeapons)]
						end

						giveWeapons[newWeapon.id] = newWeapon
					end
				end

				local receivedEquipment = {}

				-- give items
				for _, i in pairs(giveItems) do
					gambler:GiveEquipmentItem(i.id)

					receivedEquipment[#receivedEquipment + 1] = i.name
				end

				-- give weapons
				for _, w in pairs(giveWeapons) do
					-- Use Give instead of GiveEquipmentWeapon to ignore slot limits
					gambler:Give(w.id)

					receivedEquipment[#receivedEquipment + 1] = w.name
				end

				-- send message to client
				net.Start("gambler_message")
				net.WriteString(table.concat(receivedEquipment, ", ") .. ".")
				net.Send(gambler)
			end

			hook.Add("TTTBeginRound", "TTT2GamblerPostReceiveCustomClasses", function()
				for _, p in ipairs(player.GetAll()) do
					if p:IsActive() and p:GetSubRole() == ROLE_GAMBLER then
						SendItemsToGambler(p)
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