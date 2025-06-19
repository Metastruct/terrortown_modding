if SERVER then
	AddCSLuaFile()

	local playerData = {}
	_G.camping_playerData = playerData

	local CV_ENABLED = CreateConVar("camping_enabled", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable/disable the anti-camping system")
	local CV_CAMP_TIME = CreateConVar("camping_time_threshold", "40", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Seconds before considering someone a camper")
	local CV_MOVEMENT_THRESHOLD = CreateConVar("camping_movement_threshold", "300", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Units player must move to not be considered camping")
	local CV_ISOLATION_DISTANCE = CreateConVar("camping_isolation_distance", "1000", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Distance from other players to be considered isolated")
	local CV_VISIBILITY_DURATION = CreateConVar("camping_visibility_duration", "15", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Seconds to keep camper visible")
	local CV_WARNING_TIME = CreateConVar("camping_warning_time", "10", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Seconds before making visible to show warning")
	local CV_CHECK_INTERVAL = CreateConVar("camping_check_interval", "2", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Seconds between position checks")

	local function InitPlayerData(ply)
		if not IsValid(ply) then return end

		playerData[ply] = {
			lastPos = ply:GetPos(),
			lastWarned = 0,
			startCampTime = 0,
			isCamping = false,
			lastMoveTime = CurTime()
		}
	end

	local function CleanupPlayerData(ply)
		if playerData[ply] then
			playerData[ply] = nil
		end
	end

	local function IsPlayerIsolated(ply)
		if not IsValid(ply) then return false end
		if ply.IsAFK and ply:IsAFK() then return true end

		local pos = ply:GetPos()
		local closestDistance = math.huge

		for _, otherPly in pairs(player.GetAll()) do
			if IsValid(otherPly) and otherPly ~= ply and otherPly:IsTerror() then
				local distance = pos:Distance(otherPly:GetPos())

				if distance < closestDistance then
					closestDistance = distance
				end
			end
		end

		return closestDistance > CV_ISOLATION_DISTANCE:GetInt()
	end

	local function HasPlayerMoved(ply)
		if not IsValid(ply) then return true end
		if ply.IsAFK and ply:IsAFK() then return false end
		if not playerData[ply] then return true end

		local data = playerData[ply]
		local currentPos = ply:GetPos()

		local moved = currentPos:Distance(data.lastPos) > CV_MOVEMENT_THRESHOLD:GetInt()
		if moved then
			data.lastPos = currentPos
		end

		return moved
	end

	local function ExposeCamper(ply)
		if not IsValid(ply) then return end

		ply:SetNWBool("CampingVisible", true)

		local timer_name = ("camping_visibility_[%s]"):format(ply:SteamID())
		timer.Create(timer_name, CV_VISIBILITY_DURATION:GetInt(), 1, function()
			if IsValid(ply) then
				local data = playerData[ply]
				if data.isCamping then
					ExposeCamper(ply) -- reset timer if they are still camping
					return
				end

				ply:SetNWBool("CampingVisible", false)
			end
		end)
	end

	local function WarnCamper(ply, timeLeft)
		if not IsValid(ply) then return end

		local text = "Don't be lame! Move within " .. math.ceil(timeLeft) .. " seconds or you'll be visible through walls!"
		if EasyChat then
			EasyChat.Warn(ply, text)
		else
			ply:ChatPrint("[WARN] " .. text)
		end
	end

	local function LowPlayerCount()
		local totalPlayers = player.GetCount()
		if totalPlayers <= 4 then return true end

		local activePlayers = 0
		for _, ply in pairs(player.GetAll()) do
			if IsValid(ply) and ply:IsTerror() then
				activePlayers = activePlayers + 1
			end
		end

		return activePlayers / totalPlayers <= 0.2
	end

	local function CheckForCampers()
		if not CV_ENABLED:GetBool() then return end
		if not LowPlayerCount() then return end

		for _, ply in pairs(player.GetAll()) do
			if IsValid(ply) and ply:IsTerror() then
				if not playerData[ply] then
					InitPlayerData(ply)
				end

				local data = playerData[ply]
				local hasMoved = HasPlayerMoved(ply)
				local isIsolated = IsPlayerIsolated(ply)

				if hasMoved then
					data.isCamping = false
					data.startCampTime = 0
					data.lastMoveTime = CurTime()
				else
					if not data.isCamping then
						data.isCamping = true
						data.startCampTime = CurTime()
					end

					local campTime = CurTime() - data.startCampTime
					if isIsolated then
						if campTime >= CV_CAMP_TIME:GetInt() then
							ExposeCamper(ply)
						elseif campTime > (CV_CAMP_TIME:GetInt() - CV_WARNING_TIME:GetInt()) then
							local timeLeft = CV_CAMP_TIME:GetInt() - campTime

							if CurTime() - data.lastWarned > 5 then
								WarnCamper(ply, timeLeft)
								data.lastWarned = CurTime()
							end
						end
					else
						if data.isCamping and campTime > 5 then
							data.startCampTime = CurTime() - 5
						end
					end
				end
			end
		end
	end

	hook.Add("PlayerSpawn", "Camping_PlayerSpawn", function(ply)
		InitPlayerData(ply)
	end)

	hook.Add("PlayerDisconnected", "Camping_PlayerDisconnected", function(ply)
		CleanupPlayerData(ply)
	end)

	hook.Add("PlayerDeath", "Camping_PlayerDeath", function(ply)
		CleanupPlayerData(ply)
		ply:SetNWBool("CampingVisible", false)
	end)

	local function ResetAllPlayerData()
		for ply, data in pairs(playerData) do
			if IsValid(ply) then
				ply:SetNWBool("CampingVisible", false)
				CleanupPlayerData(ply)
			end
		end
	end

	hook.Add("TTTEndRound", "Camping_RoundEnd", function()
		ResetAllPlayerData()
	end)

	hook.Add("TTTPrepareRound", "Camping_PrepareRound", function()
		ResetAllPlayerData()
	end)

	hook.Add("SetupPlayerVisibility", "Camping_Visibility", function()
		for _, ply in ipairs(player.GetAll()) do
			if ply:IsTerror() and ply:GetNWBool("CampingVisible", false) then
				AddOriginToPVS(ply:GetPos())
			end
		end
	end)

	timer.Create("CampingCheck", CV_CHECK_INTERVAL:GetInt(), 0, CheckForCampers)

	-- Update timer interval when ConVar changes
	cvars.AddChangeCallback("camping_check_interval", function(convar_name, value_old, value_new)
		timer.Remove("CampingCheck")
		timer.Create("CampingCheck", tonumber(value_new) or 2, 0, CheckForCampers)
	end)
end

if CLIENT then
	surface.CreateFont("CampingWarning", {
		font = "Arial",
		size = 18,
		extended = true,
		weight = 1000,
		outline = true
	})

	local CAMPER_COLOR = Color(255, 100, 100, 255)
	local OFFSET = Vector(0, 0, 10)

	hook.Add("HUDPaint", "Camping_HUDPaint", function()
		for _, ply in ipairs(player.GetAll()) do
			if not ply:GetNWBool("CampingVisible", false) then continue end
			if ply == LocalPlayer() then continue end
			if not ply:Alive() then continue end
			cam.Start3D(EyePos(), EyeAngles())
			cam.IgnoreZ(true)
			render.SuppressEngineLighting(true)

			if pac then
				pac.ForceRendering(true)
				pac.ShowEntityParts(ply)
				pac.RenderOverride(ply, "opaque")
			end

			ply:DrawModel()
			local wep = ply:GetActiveWeapon()

			if IsValid(wep) then
				wep:DrawModel()
			end

			if pac then
				pac.ForceRendering(false)
			end

			render.SuppressEngineLighting(false)
			cam.IgnoreZ(false)
			cam.End3D()
			surface.SetTextColor(CAMPER_COLOR)
			surface.SetFont("CampingWarning")
			local text = ply.IsAFK and ply:IsAFK() and "[AFK]" or "[CAMPER]"
			local tw, _ = surface.GetTextSize(text)
			local pos = (ply:GetPos() + OFFSET):ToScreen()

			if pos.visible then
				surface.SetTextPos(pos.x - tw / 2, pos.y)
				surface.DrawText(text)
			end
		end
	end)

	hook.Add("PreDrawOutlines", "Camping_Outlines", function()
		local camper_players = {}

		for _, ply in ipairs(player.GetAll()) do
			if not ply:GetNWBool("CampingVisible", false) then continue end
			if ply == LocalPlayer() then continue end
			if not ply:Alive() then continue end
			table.insert(camper_players, ply)
		end

		outline.Add(camper_players, CAMPER_COLOR, OUTLINE_MODE_BOTH, 4)
	end)
end