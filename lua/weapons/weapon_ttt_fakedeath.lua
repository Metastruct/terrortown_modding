-- Original code from workshop addon 1473581448 "[TTT2/TTT] Death Faker (fixed and improved)"
-- This has been overwritten to include various fixes that can't be easily patched using entity_tweaks.lua
-- To simplify the code, checks for whether we're playing TTT2 or some other TTT variant have been removed

if SERVER then
	AddCSLuaFile()

	resource.AddSingleFile("materials/vgui/ttt/icon_death_faker_vgui.png")

	util.AddNetworkString("TTTDFSYNC")
	util.AddNetworkString("TTTDFTrackNotification")
end

-- Merged its hooks.lua file into this file
do
	local explode = CreateConVar("ttt_df_explode_on_real_confirm", 0, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Should the fake body explodes, if the real players body is confirmed")
	local trackingTime = CreateConVar("ttt_df_tracking_time", 30, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "The time a player is tracked after searching a fake body")

	if CLIENT then
		local icon_tid_credits = Material("vgui/ttt/tid/tid_credits")

		local function GetFakedDeathGroup(ply)
			if ply:GetNWBool("FakedDeath", false) and ply:TTT2NETGetBool("body_found", false) then
				return GROUP_FOUND
			end
		end
		hook.Add("TTTScoreGroup", "TTTFakeDeathScoreGroup", GetFakedDeathGroup)

		-- add fake credits
		hook.Add("TTTRenderEntityInfo", "TTTFakeDeathFakeCredits", function(tData)
			local client = LocalPlayer()
			local ent = tData:GetEntity()

			-- has to be a ragdoll
			if not IsValid(ent) or not ent:IsRagdoll() then return end

			-- add credits info when corpse has credits
			if client:IsActive() and client:IsShopper() and ent:GetNWBool("FakeCredits") then
				tData:AddDescriptionLine(
					LANG.TryTranslation(bodysearch and bodysearch.GetInspectConfirmMode() == 0 and "target_credits_on_confirm" or "target_credits_on_search"),
					COLOR_GOLD,
					{icon_tid_credits}
				)
			end
		end)

		local trackOutlineColor = Color(255, 50, 50)
		hook.Add("PreDrawOutlines", "TTTFakeDeathTrackConfirmer", function()
			local client = LocalPlayer()

			if client.trackedDFPlayers != nil then
				for i = 1,table.Count(client.trackedDFPlayers) do
					local tracked = client.trackedDFPlayers[i]
					local startTime = client.trackedDFStarttimes[i]

					if IsValid(tracked) && !tracked:GetNoDraw() && startTime + trackingTime:GetFloat() > CurTime() then
						outline.Add(tracked, trackOutlineColor)
					end
				end
			end
		end)

		local function ModifySearch(processed, raw)
			local plys = player.GetAll()
			local ply

			for i = 1, #plys do
				if plys[i]:Name() == raw.nick then
					ply = plys[i]
				end
			end

			raw.owner = ply
		end
		hook.Add("TTTBodySearchPopulate", "TTTFakeDeathModifySearch", ModifySearch)
	else
		hook.Add("TTTCanIdentifyCorpse", "TTTFakeDeathGetTrueRoleColorBack", function(ply, corpse, was_traitor)
			local confirmed = CORPSE.GetPlayer(corpse)

			if not corpse.is_fake and IsValid(confirmed) then
				confirmed:SetNWBool("FakedDeath", false)

				local fakeBody = confirmed.fake_corpse

				if not explode:GetBool() or not IsValid(fakeBody) then return end

				confirmed:SetNWBool("FakedDeath", false)
				fakeBody:Ignite(5, 5) -- Replicate the burning of a body

				util.PaintDown(fakeBody:GetPos(), "Scorch", fakeBody) -- TTT specific function

				timer.Simple(5, function()
					for k, v in ipairs(player.GetAll()) do -- Tell our Traitor friends that someone's body exploded
						if v:GetRole() == ROLE_TRAITOR then
							CustomMsg(v, confirmed:Nick() .. "'s fake body has been detonated!", Color(200, 0, 0))
						end
					end

					local expl = ents.Create("env_explosion") -- Create a tiny explosion for effect
					expl:SetPos(fakeBody:GetPos()) -- Put it where our body currently is
					expl:SetOwner(confirmed) -- The body owner takes credit it anyone gets damaged...
					expl:Spawn()
					expl:SetKeyValue("iMagnitude", "10")
					expl:Fire("Explode", 0, 0) -- Kablam
					expl:EmitSound("siege/big_explosion.wav", 200, 200)

					fakeBody:Remove()

					confirmed.fake_corpse = nil
				end)
			end

			if corpse.is_fake and IsValid(ply) then
				local confirmed = player.GetBySteamID64(corpse.sid64)

				confirmed:TTT2NETSetBool("body_found", true)
				confirmed:TTT2NETSetBool("role_found", true)
				if confirmed:TTT2NETGetFloat("t_first_found", -1) < 0 then
					confirmed:TTT2NETSetFloat("t_first_found", CurTime())
				end
				confirmed:TTT2NETSetFloat("t_last_found", CurTime())

				local creator = corpse:GetNWEntity("FakeBodyCreator")
				if creator != ply then
					net.Start("TTTDFTrackNotification")
					net.WriteEntity(ply)
					net.Send(creator)
				end
			end
		end)
	end

	hook.Add("TTTPrepareRound", "TTTFakeDeathRemoveDeathFakers", function()
		for k, v in ipairs(player.GetAll()) do
			v:SetNWBool("FakedDeath", false)

			v.trackedDFPlayers = {}
			v.trackedDFStarttimes = {}

			v.df_class = nil
			v.df_bodyname = nil
			v.df_role = nil
		end
	end)
end

local DFROLES = {}

DFROLES.Roles = {
	{ROLE_TRAITOR, "Traitor", Color(250, 20, 20)},
	{ROLE_INNOCENT, "Innocent", Color(20, 250, 20)},
	{ROLE_DETECTIVE, "Detective", Color(20, 20, 250)}
}

if CLIENT then
	SWEP.PrintName = "Death Faker"
	SWEP.Slot = 6
	SWEP.EquipMenuData = {
		type = "item_weapon",
		name = "Death Faker",
		desc = [[
Left-Click: Spawns a dead body
Reload: Configure the body
Right-Click: Quickly change the role of the body
]]
	}
	SWEP.Icon = "vgui/ttt/icon_death_faker_vgui.png"
end

SWEP.HoldType = "slam"
SWEP.Base = "weapon_tttbase"

SWEP.Kind = WEAPON_NONE
SWEP.CanBuy = {ROLE_TRAITOR, ROLE_DETECTIVE}
SWEP.WeaponID = AMMO_BODYSPAWNER

SWEP.UseHands = true
SWEP.ViewModelFlip = false
SWEP.ViewModelFOV = 54
SWEP.ViewModel = Model("models/weapons/cstrike/c_c4.mdl")
SWEP.WorldModel = Model("models/weapons/w_c4.mdl")

SWEP.DrawCrosshair = false
SWEP.ViewModelFlip = false
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0.1

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 0.1

SWEP.NoSights = true

local identify = CreateConVar("ttt_df_identify_body", 0, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Should the fake body automatically get identified by a random player after being dropped")
local trackingTime = GetConVar("ttt_df_tracking_time")

local function firstToUpper(str)
	return str:gsub("^%l", string.upper)
end

local function GetSidekickTableForRole(role)
	if role != nil then
		local siki_deagle = GetEquipmentByName("weapon_ttt2_sidekickdeagle")
		if istable(siki_deagle) and istable(siki_deagle.CanBuy) and table.HasValue(siki_deagle.CanBuy, role.index) and isfunction(GetDarkenColor) then
			local siki_mod_table =  table.Copy(GetRoleByIndex(ROLE_SIDEKICK))
			siki_mod_table.color = GetDarkenColor(role.color)
			siki_mod_table.dkcolor = GetDarkenColor(role.dkcolor)
			siki_mod_table.bgcolor = GetDarkenColor(role.bgcolor)
			return siki_mod_table
		end
	end
end

if CLIENT then
	net.Receive("TTTDFSYNC", function()
		local size = net.ReadUInt(ROLE_BITS)

		DFROLES.Roles = {}

		for i = 1, size do
			local role = net.ReadUInt(ROLE_BITS)
			local v = GetRoleByIndex(role)
			local color = v.color
			if role == ROLE_SIDEKICK then
				color = net.ReadColor()
			end

			DFROLES.Roles[#DFROLES.Roles + 1] = {
				role,
				firstToUpper(v.name),
				color
			}
		end
	end)

	net.Receive("TTTDFTrackNotification", function()
		local tracked = net.ReadEntity()
		local startTime = CurTime()

		local ply = LocalPlayer()

		if ply.trackedDFPlayers == nil or ply.trackedDFStarttimes == nil then
			ply.trackedDFPlayers = {}
			ply.trackedDFStarttimes = {}
		end

		table.insert(ply.trackedDFPlayers, tracked)
		table.insert(ply.trackedDFStarttimes, startTime)

		local trackingTimeFloat = trackingTime:GetFloat()

		chat.AddText(
			Color(200, 20, 20),
			"[Death Faker] ",
			Color(250, 250, 250),
			"Your fake body was searched by ",
			tracked,
			". You will now track them for ",
			tostring(trackingTimeFloat),
			" seconds."
		)

		chat.PlaySound()
	end)

	hook.Add("TTTScoreboardRowColorForPlayer", "TTTFakeDeathColorFake", function(ply)
		if IsValid(ply) and ply:GetNWBool("FakedDeath") and ply:TTT2NETGetBool("body_found") then
			local role = ply:GetNWInt("FakeCorpseRole")
			local color = Color(0, 0, 0, 0)

			if role ~= ROLE_INNOCENT then
				local index = ply:GetNWInt("FakeCorpseIndex")
				color = DFROLES.Roles[index][3]
			end

			return color
		end
	end)

	hook.Add("TTT2ModifyMiniscoreboardColor", "TTTFakeDeathFColorFake", function(ply, col)
		if IsValid(ply) and ply:GetNWBool("FakedDeath") and ply:TTT2NETGetBool("body_found") then
			local role = ply:GetNWInt("FakeCorpseRole")

			local index = ply:GetNWInt("FakeCorpseIndex")
			local color = DFROLES.Roles[index][3]

			color = Color(color.r, color.g, color.b, col.a)

			return color
		end
	end)
else
	hook.Add("TTTBeginRound", "TTTFakeDeathInit", function()
		DFROLES.Roles = {{
			TRAITOR.index,
			firstToUpper(TRAITOR.name),
			TRAITOR.color
		}}

		local t_siki = GetSidekickTableForRole(TRAITOR)
		if t_siki then
			DFROLES.Roles[#DFROLES.Roles + 1] = {
				t_siki.index,
				firstToUpper(t_siki.name),
				t_siki.color
			}
		end

		local roles = roles.GetList()

		for i = 1, #roles do
			local v = roles[i]

			if v:IsSelectable() and v.index != TRAITOR.index then
				DFROLES.Roles[#DFROLES.Roles + 1] = {
					v.index,
					firstToUpper(v.name),
					v.color
				}

				local siki = GetSidekickTableForRole(v)
				if siki then
					DFROLES.Roles[#DFROLES.Roles + 1] = {
						siki.index,
						firstToUpper(siki.name),
						siki.color
					}
				end
			end
		end

		net.Start("TTTDFSYNC")
		net.WriteUInt(#DFROLES.Roles, ROLE_BITS)

		for i = 1, #DFROLES.Roles do
			local roleIndex = DFROLES.Roles[i][1]
			net.WriteUInt(roleIndex, ROLE_BITS)
			if roleIndex == ROLE_SIDEKICK then
				net.WriteColor(DFROLES.Roles[i][3])
			end
		end

		net.Broadcast()
	end)

	local function SelectHeadshot(ply, cmd, args)
		if #args ~= 1 then return end

		if args[1] == "0" then
			ply.df_headshot = false
		else
			ply.df_headshot = true
		end
	end
	concommand.Add("ttt_df_headshot", SelectHeadshot)

	local function SelectFakeCredits(ply, cmd, args)
		if #args ~= 1 then return end

		if args[1] == "0" then
			ply.df_fakecredits = false
		else
			ply.df_fakecredits = true
		end
	end
	concommand.Add("ttt_df_fakecredits", SelectFakeCredits)

	local function SelectWeapon(ply, cmd, args)
		if #args ~= 1 then return end

		ply.df_weapon = args[1]
	end
	concommand.Add("ttt_df_select_weapon", SelectWeapon)

	local function SelectRole(ply, cmd, args)
		if #args ~= 1 then return end

		ply.df_role = math.floor(args[1])
	end
	concommand.Add("ttt_df_select_role", SelectRole)

	local function SelectClass(ply, cmd, args)
		if #args ~= 1 then return end

		ply.df_class = args[1]
	end
	concommand.Add("ttt_df_select_class", SelectClass)

	local function SelectPlayer(ply, cmd, args)
		if #args ~= 1 then return end

		ply.df_bodyname = args[1]
	end
	concommand.Add("ttt_df_select_player", SelectPlayer)
end

function SWEP:Initialize()
	self.CurrentRole = DFROLES.Roles[1]
	self.ReloadingTime = CurTime()

	if CLIENT then
		self:AddTTT2HUDHelp("Spawn a corpse", "Quickly change the role of the corpse")
		self:AddHUDHelpLine("Customize the corpse (name, role, cause of death)", Key("+reload", "R"))
	end
end

function SWEP:PrimaryAttack()
	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	if not ply.df_role then
		ply.df_role = self.CurrentRole[1]
	end

	if SERVER then
		self:BodyDrop()
		self:Remove()
	end
end

function SWEP:SecondaryAttack()
	if not IsFirstTimePredicted() then return end

	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	local key = 0
	local currentRole = self.CurrentRole[1]
	if ply.df_role then
		currentRole = ply.df_role
	end

	for k, v in ipairs(DFROLES.Roles) do
		if v[1] == currentRole then
			key = k

			break
		end
	end

	key = key + 1

	if key > #DFROLES.Roles then
		key = 1
	end

	self.CurrentRole = DFROLES.Roles[key]
	ply.df_role = self.CurrentRole[1]

	if CLIENT then
		chat.AddText(
			Color(200, 20, 20),
			"[Death Faker] ",
			Color(250, 250, 250),
			"Your body's role will be ",
			self.CurrentRole[3],
			self.CurrentRole[2]
		)

		chat.PlaySound()
	end
end

function SWEP:Reload()
	if not IsFirstTimePredicted() or SERVER or CurTime() <= self.ReloadingTime then return end

	if not self.GUI or not self.GUI:IsValid() then
		self:CreateGUI()
	else
		self.GUI:Close()
	end

	self.ReloadingTime = CurTime() + 0.2
end

if SERVER then
	function SWEP:BodyDrop()
		local ply = self:GetOwner()
		if not IsValid(ply) then return end

		local dmg = DamageInfo()

		local dead

		if ply.df_bodyname then
			dead = player.GetByUniqueID(ply.df_bodyname)
		end

		if not dead then
			dead = ply
		end

		-- Use a blank string when a damage type has been specified, otherwise this will change to the weapon of choice
		local dmgwep = ""

		if ply.df_weapon == "-1" then
			dmg:SetDamageType(DMG_FALL)
		elseif ply.df_weapon == "-2" then
			dmg:SetDamageType(DMG_BLAST)
		elseif ply.df_weapon == "-3" then
			dmg:SetDamageType(DMG_CRUSH)
		elseif ply.df_weapon == "-4" then
			dmg:SetDamageType(DMG_BURN)
		elseif ply.df_weapon == "-5" then
			dmg:SetDamageType(DMG_DROWN)
		else
			dmg:SetDamageType(DMG_BULLET)

			dmgwep = ply.df_weapon or "weapon_ttt_m16"
		end

		local wepTab = dmgwep != "" and weapons.Get(dmgwep) or nil
		local wepDamage = wepTab
			and wepTab.Primary
			and isnumber(wepTab.Primary.Damage)
			and wepTab.Primary.Damage
			or math.random(10, 25)

		if ply.df_headshot then
			wepDamage = wepDamage * (wepTab and wepTab.HeadshotMultiplier or 2.7)
		end

		dmg:SetAttacker(ply)
		dmg:SetDamage(wepDamage)

		dead:SetNWBool("FakedDeath", true)

		-- This is a silly hack to make the ragdoll appear where the user is
		local storedPos = dead:GetPos()
		dead:SetPos(ply:GetPos())

		local rag = CORPSE.Create(dead, ply, dmg)
		CORPSE.SetCredits(rag, 0)

		dead:SetPos(storedPos)

		rag.sid = dead:SteamID()
		rag.sid64 = dead:SteamID64()
		rag.uqid = dead:UniqueID()

		rag.is_fake = true
		rag:SetNWBool("IsFakeBody", true)
		rag:SetNWEntity("FakeBodyCreator", ply)

		-- Tie the body to the player
		dead.fake_corpse = rag

		rag.dmgwep = dmgwep
		rag.was_headshot = ply.df_headshot or false

		rag:SetNWBool("FakeCredits", ply.df_fakecredits or false)

		rag.was_role = ply.df_role or 1

		rag.kills = {}
		rag.killer_sample = nil

		dead:SetNWInt("FakeCorpseRole", rag.was_role)
		local key = 0
		for k, v in ipairs(DFROLES.Roles) do
			if v[1] == ply.df_role then
				key = k

				break
			end
		end
		dead:SetNWInt("FakeCorpseIndex", key)
		rag.role_color = DFROLES.Roles[key][3]

		if not ply.df_headshot then
			-- The deathsound handling is all localised within base TTT2, so this is the simplest way we can replicate it
			sound.Play(string.format("player/death%s.wav", math.random(1, 6)), ply:GetShootPos(), 90, 100)
		end

		-- If convar is enabled, automatically identify the body after dropping it
		--TODO?: This needs updating if we're actually going to be using this convar, it all sucks lol  (bad finder, found message is wrong)
		if identify:GetBool() then
			CORPSE.SetFound(rag, true)

			dead:TTT2NETSetBool("body_found", true)
			dead:SetNWBool("body_found", true)

			-- We are going to use a random player to identify this fake body.
			local finder = table.Random(player.GetAll())
			if finder == dead or finder:IsSpec() or not finder:Alive() then
				finder = table.Random(player.GetAll())
			end

			for _, v in ipairs(player.GetAll()) do -- Tell the other player's that this body has been 'found'
				CustomMsg(v, finder:Nick() .. " found the body of " .. dead:Nick() .. ". He was a Traitor!", color_white)
			end
		end

		for i = 1, 10 do
			local jitter = VectorRand() * 60
			jitter.z = 20

			util.PaintDown(rag:GetPos() + jitter, "Blood", rag)
		end

		return rag
	end
else
	function SWEP:CreateGUI()
		local ply = LocalPlayer()

		local w, h = 300, 195

		local y = 30

		local Panel = vgui.Create("DFrame")
		--Panel:SetPaintBackground(false)
		Panel:SetSize(w, h)
		Panel:Center()
		Panel:MakePopup()
		Panel:IsActive()
		Panel:SetTitle("Death Faker Config")
		Panel:SetVisible(true)
		Panel:ShowCloseButton(true)
		Panel:SetMouseInputEnabled(true)
		Panel:SetDeleteOnClose(true)
		Panel:SetKeyboardInputEnabled(false)

		local FakeCreditsCB = vgui.Create("DCheckBoxLabel", Panel)
		FakeCreditsCB:SetText("Fake Credits")
		FakeCreditsCB:SetPos(10, y)
		FakeCreditsCB:SetSize(150, 20)
		FakeCreditsCB:SetChecked(ply.df_fakecredits)
		FakeCreditsCB.OnChange = function()
			if FakeCreditsCB:GetChecked() then
				RunConsoleCommand("ttt_df_fakecredits", "1")
				ply.df_fakecredits = true
			else
				RunConsoleCommand("ttt_df_fakecredits", "0")
				ply.df_fakecredits = false
			end
		end

		y = y + 20

		local HeadshotCB = vgui.Create("DCheckBoxLabel", Panel)
		HeadshotCB:SetText("Headshot (and silent)")
		HeadshotCB:SetPos(10, y)
		HeadshotCB:SetSize(150, 20)
		HeadshotCB:SetChecked(ply.df_headshot)
		HeadshotCB.OnChange = function()
			if HeadshotCB:GetChecked() then
				RunConsoleCommand("ttt_df_headshot", "1")
				ply.df_headshot = true
				ply.bloodmode = true
			else
				RunConsoleCommand("ttt_df_headshot", "0")
				ply.df_headshot = false
				ply.bloodmode = false
			end
		end

		y = y + 30

		local DLabel = vgui.Create("DLabel", Panel)
		DLabel:SetPos(10, y)
		DLabel:SetSize(100, 20)
		DLabel:SetText("Body Name:")

		local NameComboBox = vgui.Create("DComboBox", Panel)
		NameComboBox:SetPos(150, y)
		NameComboBox:SetSize(140, 20)

		local plys = player.GetAll()
		local value = ply:Name()

		if ply.df_bodyname then
			local newply = player.GetByUniqueID(ply.df_bodyname)

			value = IsValid(newply) and newply:Name() or value
		end

		NameComboBox:SetValue(value)
		for i = 1, #plys do
			NameComboBox:AddChoice(plys[i]:Name(), plys[i]:UniqueID())
		end

		NameComboBox.OnSelect = function(panel, index, _, data)
			RunConsoleCommand("ttt_df_select_player", data)

			ply.df_bodyname = data
		end

		y = y + 25

		local DLabel2 = vgui.Create("DLabel", Panel)
		DLabel2:SetPos(10, y)
		DLabel2:SetSize(100, 20)
		DLabel2:SetText("Body Role:")

		local RoleComboBox = vgui.Create("DComboBox", Panel)
		RoleComboBox:SetPos(150, y)
		RoleComboBox:SetSize(140, 20)

		local data = 1

		if ply.df_role then
			data = ply.df_role
		end

		for _, v in ipairs(DFROLES.Roles) do
			RoleComboBox:AddChoice(v[2], v[1], data == v[1])
		end

		RoleComboBox.OnSelect = function(panel, index, _, dat)
			RunConsoleCommand("ttt_df_select_role", dat)

			ply.df_role = dat
		end

		y = y + 25

		local DLabel3 = vgui.Create("DLabel", Panel)
		DLabel3:SetPos(10, y)
		DLabel3:SetSize(100, 20)
		DLabel3:SetText("Used Weapon:")

		local WeaponCB = vgui.Create("DComboBox", Panel)
		WeaponCB:SetPos(150, y)
		WeaponCB:SetSize(140, 20)

		local weps = weapons.GetList()

		if not ply.df_weapon then
			ply.df_weapon = "weapon_ttt_m16"
		end

		for i = 1, #weps do
			local wep = weps[i]

			if wep.Base == "weapon_tttbase" and wep.Primary.Ammo ~= "none" then
				WeaponCB:AddChoice(LANG.TryTranslation(wep.PrintName), wep.ClassName, wep.ClassName == ply.df_weapon)
			end
		end

		WeaponCB:AddChoice("Fall Damage", "-1", ply.df_weapon == "-1")
		WeaponCB:AddChoice("Explosion Damage", "-2", ply.df_weapon == "-2")
		WeaponCB:AddChoice("Object Damage", "-3", ply.df_weapon == "-3")
		WeaponCB:AddChoice("Fire Damage", "-4", ply.df_weapon == "-4")
		WeaponCB:AddChoice("Water Damage", "-5", ply.df_weapon == "-5")

		WeaponCB.OnSelect = function(panel, index, _, dat)
			RunConsoleCommand("ttt_df_select_weapon", dat)

			ply.df_weapon = dat
		end

		self.GUI = Panel
	end
end