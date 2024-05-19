local ROUND = {}
ROUND.Name = "Zombies"
ROUND.Description = "A virus spreads, kills claimed by traitors will be revived as zombies. Survive for 5 minutes!"

local TAG = "ChaosRoundsZombie"

if SERVER then
	util.AddNetworkString(TAG)

	local function make_zombie(ply)
		if not IsValid(ply) then return end
		if not ply:IsPlayer() then return end

		ply:SetRole(ROLE_ZOMBIE)

		if not ply:HasWeapon("weapon_ttt_zombie") then
			ply:Give("weapon_ttt_zombie")
		end

		for _, w in ipairs(ply:GetWeapons()) do
			if w:GetClass() ~= "weapon_ttt_zombie" then
				w:Remove()
			end
		end

		ply:SetMaxHealth(50)
		ply:SetHealth(50)
		ply:SetArmor(0)
		ply:SetRunSpeed(400)

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
			if wep:GetClass() == "weapon_ttt_zombie" then return end

			wep:Remove()

			if not owner:HasWeapon("weapon_ttt_zombie") then
				owner:Give("weapon_ttt_zombie")
			end
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
	end

	function ROUND:Finish()
		hook.Remove("TTT2PostPlayerDeath", TAG)
		hook.Remove("WeaponEquip", TAG)
		hook.Remove("TTTCheckForWin", TAG)

		for _, ply in ipairs(player.GetAll()) do
			if ply:GetSubRole() == ROLE_ZOMBIE then
				ply:SetMaxHealth(100)
			end
		end
	end
end

if CLIENT then
	net.Receive(TAG, function()
		local ply = net.ReadEntity()
		ply:SetRole(ROLE_ZOMBIE)
	end)
end

return RegisterChaosRound(ROUND)
