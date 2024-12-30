-- The weapon_squirtbottle SWEP ported over to TTT with some cleanup

local className = "weapon_ttt_squirtbottle"
local hookTag = "TTTSprayBottle"

local CurTime = CurTime
local math = math
local random = math.random

if SERVER then
	AddCSLuaFile()
	resource.AddFile("materials/vgui/ttt/icon_squirtbottle.vmt")
	resource.AddFile("materials/models/weapons/tw1stal1cky/physics_trash.vmt")
	resource.AddFile("models/weapons/tw1stal1cky/c_squirtbottle.mdl")
	resource.AddFile("models/weapons/tw1stal1cky/w_squirtbottle.mdl")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/squirtbottle_use.wav")

	util.AddNetworkString(hookTag)
else
	SWEP.PrintName = "Spray Bottle"
	SWEP.Author = "TW1STaL1CKY"
	SWEP.Slot = 8

	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 75
	SWEP.DrawCrosshair = false

	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "A spray bottle filled with... something.\n\nTerrorists don't like being sprayed."
	}

	SWEP.Icon = "vgui/ttt/icon_squirtbottle"
	SWEP.IconLetter = "c"
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.ClassName = className
SWEP.HoldType = "pistol"

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/tw1stal1cky/c_squirtbottle.mdl"
SWEP.WorldModel = "models/weapons/tw1stal1cky/w_squirtbottle.mdl"
SWEP.idleResetFix = true

SWEP.Primary.Range = 86
SWEP.Primary.Delay = 0.25
SWEP.Primary.Automatic = false
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Ammo = "none"
SWEP.Primary.Sound = "weapons/tw1stal1cky/squirtbottle_use.wav"

SWEP.Secondary.Delay = 0.1
SWEP.Secondary.Automatic = false
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Ammo = "none"

SWEP.Kind = WEAPON_EXTRA
SWEP.CanBuy = {ROLE_DETECTIVE}
SWEP.LimitedBuy = false

SWEP.DeploySpeed = 2
SWEP.NoSights = true

SWEP.StunDuration = 1.2
SWEP.StunDurationMin = 0.15
SWEP.StunDurationStepAmount = 0.075

function SWEP:SetupDataTables()
	self:NetworkVar("Float", "LastSpray")
end

function SWEP:PrimaryAttack()
	local now = CurTime()

	self:SetNextPrimaryFire(now + self.Primary.Delay)

	local owner = self:GetOwner()

	if not IsValid(owner) then return end

	owner:SetAnimation(PLAYER_ATTACK1)
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

	local wLvl = owner:WaterLevel()

	if wLvl == 3 or (wLvl == 2 and owner:EyeAngles().p > 0) then
		self:EmitSound("player/footsteps/wade6.wav", 60, random(170, 185), 0.5)
		return
	end

	self:EmitSound(self.Primary.Sound, 68, random(97, 103))

	self:SetLastSpray(now)

	if SERVER then
		self:HandleSpray()
	end
end

function SWEP:SecondaryAttack() end

function SWEP:Reload() end

hook.Add("StartCommand", hookTag, function(pl, cm)
	if pl._SprayedEffectEnd and pl._SprayedEffectEnd > CurTime() and pl:Alive() then
		cm:RemoveKey(IN_ATTACK)
		cm:RemoveKey(IN_ATTACK2)
		cm:RemoveKey(IN_SPEED)
		cm:AddKey(IN_WALK)
	end
end)

