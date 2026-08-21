if SERVER then
	AddCSLuaFile()

	resource.AddFile("models/weapons/csgo/w_eq_taser.mdl")
	resource.AddFile("materials/models/weapons/csgo/w_eq_taser/taser.vmt")

	resource.AddSingleFile("materials/vgui/ttt/icon_taser.png")
else
	SWEP.PrintName = "Taser"
	SWEP.Slot = 6

	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 60

	SWEP.Icon = "vgui/ttt/icon_taser.png"
	SWEP.IconLetter = "w"

	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "A taser capable of stunning someone for some time."
	}
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.HoldType = "revolver"

SWEP.Primary.Ammo = ""
SWEP.Primary.Delay = 0.275
SWEP.Primary.Recoil = 0
SWEP.Primary.Cone = 0
SWEP.Primary.Automatic = true
SWEP.Primary.ClipSize = 5
SWEP.Primary.ClipMax = -1
SWEP.Primary.DefaultClip = 5
SWEP.Primary.Sound1 = "^npc/turret_floor/shoot2.wav"
SWEP.Primary.Sound2 = "weapons/stunstick/stunstick_impact2.wav"
SWEP.Primary.Range = 360

SWEP.HeadshotMultiplier = 1

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/cstrike/c_pist_deagle.mdl"
SWEP.WorldModel = "models/weapons/csgo/w_eq_taser.mdl"
SWEP.idleResetFix = true
SWEP.ShowDefaultViewModel = false

SWEP.IronSightsPos = Vector(-6.273, -8.5, 2.57)

SWEP.Kind = WEAPON_EQUIP1
SWEP.CanBuy = { ROLE_DETECTIVE }
SWEP.LimitedStock = true

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", "PendingReload")
	self:NetworkVar("Float", "ReloadStart")
	self:NetworkVar("Float", "ReloadEnd")
end

function SWEP:Initialize()
	BaseClass.Initialize(self)

	-- Edit the holdtype gesture anims this way to not have to redefine it all using TranslateActivity
	self.ActivityTranslate[ACT_MP_ATTACK_STAND_PRIMARYFIRE] = ACT_HL2MP_GESTURE_RANGE_ATTACK_PISTOL
	self.ActivityTranslate[ACT_MP_ATTACK_CROUCH_PRIMARYFIRE] = ACT_HL2MP_GESTURE_RANGE_ATTACK_PISTOL
	self.ActivityTranslate[ACT_MP_RELOAD_STAND] = ACT_HL2MP_GESTURE_RELOAD_AR2
	self.ActivityTranslate[ACT_MP_RELOAD_CROUCH] = ACT_HL2MP_GESTURE_RELOAD_AR2
end

function SWEP:PrimaryAttack(worldsnd)
	if self:GetPendingReload() then return end

	local nextActionTime = CurTime() + self.Primary.Delay

	self:SetNextPrimaryFire(nextActionTime)
	self:SetNextSecondaryFire(nextActionTime)

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	if self:Clip1() <= 0 then
		self:DryFire(self.SetNextPrimaryFire)
		return
	end

	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	owner:SetAnimation(PLAYER_ATTACK1)

	self:TakePrimaryAmmo(1)

	if self:Clip1() > 0 then
		self:SetPendingReload(true)
		self:SetReloadStart(nextActionTime)
	end

	owner:LagCompensation(true)

	local eyePos = owner:GetShootPos()
	local tr = util.TraceLine({
		start = eyePos,
		endpos = eyePos + (owner:GetAimVector() * self.Primary.Range),
		filter = owner,
		mask = MASK_SHOT
	})

	owner:LagCompensation(false)

	local ef = EffectData()
	ef:SetOrigin(tr.HitPos)
	ef:SetStart(eyePos)
	ef:SetAttachment(1)
	ef:SetEntity(self)
	util.Effect("ToolTracer", ef)

	if not worldsnd then
		self:EmitSound(self.Primary.Sound1, self.Primary.SoundLevel, math.random(120, 130))
		self:EmitSound(self.Primary.Sound2, self.Primary.SoundLevel, math.random(95, 110), 0.175, CHAN_VOICE2)
	elseif SERVER then
		sound.Play(self.Primary.Sound1, self:GetPos(), self.Primary.SoundLevel, math.random(120, 130))
		sound.Play(self.Primary.Sound2, self:GetPos(), self.Primary.SoundLevel, math.random(95, 110), 0.175)
	end

	if CLIENT then return end

	self:TryTazeVictim(tr.Entity)
