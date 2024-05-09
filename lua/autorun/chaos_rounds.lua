local TAG = "TTT_ChaosRounds"
local BASE_CHANCE_MULT = 3
local ROUNDS = {}
local files, _ = file.Find("chaos_rounds/*.lua", "LUA")
for _, f in pairs(files) do
	local path = "chaos_rounds/" .. f
	local r = include(path)
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
	util.AddNetworkString(TAG)

	local BONUS_CHANCE_MULT = 0
	local ACTIVE_CHAOS_ROUND
	local CHAOS_ROUND_DONE = false -- once per map

	local function network_state(round_key, state)
		net.Start(TAG)
		net.WriteString(round_key)
		net.WriteUInt(state, 32)
		net.Broadcast()
	end

	local function select_chaos_round()
		if CHAOS_ROUND_DONE then return end
		if math.random(0, 100) > BASE_CHANCE_MULT + BONUS_CHANCE_MULT then return end

		local keys = table.GetKeys(ROUNDS)
		local rand_key = keys[math.random(#keys)]
		if not ROUNDS[rand_key] then return end

		ACTIVE_CHAOS_ROUND = ROUNDS[rand_key]

		network_state(ACTIVE_CHAOS_ROUND.Name, CHAOS_STATE_SELECTED)
	end

	local function begin_chaos_round()
		if not ACTIVE_CHAOS_ROUND then return end

		if not isfunction(ACTIVE_CHAOS_ROUND.Start) then
			ErrorNoHalt("Chaos round \'" .. ACTIVE_CHAOS_ROUND.Name "\' had no Start function!")
			return
		end

		network_state(ACTIVE_CHAOS_ROUND.Name, CHAOS_STATE_ROUND_START)
		ACTIVE_CHAOS_ROUND:Start()
	end

	local function end_chaos_round()
		if not ACTIVE_CHAOS_ROUND then return end

		local round = ACTIVE_CHAOS_ROUND

		CHAOS_ROUND_DONE = true
		ACTIVE_CHAOS_ROUND = nil
		BONUS_CHANCE_MULT = 0

		if not isfunction(round.Finish) then
			ErrorNoHalt("Chaos round \'" .. round.Name "\' had no Finish function!")
			return
		end

		network_state(round.Name, CHAOS_STATE_ROUND_FINISH)
		round:Finish()
	end

	hook.Add("TTTEndRound", TAG, function()
		end_chaos_round()

		-- add 10% every round, but cap it to 75% overall
		BONUS_CHANCE_MULT = math.min(72, BONUS_CHANCE_MULT + 10)

		timer.Simple(0, select_chaos_round)
	end)

	hook.Add("TTTBeginRound", TAG, begin_chaos_round)
end

if CLIENT then
	local ACTIVE_CHAOS_ROUND

	local function show_selection()
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

		local f = vgui.Create("DPanel")
		f:SetSize(600, 350)
		f:SetPos(ScrW() / 2 - 300, 200)

		function f:Paint(w, h)
			paint_bg(w, h, 36, 36, 36, 255)
		end

		local header = f:Add("DPanel")
		header:Dock(TOP)
		header:SetTall(130)
		header.Paint = function() end

		local icon = header:Add("DPanel")
		icon:SetWide(110)
		icon:Dock(LEFT)
		icon:DockMargin(10, 10, 10, 10)
		local ICON_MAT = Material("data/chaos_round_icon.png")
		function icon:Paint(w, h)
			paint_bg(w, h, 255, 255, 255, 255, ICON_MAT)
		end

		surface.CreateFont("TTT2_ChaosRoundsFontMega", {
			extended = true,
			font = "Tahoma",
			size = 60,
			weight = 300
		})

		surface.CreateFont("TTT2_ChaosRoundsFontBig", {
			extended = true,
			font = "Tahoma",
			size = 40,
			weight = 300
		})

		surface.CreateFont("TTT2_ChaosRoundsFontSmall", {
			extended = true,
			font = "Tahoma",
			size = 18,
			weight = 800
		})

		local text_title = header:Add("DLabel")
		text_title:Dock(TOP)
		text_title:SetTall(50)
		text_title:SetText("CHAOS ROUNDS")
		text_title:SetFont("TTT2_ChaosRoundsFontBig")

		local desc = "Chaos rounds are special rounds that apply a special condition or rule to the current round. Only one round may happen per map. Chaos rounds happen randomly, so be prepared!"
		local text = header:Add("DLabel")
		text:Dock(FILL)
		text:SetTall(50)
		text:SetText(desc)
		text:SetFont("TTT2_ChaosRoundsFontSmall")
		text:SetWrap(true)

		local body = f:Add("DPanel")
		body:Dock(FILL)
		body:DockMargin(15, 15, 15, 15)

		local casino_time = false
		sound.PlayURL("https://github.com/Metastruct/garrysmod-chatsounds/raw/master/sound/chatsounds/autoadd/elevator_source/yaykids.ogg", "mono", function(station)
			if not IsValid(station) then return end

			station:SetPos(LocalPlayer():GetPos())
			station:SetVolume(0.5)
			station:Play()

			timer.Simple(10, function()
				sound.PlayURL("https://github.com/Metastruct/garrysmod-chatsounds/raw/master/sound/chatsounds/autoadd/capsadmin/casino2.ogg", "mono", function(station2)
					if not IsValid(station2) then return end

					station2:SetPos(LocalPlayer():GetPos())
					station2:SetVolume(0.5)
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
		local last_word = words[math.random(#words)]
		function body:Paint(w, h)
			paint_bg(w, h, 0, 0, 0, 255)

			surface.SetFont("TTT2_ChaosRoundsFontMega")

			if casino_time then
				local rgb = HSVToColor((CurTime() * 300) % 360, 1, 1)
				surface.SetTextColor(rgb.r, rgb.g, rgb.b, 255)

				local word = ACTIVE_CHAOS_ROUND.Name
				local tw, th = surface.GetTextSize(word)

				surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
				surface.DrawText(word)
			else
				surface.SetTextColor(255, 0, 0, 255)

				if next_word < SysTime() then
					last_word = words[math.random(#words)]
					next_word = SysTime() + friction
				end

				local tw, th = surface.GetTextSize(last_word)

				surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
				surface.DrawText(last_word)
			end


			friction = friction + 0.0002
		end

		timer.Simple(30, function()
			if ACTIVE_CHAOS_ROUND then
				chat.AddText(Color(255, 0, 0), "[CHAOS ROUND] ", ACTIVE_CHAOS_ROUND.Name:upper(), ": ", ACTIVE_CHAOS_ROUND.Description or "No description provided.")
			end

			if not IsValid(f) then return end

			f:Remove()
		end)
	end

	net.Receive(TAG, function()
		local key = net.ReadString()
		local state = net.ReadInt(32)

		if state == CHAOS_STATE_ROUND_START then
			if not ACTIVE_CHAOS_ROUND then return end

			if not isfunction(ACTIVE_CHAOS_ROUND.Start) then
				ErrorNoHalt("Chaos round \'" .. ACTIVE_CHAOS_ROUND.Name "\' had no Start function!")
				return
			end

			ACTIVE_CHAOS_ROUND:Start()
		elseif state == CHAOS_STATE_ROUND_FINISH then
			if not ACTIVE_CHAOS_ROUND then return end

			local round = ACTIVE_CHAOS_ROUND
			ACTIVE_CHAOS_ROUND = nil

			if not isfunction(round.Finish) then
				ErrorNoHalt("Chaos round \'" .. round.Name "\' had no Finish function!")
				return
			end

			round:Finish()
		elseif state == CHAOS_STATE_SELECTED then
			ACTIVE_CHAOS_ROUND = ROUNDS[key]
			if not ACTIVE_CHAOS_ROUND then
				ErrorNoHalt("Chaos round \'" .. key "\' does not exist on client!")
				return
			end

			show_selection()
		end
	end)
end