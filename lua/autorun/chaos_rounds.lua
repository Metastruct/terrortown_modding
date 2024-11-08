--[[
	/!\ DISCLAIMER /!\

	This file is responsible for the internal logic of chaos round, if you want to create a chaos round,
	navigate to lua/chaos_rounds/template.lua. Modify the template.lua file in whichever way you feel you
	need to make your chaos round work and save it in the same directory under a different name.

	Do NOT override the original file!
]]--

local TAG = "TTT_ChaosRounds"
local ROUNDS = {}

local cvar_chance = CreateConVar("ttt_chaos_chance", "0.02", {FCVAR_NOTIFY, FCVAR_ARCHIVE}, "Chance for a chaos round to occur")

function RegisterChaosRound(name, round)
	if istable(name) then
		round = name
		name = name.Name
	end

	ROUNDS[name] = round

	return round
end

local files, _ = file.Find("chaos_rounds/*.lua", "LUA")
for _, f in pairs(files) do
	local path = "chaos_rounds/" .. f
	local r = include(path)
	if not istable(r) then continue end
	r.Name = isstring(r.Name) and r.Name or f:gsub("%.lua$", "")
	ROUNDS[r.Name] = r

	if SERVER then
		AddCSLuaFile(path)
	end
end

local CHAOS_STATE_SELECTED = 1
local CHAOS_STATE_ROUND_START = 2
local CHAOS_STATE_ROUND_FINISH = 3

