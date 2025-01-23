local className = "weapon_ttt_shusher"
local hookName = "TTTShusherGun"
local shushedVarName = "TTTShusherGunShushed"
local shushedDurationVarName = "TTTShusherGunDuration"

local convarDurationName = "ttt_shusher_duration"
local convarDurationHeadshotName = "ttt_shusher_duration_headshot"

local statusId = "ttt_shushed_status"
local markerVisionId = "shushed_alert_team"
local markerVisionSelfId = "shushed_alert_self"

if SERVER then
	AddCSLuaFile()

	resource.AddFile("materials/vgui/ttt/icon_shusher.png")
	resource.AddSingleFile("materials/vgui/ttt/perks/hud_shushed.png")

	-- Hooks to restrict chatting while shushed
	hook.Add("PlayerCanHearPlayersVoice", hookName, function(_, talker)
		if talker[shushedVarName] then return false end
	end)

	hook.Add("PlayerSay", hookName, function(pl, text)
		if pl[shushedVarName] then
			local filter = RecipientFilter()
			filter:AddPlayer(pl)

			pl:EmitSound("player/suit_denydevice.wav", 75, 100, 0.5, CHAN_AUTO, 0, 0, filter)

			LANG.Msg(pl, "ttt_shushed_warning", nil, MSG_MSTACK_WARN)

			return ""
		end
	end)

	hook.Add("TTTPlayerRadioCommand", hookName, function(pl)
		if pl[shushedVarName] then return true end
	end)

	-- Support for Metastruct: don't let shushed players use chatsounds
	hook.Add("ChatsoundsShouldNetwork", hookName, function(pl)
		if pl[shushedVarName] then return false end
	end)

	-- Support for Metastruct: don't let shushed players emit hurt sounds
	hook.Add("ShouldPlayerEmitHurtSound", hookName, function(pl)
		if pl[shushedVarName] then return false end
	end)

	local function removeSushedEffect(pl)
		if pl[shushedVarName] then
			pl[shushedVarName] = nil
			pl:SetNWBool(shushedVarName, false)
			pl:SetNWFloat(shushedDurationVarName, 0)

			STATUS:RemoveStatus(pl, statusId)

			pl:RemoveMarkerVision(markerVisionId)
			pl:RemoveMarkerVision(markerVisionSelfId)

			timer.Remove(shushedVarName .. tostring(pl:EntIndex()))
		end
	end

	-- Remove Shushed effect when respawned or killed
	hook.Add("PlayerSpawn", hookName, removeSushedEffect)
	hook.Add("PostPlayerDeath", hookName, removeSushedEffect)

	-- Remove Shushed effect when the round ends
	hook.Add("TTTEndRound", hookName, function()
		for k, v in ipairs(player.GetAll()) do
			removeSushedEffect(v)
		end
	end)
