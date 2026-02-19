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
SWEP.Primary.Delay = 0.4
SWEP.Primary.Recoil = 0
SWEP.Primary.Cone = 0
SWEP.Primary.Automatic = true
SWEP.Primary.ClipSize = 4
SWEP.Primary.ClipMax = -1
SWEP.Primary.DefaultClip = 4
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

function SWEP:PrimaryAttack(worldsnd)
	if self:GetPendingReload() then return end

	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self:SetNextSecondaryFire(CurTime() + self.Primary.Delay)

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
		self:SetReloadStart(self:GetNextPrimaryFire())
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
		self:EmitSound(self.Primary.Sound2, self.Primary.SoundLevel, math.random(95, 100), 0.15, CHAN_VOICE2)
	elseif SERVER then
		sound.Play(self.Primary.Sound1, self:GetPos(), self.Primary.SoundLevel, math.random(120, 130))
		sound.Play(self.Primary.Sound2, self:GetPos(), self.Primary.SoundLevel, math.random(95, 100), 0.15)
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
			owner:GetViewModel():SetPlaybackRate(0.95)

			self:SetReloadEnd(now + 2.25)
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
	local femaleMdls = {
		["models/player/alyx.mdl"] = true,
		["models/player/mossman.mdl"] = true,
		["models/player/mossman_arctic.mdl"] = true,
		["models/player/p2_chell.mdl"] = true
	}
	local function IsModelFemale(mdl)
		return femaleMdls[mdl] or mdl:find("female") != nil
	end

	local moanSounds = {
		male = {
			"vo/npc/male01/moan01.wav",
			"vo/npc/male01/moan02.wav",
			"vo/npc/male01/moan03.wav",
			"vo/npc/barney/ba_pain03.wav"
		},
		female = {
			"vo/npc/female01/pain03.wav",
			"vo/npc/female01/pain07.wav",
			"vo/outland_12a/launch/al_launch_breath06.wav",
			"vo/outland_12a/launch/al_launch_breath14.wav",
			"vo/outland_12a/launch/al_launch_struggle06.wav",
			"vo/outland_12a/launch/al_launch_struggle09.wav"
		}
	}
	local function PlayMoan(ent, isFem)
		local tbl = isFem and moanSounds.female or moanSounds.male

		ent:EmitSound(tbl[math.random(1, #tbl)], 70, 100, 0.333)
	end

	function SWEP:TryTazeVictim(ent)
		if not IsValid(ent) then return end

		local pl
		local rag

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

			phys:AddAngleVelocity(VectorRand(-750, 750))
		end

		if not IsValid(pl) then return end

		local isFem = IsModelFemale(rag:GetModel())

		PlayMoan(rag, isFem)

		local entIndexStr = tostring(rag:EntIndex())
		local timerTasingId = "RagdollTasing" .. entIndexStr
		local timerTaseMoanId = "RagdollTaseMoan" .. entIndexStr
		local timerTaseEndId = "RagdollTaseEnd" .. entIndexStr
		local timerStart = CurTime()

		-- Spasm movements (500 reps are a fallback in case it somehow gets left running)
		timer.Create(timerTasingId, 0.1, 500, function()
			if not IsValid(rag) or not IsValid(pl) or not pl:IsTerror() then
				timer.Remove(timerTasingId)
				timer.Remove(timerTaseMoanId)
				timer.Remove(timerTaseEndId)
				return
			end

			for i = 0, rag:GetPhysicsObjectCount() - 1 do
				local phys = rag:GetPhysicsObjectNum(i)
				local force = CurTime() >= (timerStart + 5) and 80 or 260

				phys:AddAngleVelocity(VectorRand(-force, force))
			end
		end)

		-- Displeasure sounds
		timer.Create(timerTaseMoanId, 3, 10, function()
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

		-- End timer
		timer.Create(timerTaseEndId, 12, 1, function()
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
		if not self:TryDrawWorldModel() then
			self:SetRenderOrigin()
			self:SetRenderAngles()
		end

		self:DrawModel(flags)
	end

	function SWEP:TryDrawWorldModel()
		local owner = self:GetOwner()
		if not IsValid(owner) then return false end

		local pl = LocalPlayer()
		if not IsValid(pl) or (pl:GetObserverMode() == OBS_MODE_IN_EYE and pl:GetObserverTarget() == owner) then return false end

		local modelData = self.ClientsideWorldModel

		local boneId = owner:LookupBone(modelData.Bone)
		if not boneId then return false end

		local matrix = owner:GetBoneMatrix(boneId)
		if not matrix then return false end

		local pos, ang = LocalToWorld(modelData.Pos, modelData.Ang, matrix:GetTranslation(), matrix:GetAngles())

		self:SetRenderOrigin(pos)
		self:SetRenderAngles(ang)

		return true
	end
end