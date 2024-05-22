local ROUND = {}
ROUND.Name = "Zombies"
ROUND.Description = "A virus spreads, kills claimed by traitors will be revived as zombies. Survive for 5 minutes!"

local TAG = "ChaosRoundsZombie"
local WEAPON_CLASS = "weapon_ttt_zombie"

if SERVER then
	util.AddNetworkString(TAG)

	local function make_zombie(ply)
		-- this can be called if you are the lat person revived
		if GetRoundState() ~= ROUND_ACTIVE then return end

		if not IsValid(ply) then return end
		if not ply:IsPlayer() then return end

		ply:SetRole(ROLE_ZOMBIE)
		ply:GiveEquipmentItem("item_ttt_radar")

		if not ply:HasWeapon(WEAPON_CLASS) then
			ply:Give(WEAPON_CLASS)
		end

		for _, w in ipairs(ply:GetWeapons()) do
			if w:GetClass() ~= WEAPON_CLASS then
				w:Remove()
			end
		end

		ply:SetMaxHealth(50)
		ply:SetHealth(50)
		ply:SetArmor(0)
		ply:SetWalkSpeed(400)
		ply:SetRunSpeed(400)
		ply:SetLadderClimbSpeed(400)
		ply:SetJumpPower(300)

		net.Start(TAG)
		net.WriteEntity(ply)
		net.Broadcast()
	end

	local function revive_zombie(ply)
		ply:Revive(15, function()
			timer.Simple(0, function()
				if not IsValid(ply) then return end
				ply:Spawn()

				timer.Simple(1, function()
					if not IsValid(ply) then return end
					make_zombie(ply)
				end)
			end)
		end)
	end

	function ROUND:OnPrepare()
		hook.Add("TTT2MetaModifyFinalRoles", TAG, function(role_map)
			for ply, role_id in pairs(role_map) do
				local role = roles.GetByIndex(role_id)
				if role and role.defaultTeam == "traitors" and roles.ZOMBIE then
					role_map[ply] = roles.ZOMBIE.id
				end
			end
		end)
	end

	function ROUND:Start()
		local end_time = CurTime() + 60 * 5

		timer.Simple(1, function()
			SetRoundEnd(end_time)

			for _, ply in ipairs(player.GetAll()) do
				if ply:GetTeam() == "traitors" and ply:IsTerror() then
					make_zombie(ply)
				end
			end
		end)

		hook.Add("TTT2PostPlayerDeath", TAG, function(victim, _, attacker)
			-- fixate the round end timer
			timer.Simple(0, function()
				if GetRoundState() == ROUND_ACTIVE then
					SetRoundEnd(end_time)
				end
			end)

			if victim:GetSubRole() == ROLE_ZOMBIE then
				revive_zombie(victim)
				return
			end

			if victim:GetSubRole() ~= ROLE_ZOMBIE and IsValid(attacker) and attacker:IsPlayer() and attacker:GetSubRole() == ROLE_ZOMBIE then
				revive_zombie(victim)
			end
		end)

		hook.Add("WeaponEquip", TAG, function(wep, owner)
			if not owner:IsTerror() then return end
			if owner:GetSubRole() ~= ROLE_ZOMBIE then return end
			if wep:GetClass() == WEAPON_CLASS then return end

			wep:Remove()

			if not owner:HasWeapon(WEAPON_CLASS) then
				owner:Give(WEAPON_CLASS)
			end

			owner:GiveEquipmentItem("item_ttt_radar")
		end)

		hook.Add("TTTCheckForWin", TAG, function()
			local survivors = 0
			for _, ply in ipairs(player.GetAll()) do
				if ply:GetSubRole() ~= ROLE_ZOMBIE and ply:IsTerror() then
					survivors = survivors + 1
				end
			end

			if survivors <= 0 and CurTime() < end_time then return WIN_TRAITOR end
			if CurTime() >= end_time and survivors > 0 then return WIN_INNOCENT end

			return WIN_NONE
		end)

		-- remove fall damage for zombies
		hook.Add("EntityTakeDamage", TAG, function(ent, dmg_info)
			if ent:IsPlayer() and ent:GetSubRole() == ROLE_ZOMBIE and dmg_info:IsFallDamage() then
				return true
			end
		end)
	end

	function ROUND:Finish()
		hook.Remove("TTT2PostPlayerDeath", TAG)
		hook.Remove("WeaponEquip", TAG)
		hook.Remove("TTTCheckForWin", TAG)
		hook.Remove("TTT2MetaModifyFinalRoles", TAG)
		hook.Remove("EntityTakeDamage", TAG)

		for _, ply in ipairs(player.GetAll()) do
			ply:SetMaxHealth(100)
			ply:SetWalkSpeed(220)
			ply:SetRunSpeed(220)
			ply:SetLadderClimbSpeed(200)
			ply:SetJumpPower(160)
		end
	end
end

if CLIENT then
	local function get_bind(name)
		local bind = input.LookupBinding(name)
		if not bind then return "UNBOUND" end

		return bind:upper()
	end

	local PRIMARY_ATTACK_BIND = get_bind("+attack")
	local SECONDARY_ATTACK_BIND = get_bind("+attack2")
	function ROUND:Start()
		local warned = true
		hook.Add("Think", TAG, function()
			local ply = LocalPlayer()
			if ply:GetSubRole() ~= ROLE_ZOMBIE then return end
			if not ply:Alive() then return end

			local wep = ply:GetActiveWeapon()
			local target_wep = ply:GetWeapon("weapon_ttt_zombie")
			if (not IsValid(wep) or wep:GetClass() ~= WEAPON_CLASS) and IsValid(target_wep) then
				input.SelectWeapon(target_wep)
				if not warned then
					local role_color = roles.GetByIndex(ply:GetSubRole()).color
					chat.AddText(role_color, ("[INFO] You are a zombie! You can attack [%s] or jump [%s]."):format(PRIMARY_ATTACK_BIND, SECONDARY_ATTACK_BIND))
					warned = true
				end
			end
		end)

		hook.Add("PlayerFootstep", TAG, function(ply)
			if ply:GetSubRole() ~= ROLE_ZOMBIE then return end

			ply:EmitSound("npc/fast_zombie/foot" .. math.random(1,4) .. ".wav", 120)
			return true
		end)
	end

	function ROUND:Finish()
		hook.Remove("Think", TAG)
		hook.Remove("PlayerFootstep", TAG)
	end

	net.Receive(TAG, function()
		local ply = net.ReadEntity()
		ply:SetRole(ROLE_ZOMBIE)
	end)
end

return RegisterChaosRound(ROUND)