else
	local TryT = LANG.TryTranslation
	local materialSushed = Material("vgui/ttt/perks/hud_shushed.png")

	SWEP.PrintName = "Shusher"
	SWEP.Slot = 6

    SWEP.ViewModelFlip = false
    SWEP.ViewModelFOV = 54

	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "A gun that stops the victim from talking for a while. Headshots make the effect last longer."
	}

	SWEP.Icon = "vgui/ttt/icon_shusher.png"

	LANG.AddToLanguage("en", "ttt_shushed_warning", "You've been shushed! You can't speak right now!")

	STATUS:RegisterStatus(statusId, {
		hud = { materialSushed },
		type = "bad",
		name = "Shushed",
		sidebarDescription = "You can't speak! No-one can hear you!",
	})

	-- If we have been shushed, don't show our name in the voice chat HUD and tell us what's up
	local lastMsgTime = 0
	hook.Add("PlayerStartVoice", hookName, function(pl)
		if IsValid(pl) and pl == LocalPlayer() and pl:GetNWBool(shushedVarName) then
			EmitSound("player/suit_denydevice.wav", vector_origin, -2, CHAN_AUTO, 0.5, 0, 0, 100)

			if RealTime() > lastMsgTime + 3 then
				lastMsgTime = RealTime()

				LANG.Msg("ttt_shushed_warning", nil, MSG_MSTACK_WARN)
			end

			-- Try to hide the voice chat HUD for the local player
			VOICE.SetSpeaking(false)
			return true
		end
	end)

	-- Support for Metastruct: don't show shushed players' overhead chat
	hook.Add("ShouldShowRTChat", hookName, function(pl)
		if pl:GetNWBool(shushedVarName) then return false end
	end)

	hook.Add("TTT2RenderMarkerVisionInfo", "HUDDrawMarkerVisionShushed", function(mvData)
        local ent = mvData:GetEntity()
        local mvObject = mvData:GetMarkerVisionObject()

        if not mvObject:IsObjectFor(ent, markerVisionId) and not mvObject:IsObjectFor(ent, markerVisionSelfId) then return end

		-- Remove the wallhacks glow that Marker Vision applies, we don't want that for this
		if not mvObject.RemovedGlow then
			marks.Remove({ent})

			mvObject.RemovedGlow = true
		end

		-- Don't render for self
		if ent == LocalPlayer() then return end

        local nick = IsValid(ent) and ent:Nick() or "---"

        local time = math.ceil(ent:GetNWFloat(shushedDurationVarName) - CurTime())
		if time <= 0 then return end

        mvData:EnableText()

        mvData:SetTitle("Shushed")
        mvData:AddDescriptionLine(string.format("%s cannot speak for %s second%s.", nick, time, time != 1 and "s" or ""))
        mvData:AddDescriptionLine(TryT(mvObject:GetVisibleForTranslationKey()), COLOR_SLATEGRAY)

        mvData:AddIcon(
            materialSushed,
            (mvData:IsOffScreen() or not mvData:IsOnScreenCenter()) and COLOR_WHITE
        )

        mvData:SetCollapsedLine(time)
    end)
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.ClassName = className

SWEP.HoldType = "revolver"

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/cstrike/c_pist_usp.mdl"
SWEP.WorldModel = "models/weapons/w_pist_elite_single.mdl"
SWEP.idleResetFix = true

SWEP.Primary.Damage = 2
SWEP.Primary.Recoil = 0.6
SWEP.Primary.Cone = 0.0175
SWEP.Primary.Delay = 0.4
SWEP.Primary.Automatic = true
SWEP.Primary.ClipSize = 4
SWEP.Primary.DefaultClip = 4
SWEP.Primary.Ammo = "none"
SWEP.Primary.Sound = "weapons/tmp/tmp-1.wav"
SWEP.Primary.SoundLevel = 60

SWEP.HeadshotMultiplier = 2

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = {ROLE_TRAITOR}
SWEP.LimitedStock = true

SWEP.DeploySpeed = 1.75
SWEP.NoSights = true

local convarDuration = CreateConVar(convarDurationName, 10, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED})
local convarDurationHeadshot = CreateConVar(convarDurationHeadshotName, 20, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED})

function SWEP:Initialize()
    self:SetColor(Color(150, 255, 240))

    return BaseClass.Initialize(self)
end

