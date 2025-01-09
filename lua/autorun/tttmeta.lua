hook.Add("Initialize", "tttmeta-polyfill", function()
	local currentGamemode = engine.ActiveGamemode()
	if currentGamemode ~= "terrortown" then
		-- this should never happen but here are some polyfills to prevent errors everywhere

		local PLY = FindMetaTable("Player")
		function PLY:IsTerror() return true end

		function GetRoundState() return 3 end -- always active

		LANG = {
			GetNameParam = function(str) return str end,
			Msg = function(...) end,
			MsgAll = function(...) end,
			NameParam = function(name) return name end,
			Param = function(name) return name end,
			ProcessMsg = function(...) end,
			AddToLanguage = function(...) end
		}
	end
end)

local Tag = "tttfix"

require("hookextras")

do
	-- Attempt restoring failed hooks once
	local restored = setmetatable({}, {
		__index = function(self, k)
			local t = {}
			self[k] = t

			return t
		end
	})

	HOOK_FIXER_ENABLED = true

	timer.Create("tttfix_hook_amnesty_experiment", 0.997, 0, function()
		if HOOK_FIXER_ENABLED == false then return end

		for hook_name, failed_hooks in pairs(hook.GetFailed and hook.GetFailed() or {}) do
			for hook_cb_name, faildata in pairs(failed_hooks) do
				if not restored[hook_name][hook_cb_name] then
					local existing_func = hook.GetTable()[hook_name][hook_cb_name]
					restored[hook_name][hook_cb_name] = faildata

					if not existing_func then
						hook.Restore(hook_name, hook_cb_name)
					end
				end
			end
		end
	end)
end


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
		["drop"] = true,
		["dropcoin"] = true,
		["dropcoins"] = true,
		["economy"] = true,
		["findfag"] = true,
		["findlag"] = true,
		["friendly"] = true,
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
		["raffle"] = true,
		["ragdoll"] = true,
		["ragdollize"] = true,
		["ragmod"] = true,
		["ragmodset"] = true,
		["spec"] = true,
		["spectate"] = true,
		["sprayroulette"] = true,
		["tc"] = true,
		["unjail"] = true,
		["unragdoll"] = true,
		["unragdollize"] = true,
		["unreserve"] = true,
		["untc"] = true,
		["vomit"] = true,
		["wandercam"] = true
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

	-- Disable discord messages for alive players
	hook.Add("PlayerCanSeeDiscordChat", Tag, function(_, _, _, ply)
		if ply:IsTerror() then return false end
	end)

	-- Give more detailed karma feedback
	util.AddNetworkString("TTT_KarmaFeedback")

	local total_karma = 0
	hook.Add("TTTKarmaGivePenalty", "DetailedKarma", function(ply, penalty, victim)
		if not IsValid(ply) then return end

		total_karma = total_karma + penalty
		timer.Create("TTT_KarmaFeedback", 1, 1, function()
			net.Start("TTT_KarmaFeedback")
			net.WriteUInt(math.Round(total_karma), 8)
			net.WriteString(victim:Nick())
			net.Send(ply)

			total_karma = 0
		end)
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

			-- Helper command to quickly save the current MapVote config values
			if MapVote then
				aowl.AddCommand("savemapvoteconfig", "Writes the current MapVote.Config table to MapVote's config.txt file", function(pl, line, target)
					if not istable(MapVote.Config) then
						MapVote.Config = {}
					end

					file.Write("mapvote/config.txt", util.TableToJSON(MapVote.Config))

					print("Wrote MapVote.Config table to 'mapvote/config.txt'. Called by " .. (IsValid(pl) and tostring(pl) or "CONSOLE"))
				end,
				"developers", true)
			end
		end

		if PROPSPEC then
			PROPSPEC.Start_Original = PROPSPEC.Start_Original or PROPSPEC.Start

			function PROPSPEC.Start(pl, ent)
				-- Don't allow spectators to possess Prop Disguiser props
				if IsValid(ent.PropDisguiserOwner) then return end

				PROPSPEC.Start_Original(pl, ent)
			end
		end

		-- Disable an obsolete engine protect hook we have if it's there - all it really does now is print a useless message in console
		hook.Remove("EntityRemoved", "dont_remove_players")

		-- Disable an engine protect hook that isn't needed at all in TTT, free up a bit of processing
		hook.Remove("EntityTakeDamage", "weapon_striderbuster_anticrash")

		-- Disable autorepairing windows
		hook.Remove("OnEntityCreated", "func_breakable_surf_autorepair")

		-- Disable Meta sandbox's fall crushing script - TTT handles this already
		hook.Remove("OnPlayerHitGround", "crush_players_npcs")

		-- Disable serverside hooks from other things that don't work or are obsolete in TTT - remove hook bloat and free up some processing
		hook.Remove("PlayerInitialSpawn", "__R4gM0d__")
		hook.Remove("PlayerSpawn", "__R4gM0d__")
		hook.Remove("PlayerDeath", "__R4gM0d__")
		hook.Remove("PlayerNoClip", "AowlJail")
		hook.Remove("PlayerDisconnected", "AowlJail")
		hook.Remove("PlayerSay", "kaboomkaboom")
		hook.Remove("PostPlayerDeath", "kill_silent")
		hook.Remove("PlayerSlowThink", "ms_drowning")
		hook.Remove("OnEntityWaterLevelChanged", "ms_drowning")
		hook.Remove("PlayerSpawn", "ms_drowning")
		hook.Remove("PlayerShouldTakeDamage", "physgun_crosstreams")
		hook.Remove("CanPlayerHax", "RP_FriendlyMode")
		hook.Remove("EntityTakeDamage", "RP_FriendlyMode")
		hook.Remove("PlayerShouldTakeDamage", "RP_FriendlyMode")
		hook.Remove("PlayerLeftTrigger", "RP_FriendlyMode")
		hook.Remove("SetupPlayerVisibility", "Spectate")
		hook.Remove("PlayerDisconnected", "TC")
		hook.Remove("PlayerShouldTakeDamage", "TC")
		hook.Remove("CanPlayerHax", "useful_commands_ragdollize")
		hook.Remove("CanPlayerSuicide", "useful_commands_ragdollize")
		hook.Remove("CanPlyTeleport", "useful_commands_ragdollize")
		hook.Remove("PlayerNoClip", "useful_commands_ragdollize")
		hook.Remove("PlayerSwitchFlashlight", "useful_commands_ragdollize")
		hook.Remove("PlayerCanPickupWeapon", "useful_commands_ragdollize")
		hook.Remove("CanPlayerEnterVehicle", "useful_commands_ragdollize")
		hook.Remove("EntityRemoved", "useful_commands_ragdollize_cleanup")
		hook.Remove("EntityRemoved", "useful_commands_ragdollize_ragdollremove")
		hook.Remove("FindUseEntity", "useless")
		hook.Remove("PlayerSay", "playersay_emitsound")
		timer.Remove("AowlJail")
		timer.Remove("physgun_crosstreams")
	end)