end

function SWEP:Deploy()
	self:SetReloadEnd(0)

	return BaseClass.Deploy(self)
end

function SWEP:Think()
	local owner = self:GetOwner()

	local now = CurTime()
	local reloadEnd = self:GetReloadEnd()

	if reloadEnd > 0 then
		if reloadEnd <= now then
			self:SetPendingReload(false)
			self:SetReloadStart(0)
			self:SetReloadEnd(0)
		end
	else
		local reloadStart = self:GetReloadStart()

		if reloadStart > 0 and reloadStart <= now then
			owner:SetAnimation(PLAYER_RELOAD)

			self:SendWeaponAnim(ACT_VM_RELOAD)
			owner:GetViewModel():SetPlaybackRate(1.15)

			self:SetReloadEnd(now + 1.9)
		end
	end

	BaseClass.Think(self)
end

local eventsToDisable = {
	[20] = true,
	[5001] = true
}
local soundsToReplace = CLIENT and {
	["Weapon_DEagle.Slideback"] = true,
	["Weapon_DEagle.Clipout"] = "weapons/ump45/ump45_clipout.wav",
	["Weapon_DEagle.Clipin"] = "weapons/ump45/ump45_clipin.wav",
} or nil

function SWEP:FireAnimationEvent(pos, ang, eventId, param)
	if eventsToDisable[eventId] then return true end

	if CLIENT and eventId == 5004 then
		local replace = soundsToReplace[param]

		if isstring(replace) then
			self:EmitSound(replace, 75, 100, 0.6, CHAN_ITEM)
			return true
		elseif replace then
			return true
		end
	end
end