local function shushBulletCallback(attacker, tr, dmg)
	local returnTbl = { effects = false }

	if SERVER then
		if (gameloop and gameloop.GetRoundState() or GetRoundState()) == ROUND_POST then return end

		local ent = tr.Entity

		if IsValid(ent) and ent:IsPlayer() then
			local duration = tr.HitGroup == HITGROUP_HEAD and convarDurationHeadshot:GetInt() or convarDuration:GetInt()

			-- If the shot we're making is about to shorten the Shushed effect rather than extend it, don't continue
			if CurTime() + duration <= ent:GetNWFloat(shushedDurationVarName) then
				return returnTbl
			end

			ent[shushedVarName] = true
			ent:SetNWBool(shushedVarName, true)
			ent:SetNWFloat(shushedDurationVarName, CurTime() + duration)

			STATUS:AddTimedStatus(ent, statusId, duration, true)

			local mvObject = ent:AddMarkerVision(markerVisionId)
			mvObject:SetOwner(TEAM_TRAITOR)
			mvObject:SetVisibleFor(VISIBLE_FOR_TEAM)
			mvObject:SyncToClients()

			-- If the attacker was not a traitor, let them see the marker specifically
			if attacker:IsPlayer() and attacker:GetTeam() != TEAM_TRAITOR then
				local mvObject = ent:AddMarkerVision(markerVisionSelfId)
				mvObject:SetOwner(attacker)
				mvObject:SetVisibleFor(VISIBLE_FOR_PLAYER)
				mvObject:SyncToClients()
			end

			timer.Create(shushedVarName .. tostring(ent:EntIndex()), duration, 1, function()
				if IsValid(ent) then
					ent[shushedVarName] = nil
					ent:SetNWBool(shushedVarName, false)
					ent:SetNWFloat(shushedDurationVarName, 0)

					ent:RemoveMarkerVision(markerVisionId)
					ent:RemoveMarkerVision(markerVisionSelfId)

					-- The status should already remove itself since it's timed
				end
			end)
		end
	end

	return returnTbl
end

function SWEP:PrimaryAttack(worldsnd)
    self:SetNextSecondaryFire(CurTime() + self.Primary.Delay)
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    if not self:CanPrimaryAttack() then
        return
    end

    if not worldsnd then
        self:EmitSound(self.Primary.Sound, self.Primary.SoundLevel, 140)
    elseif SERVER then
        sound.Play(self.Primary.Sound, self:GetPos(), self.Primary.SoundLevel, 140)
    end

    self:ShootBullet(
        self.Primary.Damage,
        self:GetPrimaryRecoil(),
        1,
        self:GetPrimaryCone()
    )

    self:TakePrimaryAmmo(1)

    local owner = self:GetOwner()

    if not IsValid(owner) or owner:IsNPC() or not owner.ViewPunch then return end

    owner:ViewPunch(
        Angle(
            util.SharedRandom(self:GetClass(), -0.2, -0.1, 0) * self:GetPrimaryRecoil(),
            util.SharedRandom(self:GetClass(), -0.1, 0.1, 1) * self:GetPrimaryRecoil(),
            0
        )
    )
end

function SWEP:ShootBullet(dmg, recoil, numbul, cone)
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	self:SendWeaponAnim(self.PrimaryAnim)

    owner:MuzzleFlash()
    owner:SetAnimation(PLAYER_ATTACK1)

	numbul = numbul or 1
    cone = cone or 0.02

    local bullet = {}
    bullet.Num = numbul
    bullet.Src = owner:GetShootPos()
    bullet.Dir = owner:GetAimVector()
    bullet.Spread = Vector(cone, cone, 0)
    bullet.Tracer = 1
    bullet.TracerName = self.Tracer or "Tracer"
    bullet.Force = 1
    bullet.Damage = dmg * (self.damageScaling or 1)

    bullet.Callback = shushBulletCallback

    owner:FireBullets(bullet)

    -- Owner can die after firebullets
    if not IsValid(owner) or owner:IsNPC() or not owner:Alive() then return end

    if
        SERVER and game.SinglePlayer()
        or CLIENT and not game.SinglePlayer() and IsFirstTimePredicted()
    then
        local eyeang = owner:EyeAngles()
        eyeang.pitch = eyeang.pitch - recoil

        owner:SetEyeAngles(eyeang)
    end
end

function SWEP:SecondaryAttack() end

function SWEP:Reload() end

if CLIENT then
	function SWEP:AddToSettingsMenu(parent)
		local form = vgui.CreateTTT2Form(parent, "header_equipment_additional")

		form:MakeSlider({
			serverConvar = convarDurationName,
			label = "Effect duration",
			min = 1,
			max = 120,
			decimal = 0
		})

		form:MakeSlider({
			serverConvar = convarDurationHeadshotName,
			label = "Effect duration when headshot",
			min = 1,
			max = 120,
			decimal = 0
		})
	end
end