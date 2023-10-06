-- Moved from srvaddons
-- No longer required: if engine.ActiveGamemode() ~= 'terrortown' then return end

local Tag = 'tttfix'

if SERVER then
	AddCSLuaFile()

	util.OnInitialize(function()
		if crosschat then
			crosschat.GetForcedTeam = function()
				return 1
			end
		end
	end)

	local badcmds = {
		['ragdoll'] = true,
		['ragdollize'] = true,
		['vomit'] = true,
		['puke'] = true,
		['ooc'] = true,
		['advert'] = true,
		['headexplode'] = true,
		['kidmode'] = true,
		['jail'] = true,
		['hoborope'] = true,
		['box'] = true,
		['boxify'] = true,
	}

	hook.Add('AowlCommandAdded', Tag, function(cmd)
		if badcmds[cmd] then
			aowl.cmds[cmd] = nil
		end
	end)

	local ttt_allow_ooc = CreateConVar('ttt_allow_ooc', '1')

	hook.Add('PlayerCanSeePlayersChat', Tag, function(text, teamOnly, listener, sender)
		if sender.always_ooc or (ttt_allow_ooc:GetBool() and text and (text:find('OOC ', 1, true) or text:find(' OOC', 1, true))) then
			if not sender.sent_ooc then
				sender.sent_ooc = true
				sender:ChatPrint('[Notice] OOC chat can be seen by everyone. You will get banned for abusing OOC to reveal traitors.')
			end

			return true
		end
	end)
end

AOWL_NO_TEAMS = true

hook.Add('CanPlyGotoPly', Tag, function(pl)
	if pl.Unrestricted then return end
	if GAMEMODE.round_state == 3 then return false, 'no teleporting while round is active' end
end)

hook.Add('CanAutojump', Tag, function(pl)
	if pl.Unrestricted then return end
	if GAMEMODE.round_state == 3 then return false end
end)

hook.Add('CanPlyGoto', Tag, function(pl)
	if pl.Unrestricted then return end
	if GAMEMODE.round_state == 3 then return false, 'no teleporting while round is active' end
end)

hook.Add('CanPlyTeleport', Tag, function(pl)
	if pl.Unrestricted then return end
	if GAMEMODE.round_state == 3 then return false, 'no teleporting while round is active' end
end)

hook.Add('IsEntityTeleportable', Tag, function(pl)
	if pl.Unrestricted then return end

	return false
end)

hook.Add('CanSSJump', Tag, function(pl)
	if pl.Unrestricted then return end
	if GAMEMODE.round_state == 3 then return false, 'no jumping while round is active' end
end)

hook.Add('CanPlyRespawn', Tag, function(pl)
	if pl.Unrestricted then return end
	if GAMEMODE.round_state == 3 then return false, 'no respawning while round is active' end
end)

hook.Add('CanPlayerTimescale', Tag, function(pl)
	if pl.Unrestricted then return end

	return false, 'not allowed in ttt'
end)