if SERVER then
	resource.AddFile("materials/vgui/ttt/icon_chaos_round.vtf")
	resource.AddFile("materials/vgui/ttt/icon_chaos_round.vmt")

	util.AddNetworkString(TAG)

	local ACTIVE_CHAOS_ROUND
	local CHAOS_ROUND_DONE = false -- once per map

	local function network_state(round_key, state)
		net.Start(TAG)
		net.WriteString(round_key)
		net.WriteUInt(state, 32)
		net.Broadcast()
	end

	local force_chaos_round = nil
	function ForceChaosRound(round_name)
		if round_name == nil then
			force_chaos_round = true
		else
			if not ROUNDS[round_name] then
				ErrorNoHalt("Chaos round \'" .. round_name .. "\' does not exist on server!")

				return
			end

			force_chaos_round = round_name
		end
	end

	local function select_chaos_round()
		if not force_chaos_round then
			if CHAOS_ROUND_DONE then return end
			if math.random() > cvar_chance:GetFloat() then return end
		end

		local keys = table.GetKeys(ROUNDS)
		local rand_key = keys[math.random(#keys)]

		if type(force_chaos_round) == "string" then
			rand_key = force_chaos_round
		end

		if not ROUNDS[rand_key] then return end

		ACTIVE_CHAOS_ROUND = ROUNDS[rand_key]

		network_state(ACTIVE_CHAOS_ROUND.Name, CHAOS_STATE_SELECTED)
		if isfunction(ACTIVE_CHAOS_ROUND.OnSelected) then
			ACTIVE_CHAOS_ROUND:OnSelected()
		end

		hook.Add("TTTPrepareRound", TAG, function()
			if isfunction(ACTIVE_CHAOS_ROUND.OnPrepare) then
				ACTIVE_CHAOS_ROUND:OnPrepare()
			end

			hook.Remove("TTTPrepareRound", TAG)
		end)
	end

	local function begin_chaos_round()
		if not ACTIVE_CHAOS_ROUND then return end

		network_state(ACTIVE_CHAOS_ROUND.Name, CHAOS_STATE_ROUND_START)
		if isfunction(ACTIVE_CHAOS_ROUND.Start) then
			ACTIVE_CHAOS_ROUND:Start()
		end
	end

	local function end_chaos_round()
		if not ACTIVE_CHAOS_ROUND then return end

		local round = ACTIVE_CHAOS_ROUND
		CHAOS_ROUND_DONE = true
		ACTIVE_CHAOS_ROUND = nil

		network_state(round.Name, CHAOS_STATE_ROUND_FINISH)
		if isfunction(round.Finish) then
			round:Finish()
		end
	end

	hook.Add("TTTEndRound", TAG, function()
		end_chaos_round()
		select_chaos_round()
	end)

	hook.Add("TTTBeginRound", TAG, begin_chaos_round)
end

if CLIENT then
	local COEF_W, COEF_H = ScrW() / 2560, ScrH() / 1440
	local ACTIVE_CHAOS_ROUND
	local SHOW_SELECTION = CreateClientConVar("ttt_chaos_round_selection", "1", true, true, "Shows the selection UI for chaos rounds", 0, 1)
	local SOUND_VOLUME = CreateClientConVar("ttt_chaos_round_sound_volume", "0.5", true, false, "Volume of the chaos round sounds", 0, 1)

	local function show_selection()
		local f
		if SHOW_SELECTION:GetBool() then
			local function paint_bg(w, h, r, g, b, alpha, mat)
				surface.SetDrawColor(r, g, b, alpha)

				if mat then
					surface.SetMaterial(mat)
					surface.DrawTexturedRect(0, 0, w, h)
				else
					surface.DrawRect(0, 0, w, h)
				end

				surface.SetDrawColor(255, 255, 255, 20)
				surface.DrawRect(0, 0, w - 2, 2)
				surface.DrawRect(0, 2, 2, h - 2)

				surface.SetDrawColor(0, 0, 0, 200)
				surface.DrawRect(w - 2, 0, 2, h)
				surface.DrawRect(0, h - 2, w, 2)
			end

			f = vgui.Create("DPanel")
			f:SetSize(600 * COEF_W, 220 * COEF_H)
			f:SetPos(ScrW() / 2 - (600 * COEF_W) / 2, 200 * COEF_H)

			function f:Paint(w, h)
				paint_bg(w, h, 30, 30, 30, 255)
			end

			local header = f:Add("DPanel")
			header:Dock(TOP)
			header:SetTall(130 * COEF_H)
			header.Paint = function() end

			local icon = header:Add("DPanel")
			icon:SetWide(110 * COEF_W)
			icon:Dock(LEFT)
			icon:DockMargin(10 * COEF_W, 10 * COEF_W, 10 * COEF_W, 10 * COEF_W)

			local ICON_MAT = Material("vgui/ttt/icon_chaos_round.vtf")
			function icon:Paint(w, h)
				paint_bg(w, h, 255, 255, 255, 255, ICON_MAT)
			end

			surface.CreateFont("TTT2_ChaosRoundsFontMega", {
				extended = true,
				font = "Arial",
				size = 40 * COEF_H,
				weight = 2000
			})

			surface.CreateFont("TTT2_ChaosRoundsFontBig", {
				extended = true,
				font = "Tahoma",
				size = 40 * COEF_H,
				weight = 300
			})

			surface.CreateFont("TTT2_ChaosRoundsFontSmall", {
				extended = true,
				font = "Tahoma",
				size = 18 * COEF_H,
				weight = 800
			})

			local text_title = header:Add("DLabel")
			text_title:Dock(TOP)
			text_title:SetTall(50 * COEF_H)
			text_title:SetText("CHAOS ROUNDS")
			text_title:SetFont("TTT2_ChaosRoundsFontBig")

			local desc = "Chaos rounds are special rounds that apply a special condition or rule to the current round. Only one round may happen per map. Chaos rounds happen randomly, so be prepared!"
			local text = header:Add("DLabel")
			text:Dock(FILL)
			text:SetTall(50 * COEF_H)
			text:SetText(desc)
			text:SetFont("TTT2_ChaosRoundsFontSmall")
			text:SetWrap(true)

			local body = f:Add("DPanel")
			body:Dock(FILL)
			body:DockMargin(15 * COEF_W, 15 * COEF_W, 15 * COEF_W, 15 * COEF_W)
			local casino_time = false

			sound.PlayURL("https://github.com/Metastruct/garrysmod-chatsounds/raw/master/sound/chatsounds/autoadd/elevator_source/yaykids.ogg", "mono", function(station)
				if not IsValid(station) then return end
				station:SetPos(LocalPlayer():GetPos())
				station:SetVolume(SOUND_VOLUME:GetFloat())
				station:Play()

				timer.Simple(10, function()
					sound.PlayURL("https://github.com/Metastruct/garrysmod-chatsounds/raw/master/sound/chatsounds/autoadd/capsadmin/casino2.ogg", "mono", function(station2)
						if not IsValid(station2) then return end

						station2:SetPos(LocalPlayer():GetPos())
						station2:SetVolume(SOUND_VOLUME:GetFloat())
						station2:Play()
						casino_time = true

						timer.Simple(8, function()
							if not IsValid(station2) then return end

							station2:Stop()
						end)
					end)
				end)
			end)

			local words = table.GetKeys(ROUNDS)
			local friction = 0.01
			local next_word = 0
			function body:Paint(w, h)
				surface.SetFont("TTT2_ChaosRoundsFontMega")

				if casino_time then
					local active_round = ACTIVE_CHAOS_ROUND or { Name = "???" }

					if isfunction(active_round.DrawSelection) then
						active_round:DrawSelection(w, h)
						paint_bg(w, h, 0, 0, 0, 0) -- paints the outline on top of the custom thing
						return
					end

					-- Add pulsing background effect
					local pulse = math.sin(CurTime() * 4) * 20
					surface.SetDrawColor(20 + pulse, 0, 0, 255)
					surface.DrawRect(0, 0, w, h)

					-- Rainbow text with glow effect
					local rgb = HSVToColor((CurTime() * 300) % 360, 1, 1)
					local word = active_round.Name:upper()
					local tw, th = surface.GetTextSize(word)

					-- Draw glow
					for i = 1, 5 do
						surface.SetTextColor(rgb.r, rgb.g, rgb.b, 50 - i * 10)
						surface.SetTextPos(w / 2 - tw / 2 + i, h / 2 - th / 2)
						surface.DrawText(word)
						surface.SetTextPos(w / 2 - tw / 2 - i, h / 2 - th / 2)
						surface.DrawText(word)
					end

					-- Draw main text
					surface.SetTextColor(rgb.r, rgb.g, rgb.b, 255)
					surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
					surface.DrawText(word)

					-- Animated border
					local border_color = HSVToColor((CurTime() * 200) % 360, 1, 1)
					surface.SetDrawColor(border_color.r, border_color.g, border_color.b, 255)
					surface.DrawOutlinedRect(0, 0, w, h, 4)
				else
					paint_bg(w, h, 0, 0, 0, 255)
					surface.SetTextColor(255, 0, 0, 255)

					if next_word < SysTime() then
						last_word = words[math.random(#words)]:upper()
						next_word = SysTime() + friction
					end

					local tw, th = surface.GetTextSize(last_word)
					surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
					surface.DrawText(last_word)
				end

				friction = friction + 0.0002
			end
		end

		local called = false
		local function on_finish()
			if called then return end

			called = true

			if ACTIVE_CHAOS_ROUND then
				if _G.EPOP then
					_G.EPOP:AddMessage({
						text = ("[CHAOS ROUND] %s: %s"):format(ACTIVE_CHAOS_ROUND.Name:upper(), ACTIVE_CHAOS_ROUND.Description or "???"),
						color = COLOR_RED
					}, nil, 10)
				else
					chat.AddText(Color(255, 0, 0), "[CHAOS ROUND] ", ACTIVE_CHAOS_ROUND.Name:upper(), ": ", ACTIVE_CHAOS_ROUND.Description or "???")
				end

				if isfunction(ACTIVE_CHAOS_ROUND.OnPostSelection) then
					ACTIVE_CHAOS_ROUND:OnPostSelection()
				end
			end

			if not IsValid(f) then return end

			f:Remove()
		end

		-- in case the preparation is shorter than 25 seconds
		if IsValid(f) then
			hook.Add("TTTPrepareRound", f, on_finish)
		end

		timer.Simple(25, on_finish)
	end

	net.Receive(TAG, function()
		local key = net.ReadString()
		local state = net.ReadInt(32)

		if state == CHAOS_STATE_ROUND_START then
			if not ACTIVE_CHAOS_ROUND then return end

			if isfunction(ACTIVE_CHAOS_ROUND.Start) then
				ACTIVE_CHAOS_ROUND:Start()
			end
		elseif state == CHAOS_STATE_ROUND_FINISH then
			if not ACTIVE_CHAOS_ROUND then return end
			local round = ACTIVE_CHAOS_ROUND
			ACTIVE_CHAOS_ROUND = nil

			if isfunction(round.Finish) then
				round:Finish()
			end
		elseif state == CHAOS_STATE_SELECTED then
			ACTIVE_CHAOS_ROUND = ROUNDS[key]

			if not ACTIVE_CHAOS_ROUND then
				ErrorNoHalt("Chaos round \'" .. key"\' does not exist on client!")

				return
			end

			if isfunction(round.OnSelected) then
				round:OnSelected()
			end

			hook.Add("TTTPrepareRound", TAG, function()
				if isfunction(round.OnPrepare) then
					round:OnPrepare()
				end

				hook.Remove("TTTPrepareRound", TAG)
				show_selection()
			end)
		end
	end)

	show_selection()
end