else
	net.Receive("TTT_KarmaFeedback", function()
		--local penalty = net.ReadUInt(8)
		--local victimName = net.ReadString()

		--[[chat.AddText(
			Color(255, 0, 0),
			"Karma",
			Color(255, 255, 255),
			string.format(": Lost %d karma for harming %s", penalty, victimName)
		)]]
	end)

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
	-- Added perma debug prints until we figure out why it doesn't print
	hook.Add("TTTPrepareRound", Tag, function()
		Msg"[TTT Fix] hook.Run() " print("TTTPrepareRound")
	end)

	hook.Add("TTTBeginRound", Tag, function()
		Msg"[TTT Fix] hook.Run() " print("TTTBeginRound")
		SetPerfMode(true)
	end)

	hook.Add("TTTEndRound", Tag, function()
		Msg"[TTT Fix] hook.Run() " print("TTTEndRound")
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

		if VOICE then
			function VOICE.UpdatePlayerVoiceVolume(ply)
				local mute = VOICE.GetPreferredPlayerVoiceMuted(ply)
				if ply.SetMuted then
					ply:SetMuted(mute)
				end

				local vol = VOICE.GetPreferredPlayerVoiceVolume(ply)
				if VOICE.cv.duck_spectator:GetBool() and ply:IsSpec() then
					vol = vol * (1 - VOICE.cv.duck_spectator_amount:GetFloat())
				end
				local out_vol = vol

				local func = VOICE.ScalingFunctions[VOICE.cv.scaling_mode:GetString()]
				if isfunction(func) then
					out_vol = func(vol)
				end

				ply:SetVoiceVolumeScale(out_vol)

				-- Once our version of TTT2 updates, we won't need this patch - this console print will remind us
				if GAMEMODE.Version != "0.13.1b" then
					MsgC(Color(255, 50, 50), "The VOICE.UpdatePlayerVoiceVolume patch should no longer be needed on this version of TTT2! It can be removed safely.\n")
				end

				return out_vol, mute
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

		-- Restrict custom picker command to unrestricted devs
		-- Yes, this is all clientside so it could be circumvented if you're hacking, but you would be using something else to wallhack at that point, so...
		local cmdTable = concommand.GetTable()
		local pickerCmd = cmdTable.picker_toggle
		if pickerCmd then
			local function runIfAllowed(func)
				local pl = LocalPlayer()
				if IsValid(pl) and pl:IsAdmin() and pl.Unrestricted then
					func()
				end
			end

			concommand.Add("picker_toggle", function()
				runIfAllowed(pickerCmd)
			end)

			local pickerOnCmd = cmdTable["+picker"]
			if pickerOnCmd then
				concommand.Add("+picker", function()
					runIfAllowed(pickerOnCmd)
				end)
			end

			local pickerOffCmd = cmdTable["-picker"]
			if pickerOffCmd then
				concommand.Add("-picker", function()
					runIfAllowed(pickerOffCmd)
				end)
			end
		end

		-- Disable on-demand flymode toggling (keep actual flymode code in case we make something that uses it)
		list.Set("ChatCommands", "fly")
		concommand.Add("+fly", emptyFunc)
		concommand.Add("-fly", emptyFunc)
		concommand.Add("fly", emptyFunc)
		concommand.Add("togglefly", emptyFunc)
		hook.Remove("PlayerBindPress", "flymoving")

		-- Disable rearview commands (it's cool but kinda cheaty for TTT)
		concommand.Add("+rear", emptyFunc)
		concommand.Add("-rear", emptyFunc)
		hook.Remove("CalcView", "rearview")
		hook.Remove("PreDrawViewModel", "rearview")

		-- Disable Metastruct nametag rendering
		hook.Remove("PostDrawTranslucentRenderables", "nametags")
		hook.Remove("UpdateAnimation", "nametags")

		-- Disable clientside hooks from other things that don't work or are obsolete in TTT - remove hook bloat and free up some processing
		hook.Remove("CalcView", "DeathView")
		hook.Remove("ShouldDrawLocalPlayer", "DeathView")
		hook.Remove("HUDShouldDraw", "hide_hud")
		hook.Remove("HUDPaint", "oxygen_hud")
		hook.Remove("HUDPaint", "raffler")
		hook.Remove("HUDDrawTargetID", "RP_FriendlyMode")
		hook.Remove("HUDShouldDraw", "tobecontinued")
		hook.Remove("RenderScreenspaceEffects", "tobecontinued")
		hook.Remove("entity_killed", "tobecontinued")
		hook.Remove("player_spawn", "tobecontinued")
		hook.Remove("PlayerBindPress", "ToolMenuFix")
		hook.Remove("CalcView", "hands_thirdperson")
		hook.Remove("OnPlayerPhysicsPickup", "hands_thirdperson")
		hook.Remove("OnPlayerPhysicsDrop", "hands_thirdperson")
		hook.Remove("KeyPress", "hands_thirdperson")
		hook.Remove("InputMouseApply", "hands_thirdperson")
		hook.Remove("PlayerBindPress", "hands_thirdperson")
		hook.Remove("Think", "hands_thirdperson")
		hook.Remove("KeyPress", "sent_slots")
	end)
end

-- Shared amends

hook.Add("AowlGiveAmmo", Tag, function(pl)
	if pl.Unrestricted then return end
	return false
end)

hook.Add("CanPlyGotoPly", Tag, function(pl)
	if pl.Unrestricted then return end
	if GetRoundState() == ROUND_ACTIVE then return false, "no teleporting while round is active" end
end)

hook.Add("CanAutojump", Tag, function(pl)
	if pl.Unrestricted then return end
	if GetRoundState() == ROUND_ACTIVE then return false end
end)

hook.Add("CanPlyGoto", Tag, function(pl)
	if pl.Unrestricted then return end
	if GetRoundState() == ROUND_ACTIVE then return false, "no teleporting while round is active" end
end)

hook.Add("CanPlyTeleport", Tag, function(pl)
	if pl.Unrestricted then return end
	if GetRoundState() == ROUND_ACTIVE then return false, "no teleporting while round is active" end
end)

hook.Add("IsEntityTeleportable", Tag, function(pl)
	if pl.Unrestricted then return end
	return false
end)

hook.Add("CanSSJump", Tag, function(pl)
	if pl.Unrestricted then return end
	if GetRoundState() == ROUND_ACTIVE then return false, "no jumping while round is active" end
end)

hook.Add("CanPlyRespawn", Tag, function(pl)
	if pl.Unrestricted then return end
	if GetRoundState() == ROUND_ACTIVE then return false, "no respawning while round is active" end
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
	local PLAYER = FindMetaTable("Player")

	-- Since it's being disabled, completely rip out the "boxify" code since it adds several hooks worth of bloat on both realms
	do
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

	-- Remove extra ragmod commands
	list.Set("ChatCommands", "ragmodset")
	concommand.Add("ragmodset", emptyFunc)

	-- Remove kill_silent command
	concommand.Add("kill_silent", emptyFunc)

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

	-- Disable processing the widgets module - nothing uses it in TTT and no addons use it, so let's free up a bit of processing
	hook.Remove("PlayerTick", "TickWidgets")
	hook.Remove("PostDrawEffects", "RenderWidgets")

	-- Disable GoldSrc movement quirk replication - shouldn't have this in TTT
	hook.Remove("SetupMove", "GoldSrcGStrafe")
	hook.Remove("SetupMove", "GoldSrcUnduck")

	-- Disable custom footsteps script
	concommand.Add("footstep_sound", emptyFunc)
	hook.Remove("PlayerFootstep", "customfootstep")

	-- Disable shared hooks from other things that don't work or are obsolete in TTT - remove hook bloat and free up some processing
	hook.Remove("EntityRemoved", "npcspec")
	hook.Remove("Move", "physgun_cascade") -- Doesn't need to be running all the time, plus if it's ever spawned in TTT, I feel it shouldn't trap people like it does in Sandbox
	hook.Remove("PlayerNoClip", "physgun_cascade")
	hook.Remove("PlayerFly", "restrictors")
	hook.Remove("PlayerNoClip", "restrictors")
	hook.Remove("PlayerNoClip", "TC")

	PlayerAFKIdle = nil -- Cleanup global func from npcspec/wandercam
end)