if CLIENT then
	local suppress_until = 0

	hook.Add('ScoreboardShow', Tag, function(reason)
		if reason ~= 'ms' then return end
		if suppress_until > RealTime() then return end
		if LocalPlayer():KeyDown(IN_SPEED) or LocalPlayer():KeyDown(IN_USE) or LocalPlayer():KeyDown(IN_RELOAD) or LocalPlayer():KeyDown(IN_WALK) then return end
		suppress_until = RealTime() + 0.5

		return false
	end)

	local played_60
	local played_120
	local played_180
	local played_30
	local last_play = 0
	local ttt_extra_sounds = CreateClientConVar('ttt_extra_sounds', '1', true, false, 'Play countdown sounds', 0, 1)

	local function playSound(snd)
		if not ttt_extra_sounds:GetBool() then return end

		if RealTime() - last_play < 3 then
			print('TOO EARLY?', snd)

			return
		end

		surface.PlaySound(snd)
		print('SND', snd)
		last_play = RealTime()
	end

	local outfitter_ttt_perfmode = CreateClientConVar('outfitter_ttt_perfmode', '0', true, false, 'Only load outfits during spectate and endround and prepare', 0, 1)

	local function SetPerfMode(want_perf)
		--BUG:TODO: will not fix playermodels if they get unset!!! fix in outfitter.
		if not outfitter_ttt_perfmode:GetBool() then
			want_perf = false
			if not _G.TTT_OUTFITTER_PERF then return end
		end

		if want_perf and _G.TTT_OUTFITTER_PERF and not outfitter.IsHighPerf() then
			ErrorNoHalt('BUG: highperf not set but we are already in highperf??? Did you reload outfitter?')
			_G.TTT_OUTFITTER_PERF = false
		end

		if (want_perf and not _G.TTT_OUTFITTER_PERF) or (not want_perf and _G.TTT_OUTFITTER_PERF) then
			outfitter.SetHighPerf(want_perf, not want_perf)
			print('outfitter.SetHighPerf', want_perf)
		end

		_G.TTT_OUTFITTER_PERF = want_perf
	end

	do
		local Tag = 'tttfix'
		local played_begin_ever

		hook.Add('TTTBeginRound', Tag, function()
			if not played_begin_ever then
				played_begin_ever = true
				playSound'npc/overwatch/cityvoice/f_anticitizenreport_spkr.wav'
			end

			print('TTTBeginRound')
			SetPerfMode(true)
		end)

		hook.Add('TTTEndRound', Tag, function()
			print('TTTEndRound')

			timer.Simple(5, function()
				played_30 = false
				played_60 = false
				played_120 = false
				played_180 = false
			end)

			SetPerfMode(false)
		end)

		hook.Add('TTTPrepareRound', Tag, function()
			print('TTTPrepareRound')
		end)
	end

	local snd_time60 = 'npc/overwatch/cityvoice/fcitadel_1minutetosingularity.wav'
	local snd_time120 = 'npc/overwatch/cityvoice/fcitadel_2minutestosingularity.wav'
	local snd_time180 = 'npc/overwatch/cityvoice/fcitadel_3minutestosingularity.wav'
	local snd_time30 = 'npc/overwatch/cityvoice/fcitadel_30sectosingularity.wav'

	timer.Create(Tag, 0, 0, function()
		-- https://github.com/TTT-2/TTT2/blob/fc797b61282fbf9d69de834144cbc6ed8d920a1b/gamemodes/terrortown/gamemode/shared/hud_elements/tttroundinfo/pure_skin_roundinfo.lua#L64
		local client = LocalPlayer()
		if not client:IsValid() or not client.IsActive then return end
		local round_state = GAMEMODE.round_state
		local round_prep = round_state == ROUND_PREP
		local round_active = round_state == ROUND_ACTIVE
		local round_post = round_state == ROUND_POST
		local round_wait = round_state == ROUND_WAIT
		local isHaste = HasteMode() and round_state == ROUND_ACTIVE
		local endtime = GetGlobalFloat('ttt_round_end', 0) - CurTime()
		--TODO: haste mode and traitor is isOmniscient? What about dead?
		local remaining = isHaste and (GetGlobalFloat('ttt_haste_end', 0) - CurTime())
		local isOmniscient = not client:IsActive() or client:GetSubRoleData().isOmniscientRole

		if not isOmniscient then
  		remaining = math.max(remaining or 0, endtime)
		end

		if remaining then

			if not played_180 and remaining < 180 then
				played_180 = true
				playSound(snd_time180)
			end

			if not played_120 and remaining < 120 then
				played_120 = true
				playSound(snd_time120)
			end

			if not played_60 and remaining < 60 then
				played_60 = true
				playSound(snd_time60)
			end

			if not played_30 and remaining < 30 then
				played_30 = true
				playSound(snd_time30)
			end

			if played_180 and remaining > 180 then
				played_180 = false
			end

			if played_120 and remaining > 120 then
				played_120 = false
			end

			if played_60 and remaining > 60 then
				played_60 = false
			end

			if played_30 and remaining > 30 then
				played_30 = false
			end
		end
	end)

	--	print('endtime=',endtime/60)
	--print('remaining=',remaining/60)
	--print('GAMEMODE.round_state=',GAMEMODE.round_state)
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
						chat.AddText('FIXING', v, ' - ', mdl, ' - ', wsid)
						easylua.Print('FIXING', wsid, mdl, v)

						if not downloading[wsid] then
							downloading[wsid] = true

							steamworks.DownloadUGC(wsid, function(path)
								game.MountGMA(path, true)
							end)
						end
					else
						easylua.Print('Can\'t reload', wsid, mdl, v)
						chat.AddText('Can\'t reload:', wsid)
					end
				elseif badModel(mdl) then
					easylua.Print('Did not catch', wsid, mdl, v)
				end
			end
		end
	end

	list.Set('ChatCommands', 'outfitter-tttfix', outfitter_remount)
	list.Set('ChatCommands', 'tttfix', outfitter_remount)
	concommand.Add('tttfix', outfitter_remount)
	concommand.Add('outfitter_remount_all', outfitter_remount)
	concommand.Add('outfitter_fix_error_models', outfitter_remount)
end
