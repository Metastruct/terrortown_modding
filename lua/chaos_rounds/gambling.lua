local ROUND = {}
ROUND.Name = "Let's go gambling"
ROUND.Description = "Everyone gets the same special random weapon and a crowbar, and that's it. Mind your ammo."

local TAG = "ChaosRoundGambling"

if SERVER then
	local WEAPON_LIST = {
		"weapon_ttt_blunderbuss",
		"weapon_laser_phaser",
		"weapon_ttt_ivy_kiss",
		"weapon_ttt_gay_brick",
		"weapon_ttt_robloxbazooka",
		"weapon_ttt_revolver",
		"stungun", -- yes theres no mistake here
		"weapon_ttt_homebat",
		"weapon_ttt_ricochet",
		"weapon_ttt_c4",
		"weapon_ttt_phammer",
		"posswitch",
		"weapon_ttt_slam",
		"weapon_ttt_greendemon",
		"weapon_banana",
		"ttt_kamehameha_swep",
	}

	function ROUND:SelectRandomWeapon()
		--[[local equipments = ShopEditor.GetShopEquipments(roles.TRAITOR)
		local t_weapons = {}
		for _, equipment_data in pairs(equipments) do
			if isstring(equipment_data.name) and equipment_data.name:match("^weapon%_") then
				table.insert(t_weapons, equipment_data.name)
			end
		end]]

		-- set list because doing it automatically can give pretty boring things
		self.RandomWeaponClass = WEAPON_LIST[math.random(#WEAPON_LIST)]
	end

	function ROUND:OnPrepare()
		hook.Add("TTT2MetaModifyFinalRoles", TAG, function(role_map)
			for ply, role_id in pairs(role_map) do
				local role = roles.GetByIndex(role_id)
				if role and role.defaultTeam == "traitors" then
					role_map[ply] = roles.TRAITOR.id
				else
					role_map[ply] = roles.INNOCENT.id
				end
			end
		end)

		self:SelectRandomWeapon()
	end

	local ACCEPTED_WEAPONS_CLASS = {
		weapon_zm_improvised = true, -- crowbar apparently...
		weapon_ttt_unarmed = true, -- hands
		weapon_zm_carry = true, -- magneto stick
		weapon_ttt_brick = true, -- always funny
		weapon_ttt2_kiss = true, -- funny too
	}

	function ROUND:Start()
		for _, ply in pairs(player.GetAll()) do
			ply:Give(self.RandomWeaponClass)

			for _, w in ipairs(ply:GetWeapons()) do
				if w:GetClass() ~= self.RandomWeaponClass and not ACCEPTED_WEAPONS_CLASS[w:GetClass()] then
					w:Remove()
				end
			end
		end

		hook.Add("WeaponEquip", TAG, function(wep, owner)
			if not owner:IsTerror() then return end

			if wep:GetClass() ~= self.RandomWeaponClass and not ACCEPTED_WEAPONS_CLASS[wep:GetClass()] then
				wep:Remove()
			end
		end)

		hook.Add("TTT2CanOrderEquipment", TAG, function()
			return false, false
		end)
	end

	function ROUND:Finish()
		hook.Remove("TTT2MetaModifyFinalRoles", TAG)
		hook.Remove("WeaponEquip", TAG)
		hook.Remove("TTT2CanOrderEquipment", TAG)
	end
end

return RegisterChaosRound(ROUND)