if SERVER then
	local taseTimerAlive, taseTimerDead = 12, 2

	local femaleMdls = {
		["models/player/alyx.mdl"] = true,
		["models/player/mossman.mdl"] = true,
		["models/player/mossman_arctic.mdl"] = true,
		["models/player/p2_chell.mdl"] = true,
		["models/pac/female_base.mdl"] = true
	}
	local function IsModelFemale(mdl)
		return femaleMdls[mdl] or mdl:find("female") != nil
	end

	local moanSounds = {
		male = {
			"vo/npc/male01/pain02.wav",
			"vo/npc/male01/pain05.wav",
			"vo/npc/male01/pain06.wav",
			"vo/npc/male01/ow01.wav",
			"vo/episode_1/npc/male01/cit_pain02.wav",
			"vo/episode_1/npc/male01/cit_pain09.wav"
		},
		female = {
			"vo/npc/female01/pain02.wav",
			"vo/npc/female01/pain05.wav",
			"vo/npc/female01/pain07.wav",
			"vo/npc/female01/pain08.wav",
			"vo/npc/female01/ow01.wav",
			"vo/episode_1/npc/female01/cit_pain02.wav"
		}
	}
	local function PlayMoan(ent, isFem)
		local tbl = isFem and moanSounds.female or moanSounds.male

		ent:EmitSound(tbl[math.random(1, #tbl)], 66, math.random(99, 102), 0.8)
	end

	local function ZapStep(rag, force, useZapEffect)
		for i = 0, rag:GetPhysicsObjectCount() - 1 do
			local phys = rag:GetPhysicsObjectNum(i)

			phys:AddAngleVelocity(VectorRand(-force, force))
		end

		if useZapEffect then
			local ef = EffectData()

			ef:SetEntity(rag)
			ef:SetMagnitude(1)

			util.Effect("TeslaHitboxes", ef)
		end
	end

	function SWEP:TryTazeVictim(ent)
		if not IsValid(ent) then return end

		local pl, rag

		if ent:IsPlayer() then
			pl = ent
			rag = TTTRagdolling.Start(pl)
		elseif ent:IsRagdoll() then
			rag = ent
			pl = TTTRagdolling.GetRagdollOwner(rag)
		else
			return
		end

		if not IsValid(rag) then return end

		rag:EmitSound("ambient/energy/newspark08.wav", 75, math.random(105, 115))

		for i = 0, rag:GetPhysicsObjectCount() - 1 do
			local phys = rag:GetPhysicsObjectNum(i)

			phys:AddAngleVelocity(VectorRand(-1000, 1000))
		end

		local isFem

		local plValid = IsValid(pl)
		if plValid then
			isFem = IsModelFemale(rag:GetModel())

			PlayMoan(rag, isFem)
		end

		local entIndexStr = tostring(rag:EntIndex())
		local timerTasingId = "RagdollTasing" .. entIndexStr
		local timerTaseMoanId = "RagdollTaseMoan" .. entIndexStr
		local timerTaseEndId = "RagdollTaseEnd" .. entIndexStr
		local timerStart = CurTime()

		plValid = plValid and pl:IsTerror()

		local timerSeconds = plValid and taseTimerAlive or taseTimerDead

		-- Spasm movements (High reps are a fallback in case it somehow gets left running)
		timer.Create(timerTasingId, 0.06, 1000, function()
			if not IsValid(rag) then
				timer.Remove(timerTasingId)
				timer.Remove(timerTaseMoanId)
				timer.Remove(timerTaseEndId)
				return
			elseif not IsValid(pl) or not pl:IsTerror() then
				timer.Remove(timerTaseMoanId)

				ZapStep(rag, 150, true)
				return
			end

			local initialShockPassed = CurTime() >= (timerStart + 8)
			local force = initialShockPassed and 150 or 500

			ZapStep(rag, force, not initialShockPassed)
		end)

		-- Displeasure sounds if alive
		if plValid then
			timer.Create(timerTaseMoanId, 2, 30, function()
				if not IsValid(rag) or not IsValid(pl) or not pl:IsTerror() then
					timer.Remove(timerTasingId)
					timer.Remove(timerTaseMoanId)
					timer.Remove(timerTaseEndId)
					return
				end

				if math.random() > 0.25 then
					PlayMoan(rag, isFem)
				end
			end)
		end

		-- End timer
		timer.Create(timerTaseEndId, timerSeconds, 1, function()
			timer.Remove(timerTasingId)
			timer.Remove(timerTaseMoanId)

			if IsValid(rag) and IsValid(pl) then
				TTTRagdolling.Stop(pl, not pl:IsTerror())
			end
		end)
	end
else
	SWEP.ClientsideWorldModel = {
		Pos = Vector(0, -0.4, 0.5),
		Ang = Angle(175, 180, 0),
		Bone = "ValveBiped.Bip01_R_Hand"
	}

	function SWEP:InitializeCustomModels()
		self:AddCustomViewModel("vmodel", {
			type = "Model",
			model = self:GetModel(),
			bone = "v_weapon.deagle_Parent",
			rel = "",
			pos = Vector(0.4, -0.15, 4.75),
			angle = Angle(-90, 90, 0),
			size = Vector(1, 1, 1),
			color = color_white,
			surpresslightning = false,
			material = "",
			skin = 0,
			bodygroup = {},
		})
	end

	function SWEP:DrawWorldModel(flags)
		self:SetRenderOrigin()
		self:SetRenderAngles()

		if self:TryPrepareWorldModel() then
			self:DrawModel(flags)
		end
	end

	-- Return false to not render, return true to render
	function SWEP:TryPrepareWorldModel()
		local owner = self:GetOwner()
		if not IsValid(owner) then return true end

		local pl = LocalPlayer()
		if not IsValid(pl) or (pl:GetObserverMode() == OBS_MODE_IN_EYE and pl:GetObserverTarget() == owner) then return true end

		local modelData = self.ClientsideWorldModel

		local boneId = owner:LookupBone(modelData.Bone)
		if not boneId then return true end

		local matrix = owner:GetBoneMatrix(boneId)
		if not matrix then return true end

		local pos, ang = LocalToWorld(modelData.Pos, modelData.Ang, matrix:GetTranslation(), matrix:GetAngles())

		self:SetRenderOrigin(pos)
		self:SetRenderAngles(ang)

		return true
	end
end