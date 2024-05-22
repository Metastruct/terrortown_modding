local Tag = "tttfix"

require("hookextras")

local emptyFunc = function() end

AOWL_NO_TEAMS = true

if SERVER then
	AddCSLuaFile()

	-- Remove these aowl commands, either because they are cheaty, annoying, or don't work with TTT
	local badcmds = {
		["advert"] = true,
		["box"] = true,
		["boxify"] = true,
		["cheats"] = true,
		["dropcoin"] = true,
		["dropcoins"] = true,
		["economy"] = true,
		["findfag"] = true,
		["findlag"] = true,
		["givecoins"] = true,
		["giveup"] = true,
		["god"] = true,
		["gomoving"] = true,
		["headexplode"] = true,
		["hitler"] = true,
		["hoborope"] = true,
		["hsplode"] = true,
		["ignite"] = true,
		["invisible"] = true,
		["jail"] = true,
		["jump"] = true,
		["leavegame"] = true,
		["kidmode"] = true,
		["newswriter"] = true,
		["ooc"] = true,
		["puke"] = true,
		["push"] = true,
		["ragdoll"] = true,
		["ragdollize"] = true,
		["ragmod"] = true,
		["ragmodset"] = true,
		["unragdoll"] = true,
		["unragdollize"] = true,
		["unreserve"] = true,
		["vomit"] = true
	}

	for cmd in pairs(badcmds) do
		aowl.cmds[cmd] = nil
	end

	hook.Add("AowlCommandAdded", Tag, function(cmd)
		if badcmds[cmd] then
			aowl.cmds[cmd] = nil
		end
	end)

	-- Disable picking up vehicles
	hook.Add("TTT2PlayerPreventPickupEnt", Tag, function(pl, ent)
		for k, v in ipairs(player.GetAll()) do
			local veh = v:GetVehicle()
			if veh:IsValid() and veh:GetParent() == ent then
				return true
			end
		end
	end)

	-- Disable sitting for spectators and sitting on weapons
	hook.Add("OnPlayerSit", Tag, function(pl, pos, ang, parent)
		if not pl:IsTerror() or (IsValid(parent) and parent:IsWeapon()) then return false end
	end)

	-- Disable RP tapping shoulder thing - I would like to support this somewhat for funnies, but it opens opportunities for meta-gaming
	hook.Add("PlayerUsedByPlayer", Tag, function(pl, poker)
		return true
	end)

	-- Disable EasyChat indicating
	hook.Add("ECCanIndicate", Tag, function() return false end)

	-- Disable chatsounds for team chat and from dead/deathmatching people
	hook.Add("PlayerSay", Tag, function(pl, txt, teamChat)
		pl._chatsoundsUsedTeam = teamChat
	end)
	hook.Add("ChatsoundsShouldNetwork", Tag, function(pl)
		local usedTeam = pl._chatsoundsUsedTeam

		pl._chatsoundsUsedTeam = nil

		if usedTeam or (not pl:IsTerror() and CurTime() > (pl._last_death or 0) + 0.1) then return false end
	end)

	-- Disable AOWL failed/rate-limit sound for spectators/dead
	hook.Add("AowlShouldPlayErrorSound", Tag, function(ply)
		if not ply:IsTerror() then return false end
	end)

	-- Disable PMs (no funny meta gaming!)
	hook.Add("AllowPrivateMessaging", Tag, function(tbl)
		return false
	end)

	-- Disable alternative way of using "aowl push"
	concommand.Add("push", emptyFunc)

	-- Disable leap
	concommand.Add("leap", emptyFunc)

	-- Run these patches when things have initialized
	util.OnInitialize(function()
		if crosschat then
			crosschat.GetForcedTeam = function()
				return 1
			end
		end

		if aowl then
			local function tttRevive(sourcePl, pl)
				if IsValid(pl) and pl:IsPlayer() and not pl:IsTerror() then
					local success = pl:SpawnForRound(true)

					if success then
						-- Devs shouldn't be doing this in real games anyway so make some noise :)
						print(sourcePl or "CONSOLE", "forcibly revived", pl, "with tttrevive!")
						pl:EmitSound("npc/vort/attack_shoot.wav", 100, 90)
					end

					return success
				end

				return false
			end

			aowl.AddCommand("tttrevive", "Properly revives a player in TTT as their current role", function(pl, line, target)
				local ent = easylua.FindEntity(target)

				if type(ent) == "table" then
					if ent.get then
						ent = ent.get()
					end

					for k, v in ipairs(ent) do
						if IsValid(v) and v:IsPlayer() then
							tttRevive(pl, v)
						end
					end

					return
				end

				tttRevive(pl, ent)
			end,
			"developers", true)
		end

		if RTV then
			-- Print RTVs in chat and make a little chime (overwrite the whole function)
			RTV.AddVote = function(pl)
				if RTV.CanVote(pl) then
					RTV.TotalVotes = RTV.TotalVotes + 1
					pl.RTVoted = true

					local players = player.GetAll()

					local requiredAmount = math.Round(#players * 0.66)
					local sndPitch = 90 + math.ceil((RTV.TotalVotes / requiredAmount) * 40)

					local msg = string.format("%s has RTV'd! (%s / %s)", pl:Nick(), RTV.TotalVotes, requiredAmount)

					MsgN(msg)

					for k, v in ipairs(players) do
						v:ChatPrint(msg)
					end

					local filter = RecipientFilter()
					filter:AddAllPlayers()

					EmitSound("friends/friend_join.wav", vector_origin, -2, CHAN_AUTO, 0.8, 0, 0, sndPitch, 0, filter)

					if RTV.ShouldChange() then RTV.Start() end
				end
			end
		end

		-- Disable an obsolete engine protect hook we have if it's there - all it really does now is print a useless message in console
		hook.Remove("EntityRemoved", "dont_remove_players")

		-- Disable an engine protect hook that isn't needed at all in TTT, free up some processing time
		hook.Remove("EntityTakeDamage", "weapon_striderbuster_anticrash")
	end)
else
	-- Tell PAC to load a TTT autoload
	hook.Add("PAC3Autoload", Tag, function(name)
		return "autoload_ttt"
	end)

	-- Disable the root "boxify" command that exists on the client
	concommand.Add("boxify", emptyFunc)

	-- Shortcuts to show the Meta scoreboard
	local suppress_until = 0

	hook.Add("ScoreboardShow", Tag, function(reason)
		if reason ~= "ms" then return end
		if suppress_until > RealTime() then return end
		if LocalPlayer():KeyDown(IN_SPEED) or LocalPlayer():KeyDown(IN_USE) or LocalPlayer():KeyDown(IN_RELOAD) or LocalPlayer():KeyDown(IN_WALK) then return end
		suppress_until = RealTime() + 0.5

		return false
	end)

	-- Outfitter fixes
	local outfitter_ttt_perfmode = CreateClientConVar("outfitter_terrortown_perfmode", "1", true, false, "Only load outfits during spectate and endround and prepare", 0, 1)

	local function SetPerfMode(want_perf)
		--BUG:TODO: will not fix playermodels if they get unset!!! fix in outfitter.
		if not outfitter_ttt_perfmode:GetBool() then
			want_perf = false
			if not _G.TTT_OUTFITTER_PERF then return end
		end

		if want_perf and _G.TTT_OUTFITTER_PERF and not outfitter.IsHighPerf() then
			ErrorNoHalt("BUG: highperf not set but we are already in highperf??? Did you reload outfitter?")
			_G.TTT_OUTFITTER_PERF = false
		end

		if (want_perf and not _G.TTT_OUTFITTER_PERF) or (not want_perf and _G.TTT_OUTFITTER_PERF) then
			outfitter.SetHighPerf(want_perf, not want_perf)
		end

		_G.TTT_OUTFITTER_PERF = want_perf
	end

	--TODO: allow outfitter when spectating
	local function badModel(mdl)
		local mdl = ClientsideModel(mdl)
		local count = mdl:GetBoneCount()
		mdl:Remove()

		return count < 5
	end

	local downloading = {}

	local function outfitter_remount()
		for k, v in player() do
			local mdl, wsid = v:OutfitInfo()

			if mdl then
				if not util.IsValidModel(mdl) then
					if tonumber(wsid) then
						--TODO: use outfitter mounting system!!! This bypasses safety checks.
						easylua.Print("FIXING", wsid, mdl, v)
						chat.AddText("FIXING", v, " - ", mdl, " - ", wsid)

						if not downloading[wsid] then
							downloading[wsid] = true

							steamworks.DownloadUGC(wsid, function(path)
								game.MountGMA(path, true)
							end)
						end
					else
						easylua.Print("Can't reload", wsid, mdl, v)
						chat.AddText("Can't reload:", wsid)
					end
				elseif badModel(mdl) then
					easylua.Print("Did not catch", wsid, mdl, v)
				end
			end
		end
	end

	list.Set("ChatCommands", "outfitter-tttfix", outfitter_remount)
	list.Set("ChatCommands", "tttfix", outfitter_remount)
	concommand.Add("tttfix", outfitter_remount)
	concommand.Add("outfitter_remount_all", outfitter_remount)
	concommand.Add("outfitter_fix_error_models", outfitter_remount)

	-- Reminder message for reading the role guide
	local reminderCounts, reminderMax = {}, 2
	local reminderDefaultColor, reminderHighlightColor = Color(255, 235, 135), Color(140, 190, 255)

	local function showRoleGuideReminder(newRole)
		local pl = LocalPlayer()

		if IsValid(pl) and pl:IsTerror() then
			local role = newRole or pl:GetSubRole()
			if role == ROLE_NONE then return end

			reminderCounts[role] = (reminderCounts[role] or 0) + 1

			local roleData = roles.GetByIndex(role)

			chat.AddText(
				reminderDefaultColor, "Not sure how to play as ",
				roleData.ltcolor or roleData.color, LANG.TryTranslation(roleData.name),
				reminderDefaultColor, "? Press ",
				reminderHighlightColor, "F1",
				reminderDefaultColor, " and check the '",
				reminderHighlightColor, "TTT2 Guide",
				reminderDefaultColor, "' to learn about it!")
		end
	end

	hook.Add("TTT2UpdateSubrole", Tag, function(pl, oldRole, newRole)
		if pl != LocalPlayer()
			or oldRole == newRole
			or (reminderCounts[newRole] or 0) >= reminderMax then return end

		timer.Simple(1, function()
			if GetRoundState() != ROUND_ACTIVE then return end
			showRoleGuideReminder(newRole)
		end)
	end)

	-- Trigger things on TTT round hooks (eg. outfitter fixes)
	hook.Add("TTTBeginRound", Tag, function()
		SetPerfMode(true)
	end)

	hook.Add("TTTEndRound", Tag, function()
		SetPerfMode(false)
	end)

	-- Run these patches when things have initialized
	util.OnInitialize(function()
		-- Make the top-right notifications print to console
		if MSTACK then
			MSTACK.AddMessageExOriginal = MSTACK.AddMessageExOriginal or MSTACK.AddMessageEx

			function MSTACK:AddMessageEx(item)
				self:AddMessageExOriginal(item)

				MsgC(color_white, "[TTT2] ")
				MsgN(item.text)
			end
		end

		-- Make the centered notifications print to chat
		if EPOP then
			EPOP.ActivateMessageOriginal = EPOP.ActivateMessageOriginal or EPOP.ActivateMessage

			function EPOP:ActivateMessage()
				self:ActivateMessageOriginal()

				local item = self.messageQueue[1]
				if not item then return end

				local args = {}
				if item.title and item.title.text != "" then
					args[1] = item.title.color or color_white
					args[2] = item.title.text
				end

				if item.subtitle and item.subtitle.text != "" then
					if #args > 0 then
						-- Spacing between title and subtitle
						args[#args + 1] = " "
					end

					args[#args + 1] = item.subtitle.color or color_white
					args[#args + 1] = item.subtitle.text
				end

				chat.AddText(unpack(args))
			end
		end

		-- Replace Spectator Deathmatch's invasive PlayerBindPress hook to fix spectators not being able to press use on stuff
		if SpecDM then
			hook.Add("PlayerBindPress", "TTTGHOSTDMBINDS", function(ply, bind, pressed)
				if not IsValid(ply) or not ply:IsSpec() or not (ply.IsGhost and ply:IsGhost()) then return end

				if bind == "invnext" and pressed then
					WSWITCH:SelectNext()
					return true
				elseif bind == "invprev" and pressed then
					WSWITCH:SelectPrev()
					return true
				elseif bind == "+attack" then
					if WSWITCH:PreventAttack() then
						if not pressed then
							WSWITCH:ConfirmSelection()
						end

						return true
					end
				elseif bind == "+use" and pressed then
					-- Block pressing use as a ghost
					return true
				elseif bind == "+duck" and pressed then
					if not IsValid(ply:GetObserverTarget()) then
						GAMEMODE.ForcedMouse = true
					end
				end
			end)
		end
	end)
end

-- Shared amends

hook.Add("AowlGiveAmmo", Tag, function(pl)
	if pl.Unrestricted then return end
	return false
end)

hook.Add("CanPlyGotoPly", Tag, function(pl)
	if pl.Unrestricted then return end
	if GAMEMODE.round_state == ROUND_ACTIVE then return false, "no teleporting while round is active" end
end)

hook.Add("CanAutojump", Tag, function(pl)
	if pl.Unrestricted then return end
	if GAMEMODE.round_state == ROUND_ACTIVE then return false end
end)

hook.Add("CanPlyGoto", Tag, function(pl)
	if pl.Unrestricted then return end
	if GAMEMODE.round_state == ROUND_ACTIVE then return false, "no teleporting while round is active" end
end)

hook.Add("CanPlyTeleport", Tag, function(pl)
	if pl.Unrestricted then return end
	if GAMEMODE.round_state == ROUND_ACTIVE then return false, "no teleporting while round is active" end
end)

hook.Add("IsEntityTeleportable", Tag, function(pl)
	if pl.Unrestricted then return end
	return false
end)

hook.Add("CanSSJump", Tag, function(pl)
	if pl.Unrestricted then return end
	if GAMEMODE.round_state == ROUND_ACTIVE then return false, "no jumping while round is active" end
end)

hook.Add("CanPlyRespawn", Tag, function(pl)
	if pl.Unrestricted then return end
	if GAMEMODE.round_state == ROUND_ACTIVE then return false, "no respawning while round is active" end
end)

hook.Add("CanPlayerTimescale", Tag, function(pl)
	if pl.Unrestricted then return end
	return false, "not allowed in TTT"
end)

hook.Add("prone.CanEnter", Tag, function()
	return false
end)

-- Run these patches when things have initialized
util.OnInitialize(function()
	-- Since it's being disabled, completely rip out the "boxify" code since it adds several hooks worth of bloat on both realms
	do
		local PLAYER = FindMetaTable("Player")	-- pull this out of the do statement if we need to remove more player functions
		local boxifyTag = "boxify"

		for k,v in next, hook.GetTable() do
			for i in next, v do
				if i == boxifyTag then
					hook.Remove(k, i)
				end
			end
		end

		PLAYER.UnBoxify = nil

		list.Set("ChatCommands", "box")
		list.Set("ChatCommands", "boxify")
	end

	-- If the playermodel has an anim_attachment_head attachment then use that for hat position, else do what base TTT does (use head bone etc)
	if playermodels then
		function playermodels.GetHatPosition(pl)
			local pos, ang

			if IsValid(pl) then
				local headAttachId = pl:LookupAttachment("anim_attachment_head")

				if headAttachId > 0 then
					local data = pl:GetAttachment(headAttachId)

					pos, ang = data.Pos, data.Ang
				else
					local bone = pl:LookupBone("ValveBiped.Bip01_Head1")

					if bone then
						pos, ang = pl:GetBonePosition(bone)
					else
						pos, ang = pl:GetPos(), pl:GetAngles()

						local hullMins, hullMaxs = pl:GetHull()

						pos.z = pos.z + (hullMaxs.z - hullMins.z)
					end
				end
			end

			return pos, ang
		end
	end
end)