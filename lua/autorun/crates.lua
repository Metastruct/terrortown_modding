local TAG = "TTTBonusCrates"

if SERVER then
	util.AddNetworkString(TAG)
	util.AddNetworkString(TAG .. "_Collected")

	local spawn_points = {}
	for _, point in ipairs(ents.FindByClass("info_player_*")) do
		table.insert(spawn_points, point:GetPos())
	end

	local function spawn_point_fallbacks()
		local points = {}
		for _, ply in ipairs(player.GetAll()) do
			if IsValid(ply) and ply:IsTerror() and ply:Alive() then
				local pos = ply:GetPos()
				pos = pos + Vector(math.random(-300, 300), math.random(-300, 300), 0)
				local tr = util.TraceLine({
					start = pos,
					endpos = pos - Vector(0, 0, 100),
					mask = MASK_SOLID
				})

				if tr.Hit then
					table.insert(points, pos)
				end
			end
		end

		return points
	end

	local function get_random_spawn_pos()
		local reference_points = spawn_points
		if #reference_points == 0 then
			reference_points = spawn_point_fallbacks()
		end

		local valid_points = {}
		for _, pos in ipairs(reference_points) do
			local tr = util.TraceHull({
				start = pos + Vector(0, 0, 32), -- Start above ground
				endpos = pos + Vector(0, 0, 32),
				mins = Vector(-16, -16, 0),
				maxs = Vector(16, 16, 72),
				mask = MASK_PLAYERSOLID
			})

			if not tr.Hit then
				table.insert(valid_points, pos)
			end
		end

		if #valid_points == 0 then return nil end
		return valid_points[math.random(#valid_points)]
	end

	local special_ents = {}
	local function spawn_credit_crate(pos)
		local crate = ents.Create("prop_physics")
		crate:SetModel("models/props_junk/cardboard_box004a.mdl")
		crate:SetPos(pos + Vector(0, 0, 20))
		crate:Spawn()
		table.insert(special_ents, crate)
		crate.CrateType = "credits"
		crate.IsBonusCrate = true

		return crate
	end

	local function spawn_supply_crate(pos)
		local crate = ents.Create("prop_physics")
		crate:SetModel("models/props_junk/wood_crate001a.mdl")
		crate:SetPos(pos + Vector(0, 0, 20))
		crate:Spawn()
		table.insert(special_ents, crate)
		crate.CrateType = "supply"
		crate.IsBonusCrate = true

		return crate
	end

	hook.Add("SetupPlayerVisibility", TAG, function()
		for i, ent in ipairs(special_ents) do
			if not IsValid(ent) then
				table.remove(special_ents, i)
			else
				AddOriginToPVS(ent:GetPos())
			end
		end
	end)

	local DEBUG = true
	local cvar_chance = CreateConVar("ttt_bonus_crates_chance", "0.25", {FCVAR_NOTIFY, FCVAR_ARCHIVE}, "Chance for a bonus crate to spawn")
	hook.Add("TTTBeginRound", TAG, function()
		if not DEBUG and math.random() > cvar_chance:GetFloat() then return end

		-- After 1-2 minutes and only once per round
		timer.Create(TAG, DEBUG and 1 or math.random(60, 120), 1, function()
			local pos
			for _ = 1, 3 do -- retry 3 times
				pos = get_random_spawn_pos()
				if pos then break end
			end

			if not pos then return end

			local crate, msg
			if math.random() > 0.5 then
				crate = spawn_credit_crate(pos)
				msg = "A credit crate has been hidden on the map! Collect it for an extra credit."
			else
				crate = spawn_supply_crate(pos)
				msg = "A supply crate has been dropped! Find it to get special equipment."
			end

			timer.Simple(1, function()
				if not IsValid(crate) then return end

				net.Start(TAG)
				net.WriteEntity(crate)
				net.WriteString(msg)
				net.Broadcast()
			end)
		end)
	end)

	hook.Add("TTTEndRound", TAG, function()
		timer.Remove(TAG)
		for _, ent in ipairs(special_ents) do
			SafeRemoveEntity(ent)
		end

		special_ents = {}
	end)

	local function handle_crate_collection(ply, crate)
		if crate.CrateType == "credits" then
			local credits = math.random(1, 2)
			ply:AddCredits(credits)

			net.Start(TAG .. "_Collected")
			net.WriteEntity(ply)
			net.WriteString("credits")
			net.Broadcast()

			SafeRemoveEntity(crate)
			return true
		elseif crate.CrateType == "supply" then
			local equipment = {}
			for k, v in pairs(weapons.GetList()) do
				if v.CanBuy and #v.CanBuy > 0 then
					table.insert(equipment, v.ClassName)
				end
			end

			if #equipment > 0 then
				local wep = equipment[math.random(#equipment)]
				ply:Give(wep)

				net.Start(TAG .. "_Collected")
				net.WriteEntity(ply)
				net.WriteString("supply")
				net.WriteString(wep)
				net.Broadcast()

				SafeRemoveEntity(crate)
				return true
			end
		end
	end

	hook.Add("PlayerUse", TAG, function(ply, ent)
		if not ent.IsBonusCrate then return end
		if not IsValid(ply) and ply:IsPlayer() and ply:IsTerror() then return end

		return handle_crate_collection(ply, ent)
	end)

	hook.Add("EntityTakeDamage", TAG, function(target, dmginfo)
		if not target.IsBonusCrate then return end

		local attacker = dmginfo:GetAttacker()
		if IsValid(attacker) and attacker:IsPlayer() and attacker:IsTerror() then
			handle_crate_collection(attacker, target)
		end
	end)
end

if CLIENT then
	local active_crates = {}
	local CRATE_COLOR = Color(255, 200, 0)

	net.Receive(TAG, function()
		local crate = net.ReadEntity()
		local desc = net.ReadString()

		table.insert(active_crates, crate)
		crate.IsBonusCrate = true

		EPOP:AddMessage({
			text = "Bonus Crate",
			color = CRATE_COLOR
		},
		{
			text = desc,
			color = Color(255, 255, 255)
		}, 12)
	end)

	local lang_names = { "default", "english" }
	for _, lang in ipairs(lang_names) do
		local L = LANG.GetLanguageTableReference(lang)
		L["CRATE_FOUND"] = "{name} has found a {item}!"
	end

	net.Receive(TAG .. "_Collected", function()
		local ply = net.ReadEntity()
		local type = net.ReadString()

		if not IsValid(ply) then return end

		for i, ent in ipairs(active_crates) do
			if not IsValid(ent) then
				table.remove(active_crates, i)
			end
		end

		local wep = type == "supply" and net.ReadString() or nil
		local wep_name = wep and weapons.Get(wep) and weapons.Get(wep).PrintName or wep
		if wep_name then
			wep_name = LANG.TryTranslation(wep_name)
		end

		LANG.Msg("CRATE_FOUND", {
			name = ply:Nick(),
			item = type == "supply" and wep_name or "credit"
		}, MSG_MSTACK_ROLE, CRATE_COLOR)
	end)

	hook.Add("TTTRenderEntityInfo", TAG, function(tData)
		local ent = tData:GetEntity()

		if not ent.IsBonusCrate then return end

		tData:EnableText()
		tData:EnableOutline()
		tData:SetOutlineColor(CRATE_COLOR)

		tData:SetTitle("Bonus Crate")
		tData:SetSubtitle("Press E to collect")
	end)

	-- Add halo effect
	hook.Add("PreDrawOutlines", TAG, function()
		if #active_crates > 0 then
			outline.Add(active_crates, CRATE_COLOR, OUTLINE_MODE_BOTH, 6)
		end
	end)
end