if SERVER then
	local empty = ""
	local fireClassName = "env_fire"

	local blacklistedEntsInSphere = {
		["player"] = true,
		predicted_viewmodel = true,
		gmod_hands = true
	}

	local hullSize = Vector(4, 4, 4)

	function SWEP:HandleSpray()
		local now = CurTime()
		local owner = self:GetOwner()

		owner:LagCompensation(true)

		local pos = owner:GetShootPos()

		local tr = util.TraceHull({
			start = pos,
			endpos = pos + (owner:GetAimVector() * self.Primary.Range),
			mins = -hullSize,
			maxs = hullSize,
			filter = owner,
			mask = MASK_SHOT_HULL
		})

		owner:LagCompensation(false)

		local ent = tr.Entity

		if IsValid(ent) then
			self:SprayEntity(ent)

			if ent:IsPlayer() then
				ent._SprayedEffectEnd = now + self.StunDuration - math.min(self.StunDurationStepAmount * math.max(ent._SprayedTimes - 1, 0), self.StunDuration - self.StunDurationMin)

				ent:SetEyeAngles(ent:EyeAngles() + Angle(random(-10, 10), random(-15, 15), 0))
				ent:ViewPunch(Angle(1, 0, random() < 0.5 and 5 or -5))

				ent:AnimRestartGesture(GESTURE_SLOT_FLINCH, ACT_FLINCH_HEAD, true)

				net.Start(hookTag)
				net.WritePlayer(ent)
				net.WriteFloat(ent._SprayedEffectEnd)
				net.Broadcast()
			end
		end

		local closeEnts = ents.FindInSphere(tr.HitPos, 24)
		local closeEnt

		for i = 1, #closeEnts do
			closeEnt = closeEnts[i]

			if closeEnt == ent
			or blacklistedEntsInSphere[closeEnt:GetClass()]
			or (closeEnt:IsWeapon() and IsValid(closeEnt:GetOwner())) then continue end

			if (closeEnt:GetClass() != fireClassName and closeEnt:GetModel() == empty) then continue end

			self:SprayEntity(closeEnt)
		end
	end

	function SWEP:SprayEntity(ent)
		ent._SprayedTimes = ((ent._SprayedTimesExpiry or 0) >= CurTime() and ent._SprayedTimes or 0) + 1
		ent._SprayedTimesExpiry = CurTime() + 3

		local ext = false

		if ent:GetClass() == fireClassName then
			ent._SprayedTimesNeeded = ent._SprayedTimesNeeded or random(3, 5)

			if ent._SprayedTimes >= ent._SprayedTimesNeeded then
				ent:Fire("Extinguish")
				ext = true
			end
		else
			local onFire = ent:IsOnFire()

			if onFire then
				ent._SprayedTimes = onFire == ent._SprayedOnFireLast and ent._SprayedTimes or 1
				ent._SprayedTimesNeeded = ent._SprayedTimesNeeded or (ent:IsPlayer() and random(6, 12) or math.ceil(ent:GetModelRadius() / 12) + random(0, 2))
				print(ent._SprayedTimes, ent._SprayedTimesNeeded)

				if ent._SprayedTimes >= ent._SprayedTimesNeeded then
					ent:Extinguish()
					ext = true
				end
			else
				ext = nil
			end

			if ext then
				ent._SprayedOnFireLast = nil
				ent._SprayedTimesNeeded = nil
			else
				ent._SprayedOnFireLast = onFire or nil
			end
		end

		if ext != nil then
			ext = ext == true

			ent:EmitSound(")ambient/levels/canals/toxic_slime_sizzle3.wav",
				ext and 70 or 65,
				ext and random(90, 95) or random(140, 170),
				ext and 1 or 0.75,
				CHAN_VOICE2)
		end
	end
else
	local ParticleEmitter = ParticleEmitter

	local handBoneName = "ValveBiped.Bip01_R_Hand"

	local particleMat = Material("particle/warp1_warp")

	local pl

	hook.Add("RenderScreenspaceEffects", hookTag, function()
		if not pl then
			pl = LocalPlayer()
		end

		if pl._SprayedEffectEnd and pl._SprayedEffectEnd > CurTime() and pl:Alive() then
			DrawMaterialOverlay("effects/water_warp01", math.min((pl._SprayedEffectEnd - CurTime()) * 0.18, 0.16))
		end
	end)

	net.Receive(hookTag, function()
		if not pl then
			pl = LocalPlayer()
		end

		local victim = net.ReadPlayer()

		if IsValid(victim) then
			if victim == pl then
				pl._SprayedEffectEnd = endTime
			end

			victim:AnimRestartGesture(GESTURE_SLOT_FLINCH, ACT_FLINCH_HEAD, true)
		end
	end)

	function SWEP:DrawSpray(boneP, boneA, vel, lengthen)
		local pe = ParticleEmitter(boneP, false)

		pe:SetPos(boneP)

		local boneAF, boneAR, boneAU = boneA:Forward(), boneA:Right(), boneA:Up()

		for i = 1, 8 do
			local p = pe:Add(particleMat, boneP)

			p:SetDieTime(0.65)
			p:SetColor(240, 245, 255)
			p:SetStartAlpha(128)
			p:SetEndAlpha(0)
			p:SetStartSize(0.5)
			p:SetEndSize(lengthen and 2 or 4)
			p:SetStartLength(lengthen and 12 or 0)
			p:SetEndLength(lengthen and 10 or 0)
			p:SetVelocity(((boneAF + (boneAR * (0.5 - random())) + (boneAU * (0.5 - random()))) * random(100, 150)) + vel)
			p:SetGravity(vector_up * -5)
			p:SetAirResistance(256)
			p:SetBounce(0)
			p:SetCollide(true)
		end

		pe:Finish()
	end

	function SWEP:DrawWorldModel()
		pl = pl or LocalPlayer()

		local owner = self:GetOwner()

		if IsValid(pl) and pl:GetObserverMode() == OBS_MODE_IN_EYE and pl:GetObserverTarget() == owner then return end

		self:DrawModel()

		if not IsValid(owner) then return end

		if self:GetLastSpray() + 0.1 >= CurTime() then
			local bone = owner:LookupBone(handBoneName)
			if not bone then return end

			local matrix = owner:GetBoneMatrix(bone)
			local boneP, boneA = matrix:GetTranslation(), matrix:GetAngles()

			boneP:Add(boneA:Forward() * 6.8)
			boneP:Add(boneA:Right() * -1.25)
			boneP:Add(boneA:Up() * -4)

			self:DrawSpray(boneP, boneA, owner:GetVelocity() * 0.8, true)
		end
	end

	function SWEP:PostDrawViewModel(vm, _, pl)
		if self:GetLastSpray() + 0.125 >= CurTime() then
			local p, a = pl:GetShootPos(), pl:EyeAngles()

			p:Add(a:Forward() * 12)
			p:Add(a:Right() * 6)
			p:Add(a:Up() * -3)

			self:DrawSpray(p, a, pl:GetVelocity() * 0.8)
		end
	end
end