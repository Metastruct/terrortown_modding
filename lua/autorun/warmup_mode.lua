local tag = "TTTWarmupMode"
local globalBoolTag = "ttt_warmup_mode"

if SERVER then
	local specCheckTag = tag .. "_SpecCheck"

	local function Respawn(pl)
		pl:SetMaxHealth(100)
		pl:SetHealth(100)

		pl:SpawnForRound(true)
		pl:SetActiveInRound(true)

		hook.Run("PlayerLoadout", pl, true)

		pl:SelectWeapon("weapon_ttt_unarmed")
	end

	function TTTSetWarmupMode(toggle)
		if toggle then
			gameloop.StopWinChecks()
			gameloop.StopTimers()
			gameloop.SetRoundState(ROUND_ACTIVE)
			gameloop.SetPhaseEnd(CurTime())

			SetGlobal2Bool(globalBoolTag, true)

			for k, v in player.Iterator() do
				if not v:IsTerror() and v:ShouldSpawn() then
					Respawn(v)
				else
					v:Give("weapon_ttt_testing_roleswitch")
					v:SetCredits(100)
				end
			end

			-- Periodic check to ensure force-spectators who undo that setting are respawned in
			timer.Create(specCheckTag, 1, 0, function()
				for k, v in player.Iterator() do
					if v:IsSpec() then
						if v:GetForceSpec() then
							if v:WasActiveInRound() then
								v:SetActiveInRound(false)
							end
						elseif not v:WasActiveInRound() then
							Respawn(v)
						end
					end
				end
			end)

			hook.Add("DoPlayerDeath", tag, function(pl)
				-- Don't leave credits on the corpse
				pl:SetCredits(0)
			end)

			hook.Add("PostPlayerDeath", tag, function(pl)
				local name = "TTTWarmupRespawn" .. pl:EntIndex()

				timer.Simple(2, function()
					if not IsValid(pl) then return end

					timer.Create(name, 2, 0, function()
						if not IsValid(pl) or pl:IsTerror() or not pl:ShouldSpawn() then
							timer.Remove(name)
							return
						elseif pl:IsReviving() then
							-- Halt respawning if they're being revived
							return
						end

						Respawn(pl)

						timer.Remove(name)
					end)
				end)
			end)

			hook.Add("PlayerSpawn", tag, function(pl)
				timer.Simple(0.05, function()
					if not IsValid(pl) then return end

					pl:Give("weapon_ttt_testing_roleswitch")
					pl:SetCredits(100)
				end)
			end)

			local corpseLifetime = 90

			hook.Add("TTTOnCorpseCreated", tag, function(rag)
				timer.Simple(corpseLifetime - 2, function()
					if not IsValid(rag) then return end

					timer.Create(tag .. "RagFlash" .. rag:EntIndex(), 0.1, 0, function()
						if not IsValid(rag) then return end

						rag:SetRenderMode(RENDERMODE_TRANSCOLOR)

						local col = rag:GetColor()
						col.a = col.a == 0 and 255 or 0

						rag:SetColor(col)
					end)
				end)

				timer.Simple(corpseLifetime, function()
					if IsValid(rag) then
						rag:Remove()
					end
				end)
			end)
		else
			local wasEnabled = GetGlobal2Bool(globalBoolTag, false)

			timer.Remove(specCheckTag)
			hook.Remove("DoPlayerDeath", tag)
			hook.Remove("PostPlayerDeath", tag)
			hook.Remove("PlayerSpawn", tag)
			hook.Remove("TTTOnCorpseCreated", tag)

			SetGlobal2Bool(globalBoolTag, false)

			if wasEnabled then
				gameloop.Reset()
			end
		end
	end

	-- Add vote commands
	if GVote then
		aowl.AddCommand("warmup", "Creates a vote to start warmup mode", function(pl, line, target)
			if GetGlobal2Bool(globalBoolTag, false) then
				return false, "Warmup mode is already on. Use !endwarmup to end it."
			end

			local vote = GVote.Vote(
				("Enable warmup mode? (Needs 75%% yes votes)\n\nVoter: %s"):format(IsValid(pl) and pl:Name() or "SERVER"),
				"Yes",
				"No",
				function(results)
					local yesVotes, needed = table.Count(results.Yes), math.max(math.floor(#player.GetHumans() * 0.75), 1)

					if yesVotes >= needed then
						TTTSetWarmupMode(true)
					else
						EPOP:AddMessage(nil, "Vote failed!", string.format("Not enough Yes votes to pass - %s / %s", yesVotes, needed))
					end
				end)
		end,
		"players", true)

		aowl.AddCommand("endwarmup", "Creates a vote to end warmup mode", function(pl, line, target)
			if not GetGlobal2Bool(globalBoolTag, false) then
				return false, "Warmup mode isn't on. Use !warmup to start it."
			end

			local vote = GVote.Vote(
				("End warmup mode? (Needs 50%% yes votes)\n\nVoter: %s"):format(IsValid(pl) and pl:Name() or "SERVER"),
				"Yes",
				"No",
				function(results)
					local yesVotes, needed = table.Count(results.Yes), math.max(math.floor(#player.GetHumans() * 0.5), 1)

					if yesVotes >= needed then
						TTTSetWarmupMode(false)
					else
						EPOP:AddMessage(nil, "Vote failed!", string.format("Not enough Yes votes to pass - %s / %s", yesVotes, needed))
					end
				end)
		end,
		"players", true)
	end

	local reminderText = "Wanting to mess around and test things?\nUse !warmup to end this round and start warmup mode."
	local reminderSound = "garrysmod/ui_click.wav"

	-- Display a reminder on round start when the active player count is 4 or less
	hook.Add("TTTBeginRound", tag, function()
		timer.Simple(5, function()
			if GetGlobal2Bool(globalBoolTag, false) then return end

			local pls = 0

			for k, v in player.Iterator() do
				if v:WasActiveInRound() then
					pls = pls + 1
				end
			end

			if pls <= 4 then
				LANG.MsgAll(reminderText)

				local filter = RecipientFilter()
				filter:AddAllPlayers()

				EmitSound(reminderSound, vector_origin, 0, CHAN_AUTO, 1, 0, 0, 90, 1, filter)
			end
		end)
	end)

	-- Display a reminder to the player if they join and the game is still waiting for players
	hook.Add("TTT2PlayerReady", tag, function(pl)
		timer.Simple(10, function()
			if not IsValid(pl)
				or pl:IsTerror()
				or GetGlobal2Bool(globalBoolTag, false)
				or gameloop.GetRoundState() != ROUND_WAIT
			then return end

			LANG.Msg(pl, reminderText)

			local filter = RecipientFilter()
			filter:AddPlayer(pl)

			EmitSound(reminderSound, vector_origin, 0, CHAN_AUTO, 1, 0, 0, 90, 1, filter)
		end)
	end)
else
	local hudText = "WARMUP MODE"
	local hudHelpText1, hudHelpText2 = "No winning, no timer. Everyone respawns, has testing tools and infinite credits.", "Use !endwarmup to start playing again."
	local fontTitleName, fontHelpName = "PureSkinRole", "PureSkinItemInfo"

	local nBlack, nWhite, nAlpha = 0, 255, 200

	local function DrawText(text, x, y, alphaScale)
		surface.SetTextColor(nBlack, nBlack, nBlack, nAlpha * alphaScale)
		surface.SetTextPos(x + 2, y + 2)
		surface.DrawText(text)

		surface.SetTextColor(nWhite, nWhite, nWhite, nWhite * alphaScale)
		surface.SetTextPos(x, y)
		surface.DrawText(text)
	end

	hook.Add("HUDPaint", tag, function()
		if not GetGlobal2Bool(globalBoolTag, false) then return end

		local sWHalf = ScrW() / 2
		local hScale = ScrH() / 1440
		local alphaScale = 0.7 + (((math.sin(RealTime()) + 1) / 2) * 0.3)

		-- Title
		surface.SetFont(fontTitleName)

		local w, h = surface.GetTextSize(hudText)
		local x, y = sWHalf - (w / 2), 200 * hScale

		DrawText(hudText, x, y, alphaScale)

		-- Help text 1
		y = y + h + 4

		surface.SetFont(fontHelpName)

		w, h = surface.GetTextSize(hudHelpText1)
		x = sWHalf - (w / 2)

		DrawText(hudHelpText1, x, y, alphaScale)

		-- Help text 2
		y = y + h + 2

		w, h = surface.GetTextSize(hudHelpText2)
		x = sWHalf - (w / 2)

		DrawText(hudHelpText2, x, y, alphaScale)
	end)
end