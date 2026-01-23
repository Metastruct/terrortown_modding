local CurTime = CurTime

require("hookextras")

if SERVER then
	AddCSLuaFile()
end

local function updateRoleSettings()
	-- Defective: Update the role's color so it's easier to distinguish
	local ROLE = roles.GetStored("defective")
	if ROLE then
		ROLE.color = Color(255, 0, 40)

		-- Need to update the other color fields too on client
		if CLIENT then
			ROLE.dkcolor = util.ColorDarken(ROLE.color, 30)
			ROLE.ltcolor = util.ColorLighten(ROLE.color, 30)
			ROLE.bgcolor = util.ColorComplementary(ROLE.color)
		end
	end

	-- Defector: Ensure the role is always given a Jihad Bomb
	ROLE = roles.GetStored("defector")
	if ROLE then
		function ROLE:GiveRoleLoadout(pl)
			pl:Give("weapon_ttt_jihad_bomb")
		end
	end
end

util.OnInitialize(function()
	updateRoleSettings()

	-- Also run updateRoleSettings through this hook
	hook.Add("TTT2RolesLoaded", "TTTRoleFixes", updateRoleSettings)

	-- Gambler related fixes
	if ROLE_GAMBLER then
		if SERVER then
			-- Fix Gambler's flawed equipment randomising and giving code
			--     The ONLY way to apply this fix is to copy the whole segment of code and make our own little amends :D
			--     This means ~80% of the below code is from the Gambler addon itself
			local randomAmountConvar = GetConVar("ttt2_gambler_randomitems")

			-- Items that shouldn't be given to Gamblers at all
			local blacklistedItems = {
				item_ttt_roids = true
			}

			local function SendItemsToGambler(gambler)
				local subrole = ROLE_TRAITOR
				local buyCount = randomAmountConvar and randomAmountConvar:GetInt() or 3

				-- Gather all items buyable for role
				local roleItems = {}
				for k, v in ipairs(items.GetList()) do
					if v and not blacklistedItems[v.id] and v.CanBuy and table.HasValue(v.CanBuy, subrole) then
						roleItems[#roleItems + 1] = v
					end
				end

				-- Gather all weapons buyable for role (excluding built-in grenades)
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

				-- Collect items to give
				if randomItems > 0 then
					for i = 1, randomItems do
						local newItem = roleItems[math.random(#roleItems)]

						while giveItems[newItem.id] != nil do
							newItem = roleItems[math.random(#roleItems)]
						end

						giveItems[newItem.id] = newItem
					end
				end

				-- Collect weapons to give
				if randomWeapons > 0 then
					for i = 1, randomWeapons do
						local newWeapon = roleWeapons[math.random(#roleWeapons)]

						while giveWeapons[newWeapon.id] != nil do
							newWeapon = roleWeapons[math.random(#roleWeapons)]
						end

						giveWeapons[newWeapon.id] = newWeapon
					end
				end

				gambler.GamblerEquipmentList = {}

				local receivedEquipment = {}

				-- Give items
				for _, i in pairs(giveItems) do
					local item = gambler:GiveEquipmentItem(i.id)

					-- Some items rely on their Bought function being called to work properly, so call it
					if item then
						gambler.GamblerEquipmentList[#gambler.GamblerEquipmentList + 1] = i.id

						if isfunction(item.Bought) then
							item:Bought(gambler)
						end
					end

					receivedEquipment[#receivedEquipment + 1] = i.name
				end

				-- Give weapons
				for _, w in pairs(giveWeapons) do
					-- Use Give instead of GiveEquipmentWeapon to ignore slot limits
					local wep = gambler:Give(w.id)

					if wep then
						gambler.GamblerEquipmentList[#gambler.GamblerEquipmentList + 1] = wep

						if isfunction(wep.WasBought) then
							wep:WasBought(gambler)
						end
					end

					receivedEquipment[#receivedEquipment + 1] = w.name
				end

				-- Send message to client
				net.Start("gambler_message")
				net.WriteString(table.concat(receivedEquipment, ","))
				net.Send(gambler)
			end

			local function RemoveGamblerEquipment(gambler)
				if not gambler.GamblerEquipmentList then return end

				for k, v in ipairs(gambler.GamblerEquipmentList) do
					if isentity(v) then
						if IsValid(v)
						and v:IsWeapon()
						and v:GetOwner() == gambler then
							v:Remove()
						end
					else
						gambler:RemoveEquipmentItem(v)
					end
				end

				gambler.GamblerEquipmentList = nil
			end

			hook.Add("TTTPrepareRound", "TTT2GamblerReset", function()
				for _, p in player.Iterator() do
					p.GamblerEquipmentList = nil
				end
			end)

			-- Remove the hook created by the original Gambler code that distributes items - we have a better way
			hook.Remove("TTTBeginRound", "TTT2GamblerPostReceiveCustomClasses")

			local ROLE = roles.GetStored("gambler")
			if ROLE then
				--  Give random equipment to new gamblers, after ensuring any gambler equipment perviously given to them has been removed
				function ROLE:GiveRoleLoadout(pl, isRoleChange)
					RemoveGamblerEquipment(pl)
					SendItemsToGambler(pl)
				end
			end
		else
			local tryT = LANG.TryTranslation

			-- Fix Gambler's received equipment message
			--     Again, some of the below code is from the Gambler addon itself
			local preventMultipleMsg
			net.Receive("gambler_message", function()
				if not preventMultipleMsg then
					preventMultipleMsg = true

					local msg = net.ReadString()
					local equipmentIds = msg and string.Explode(",", msg) or {}

					local equipmentNames = {}
					for i = 1, #equipmentIds do
						local id = equipmentIds[i]
						local name = tryT(id)

						-- If a localised string wasn't found for the equipment's ID, assume it's a weapon and get its PrintName
						if name == id then
							local wep = weapons.Get(id)
							if wep then
								name = wep.PrintName

								-- If the PrintName has an underscore in it, assume it's a string that needs to be localised
								if string.find(name, "_", 1, true) then
									name = tryT(name)
								end
							end
						end

						equipmentNames[#equipmentNames + 1] = name
					end

					timer.Simple(0.1, function()
						chat.AddText(
							Color(210, 39, 34), "[Gambler]",
							Color(250, 250, 250), " You received the following traitor equipment:\n",
							Color(237, 177, 12), "    - " .. table.concat(equipmentNames, "\n    - ")
						)

						preventMultipleMsg = false
					end)
				end
			end)
		end
	end

	if SERVER then
		-- Serverside only tweaks

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
			local playerIterator = player.Iterator
			hook.Add("Think", "ThinkVampire", function()
				for _, pl in playerIterator() do
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

		-- Sacrifice related fixes
		if ROLE_SACRIFICE then
			-- The sacrifice's defib references this convar but it's never defined so it errors, create it here to fix the error
			CreateConVar("ttt2_sacrificedefi_res_thrall", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY})
		end
	else
		-- Clientside only tweaks

		-- Fix vampire bat bind not being created in the TTT2FinishedLoading hook by re-running it here
		local hookTable = hook.GetTable().TTT2FinishedLoading
		if hookTable and hookTable.TTTRoleVampireInit then
			hookTable.TTTRoleVampireInit()
		end
	end
end)