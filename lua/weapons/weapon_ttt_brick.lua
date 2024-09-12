local className = "weapon_ttt_brick"

if SERVER then
	AddCSLuaFile()

	resource.AddFile("materials/vgui/ttt/icon_brick.vmt")
	resource.AddFile("models/weapons/tbrick01.mdl")
	resource.AddFile("materials/models/weapons/tbrick/tbrick01.vmt")
	resource.AddFile("materials/models/weapons/tbrick/tbrick01_evil.vmt")
	resource.AddSingleFile("materials/models/weapons/tbrick/tbrick01_normal.vtf")
	resource.AddSingleFile("materials/models/weapons/tbrick/tbrick01_warp_evil.vtf")
	resource.AddSingleFile("materials/tbrick/face.png")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/throw.mp3")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/evil_trigger.mp3")
else
	SWEP.PrintName = "Brick"
	SWEP.Author = "TW1STaL1CKY"
	SWEP.Slot = 3

	SWEP.ShowDefaultViewModel = false
	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 54

	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "A fairly heavy brick. Throw it, it'll be funny."
	}

	SWEP.Icon = "vgui/ttt/icon_brick"
	SWEP.IconLetter = "h"
end

DEFINE_BASECLASS("weapon_tttbasegrenade")

SWEP.ClassName = className

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_grenade.mdl"
SWEP.WorldModel = "models/weapons/tbrick01.mdl"

SWEP.Kind = WEAPON_NADE

SWEP.ThrowSound = ")weapons/tw1stal1cky/brick/throw.mp3"

SWEP.HeadshotMultiplier = 2
SWEP.detonate_timer = 0.8		-- Time it takes to get to full power - doesn't detonate, we're just keeping the base's naming
SWEP.throwForceMin = 2.6		-- Base throw force (at zero power)
SWEP.throwForceMax = 3.2		-- Max throw force (at full power)
SWEP.throwForce = SWEP.throwForceMin

function SWEP:SetupDataTables()
	BaseClass.SetupDataTables(self)

	self:NetworkVar("Bool", "InFlight")
end

function SWEP:Initialize()
	BaseClass.Initialize(self)

	if SERVER then
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(25)
		end

		if math.random() <= 0.001 then
			self:SetSkin(1)
		end
	else
		self:AddTTT2HUDHelp("Throw (Hold to power)", "Cancel throw")
	end
end

function SWEP:PullPin()
	if self:GetPin() then return end

	if not IsValid(self:GetOwner()) then return end

	self:SendWeaponAnim(ACT_VM_PULLBACK_HIGH)

	if self.SetHoldType then
		self:SetHoldType(self.HoldReady)
	end

	self:SetPin(true)
	self:SetPullTime(CurTime())

	self:SetDetTime(CurTime() + self.detonate_timer)
end

function SWEP:CancelThrow()
	self:SetPin(false)
	self:SetPullTime(0)
	self:SetDetTime(0)

	self:SendWeaponAnim(ACT_VM_IDLE)

	if self.SetHoldType then
		self:SetHoldType(self.HoldNormal)
	end

	self.throwForce = self.throwForceMin
end

function SWEP:Think()
	-- Skip calling weapon_tttbasegrenade's Think, only call weapon_tttbase's Think :)
	BaseClass.BaseClass.Think(self)

	local pl = self:GetOwner()

	if not IsValid(pl) then return end

	if self:GetPin() then
		local pullTime = self:GetPullTime()
		local powerScale = math.Clamp((CurTime() - pullTime) / (self:GetDetTime() - pullTime), 0, 1)

		self.throwForce = self.throwForceMin + (self.throwForceMax - self.throwForceMin) * powerScale

		if not pl:KeyDown(IN_ATTACK) then
			-- MOUSE1 released, throw now

			self:EmitSound(self.ThrowSound, 70, math.random(96, 112), 0.66)
			self:StartThrow()

			self:SetPin(false)
			self:SendWeaponAnim(ACT_VM_THROW)

			pl:DoAnimationEvent(ACT_HL2MP_GESTURE_RANGE_ATTACK_MELEE)
		elseif pl:KeyDown(IN_ATTACK2) then
			-- MOUSE2 pressed, cancel throw

			self:CancelThrow()

			self:SetNextPrimaryFire(CurTime() + 0.1)
		end
	elseif self:GetThrowTime() > 0 and self:GetThrowTime() < CurTime() then
		self:Throw()
	end
end

function SWEP:Throw()
	if CLIENT then
		self:SetThrowTime(0)
	elseif SERVER then
		if self.was_thrown then return end

		local pl = self:GetOwner()
		if not IsValid(pl) then return end

		self.was_thrown = true

		local src, force = self:GetThrowVelocity()

		local gren = self:CreateGrenade(
			src,
			Angle(0, 0, 0),
			force,
			Vector(600, math.random(-1200, 1200), 0),
			pl)

		gren.WeaponEnt = self

		self:SetInFlight(true)
		self:SetThrowTime(0)

		pl:DropWeapon(self, nil, vector_origin)

		self:SetParent(gren)
		self:SetLocalPos(vector_origin)
		self:SetTransmitWithParent(false)
		self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)

		self:DrawShadow(false)
	end
end

function SWEP:GetGrenadeName()
	return "ttt_brick_proj"
end

function SWEP:CreateGrenade(src, ang, vel, angimp, pl)
	local gren = ents.Create(self:GetGrenadeName())

	if not IsValid(gren) then return end

	gren:SetPos(src)
	gren:SetAngles(ang)
	gren:SetSkin(self:GetSkin())
	gren:SetOwner(pl)
	gren:SetThrower(pl)
	gren:SetElasticity(0.15)

	gren:Spawn()

	-- Transfer damage scaling values and stored fingerprints to the projectile entity
	gren.damageScaling = self.damageScaling
	gren.HeadshotMultiplier = self.HeadshotMultiplier
	gren.fingerprints = self.fingerprints

	local phys = gren:GetPhysicsObject()

	if IsValid(phys) then
		phys:Wake()
		phys:SetVelocity(vel)
		phys:AddAngleVelocity(angimp)
	end

	-- Clear the owner after a short delay so it can collide with them again
	timer.Simple(0.2, function()
		if IsValid(gren) then
			gren:SetOwner(NULL)
		end
	end)

	return gren
end

function SWEP:GetThrowVelocity()
	local pl = self:GetOwner()

	local ang = pl:EyeAngles()
	local src = pl:GetPos()
		+ (pl:Crouching() and pl:GetViewOffsetDucked() or pl:GetViewOffset())
		+ (ang:Forward() * 8)
		+ (ang:Right() * 10)

	local target = pl:GetEyeTraceNoCursor().HitPos

	-- A target angle to actually throw the grenade to the crosshair instead of forwards
	local tang = (target - src):Angle()

	-- Makes the grenade go upwards
	local upBoost = 3

	if tang.p < 90 then
		tang.p = -upBoost + tang.p * ((90 + upBoost) / 90)
	else
		tang.p = 360 - tang.p
		tang.p = -upBoost + tang.p * -((90 + upBoost) / 90)
	end

	-- Makes the grenade not go backwards :/
	tang.p = math.Clamp(tang.p, -90, 90)

	local vel = math.min(800, (90 - tang.p) * 6)
	local force = tang:Forward() * vel * self.throwForce

	return src, force
end

if SERVER then
	concommand.Add("ttt_brick_bstrd", function(pl)
		if not IsValid(pl) then return end

		local wep = pl:GetActiveWeapon()

		if IsValid(wep) and wep:GetClass() == className and wep:GetSkin() != 1 then
			wep:SetSkin(1)

			local rf = RecipientFilter()
			rf:AddPlayer(pl)

			pl:EmitSound("weapons/tw1stal1cky/brick/evil_trigger.mp3", 75, 100, 1, CHAN_AUTO, 0, 0, rf)

			wep:CallOnClient("BstrdFace")
		end
	end, nil, nil, FCVAR_UNREGISTERED)
else
	local draw = draw

	local hudTextColor = Color(255, 255, 255, 180)

	local bstrdFace = Material("tbrick/face.png", "noclamp")
	local bstrdColor = Color(255, 0, 102)
	local bstrdStart, bstrdEnd

	SWEP.ClientsideWorldModel = {
		Pos = Vector(3.2, -3.7, -2),
		Ang = Angle(0, -85, 100),
		Bone = "ValveBiped.Bip01_R_Hand"
	}

	SWEP.ClientsideViewModel = {
		Pos = Vector(3.1, -3.8, 0),
		Ang = Angle(0, -70, 100),
		Bone = "ValveBiped.Bip01_R_Hand"
	}

	function SWEP:DrawHUD()
		if self.HUDHelp then
			self:DrawHelp()
		end

		local x = ScrW() * 0.5
		local y = ScrH() * 0.5

		local pullTime = self:GetPullTime()

		if self:GetPin() and pullTime and pullTime > 0 then
			local client = LocalPlayer()

			y = y + (y / 3)

			local pct = math.Clamp((CurTime() - pullTime) / (self:GetDetTime() - pullTime), 0, 1)

			local scale = appearance.GetGlobalScale()
			local w, h = 100 * scale, 20 * scale
			local wHalf = w * 0.5

			local drawColor = appearance.SelectFocusColor(client:GetRoleColor())

			draw.AdvancedText(
				"POWER",
				"PureSkinBar",
				x - 0.5 * w,
				y - h,
				hudTextColor,
				TEXT_ALIGN_LEFT,
				TEXT_ALIGN_BOTTOM,
				true,
				scale
			)
			draw.Box(x - wHalf + scale, y - h + scale, w * pct, h, COLOR_BLACK)
			draw.OutlinedShadowedBox(x - wHalf, y - h, w, h, scale, drawColor)
			draw.Box(x - wHalf, y - h, w * pct, h, drawColor)
		else
			self:DoDrawCrosshair(x, y, true)
		end
	end

	function SWEP:Deploy()
		self.throwForce = self.throwForceMin

		bstrdStart, bstrdEnd = nil, nil

		return BaseClass.Deploy(self)
	end

	function SWEP:OnRemove()
		if IsValid(self.ClientsideWorldModel.Model) then
			self.ClientsideWorldModel.Model:Remove()
		end

		if IsValid(self.ClientsideViewModel.Model) then
			self.ClientsideViewModel.Model:Remove()
		end

		BaseClass.OnRemove(self)
	end

	function SWEP:PostDrawViewModel(vm, pl, wep)
		local modelData = self.ClientsideViewModel

		if not IsValid(modelData.Model) then
			modelData.Model = ClientsideModel(self:GetModel())

			modelData.Model:SetNoDraw(true)
			modelData.Model:SetupBones()
		end

		local boneId = vm:LookupBone(modelData.Bone)
		if not boneId then return end

		local matrix = vm:GetBoneMatrix(boneId)
		if not matrix then return end

		local pos, ang = LocalToWorld(modelData.Pos, modelData.Ang, matrix:GetTranslation(), matrix:GetAngles())

		modelData.Model:SetPos(pos)
		modelData.Model:SetAngles(ang)
		modelData.Model:SetSkin(self:GetSkin())

		modelData.Model:DrawModel()

		BaseClass.PostDrawViewModel(self, vm, pl, wep)
	end

	function SWEP:DrawWorldModel(flags)
		if not self:TryDrawWorldModel() then
			self:DrawModel(flags)
		end
	end

	function SWEP:TryDrawWorldModel()
		if self:GetInFlight() then return true end

		local owner = self:GetOwner()

		if not IsValid(owner) then return false end

		local pl = LocalPlayer()
		if not IsValid(pl) or (pl:GetObserverMode() == OBS_MODE_IN_EYE and pl:GetObserverTarget() == owner) then return false end

		local modelData = self.ClientsideWorldModel

		if not IsValid(modelData.Model) then
			modelData.Model = ClientsideModel(self:GetModel())

			modelData.Model:SetNoDraw(true)
			modelData.Model:SetupBones()
		end

		local boneId = owner:LookupBone(modelData.Bone)
		if not boneId then return false end

		local matrix = owner:GetBoneMatrix(boneId)
		if not matrix then return false end

		local pos, ang = LocalToWorld(modelData.Pos, modelData.Ang, matrix:GetTranslation(), matrix:GetAngles())

		modelData.Model:SetPos(pos)
		modelData.Model:SetAngles(ang)
		modelData.Model:SetSkin(self:GetSkin())

		modelData.Model:DrawModel()

		return true
	end

	function SWEP:DrawHUDBackground()
		if bstrdStart then
			local now = RealTime()

			if now >= bstrdEnd then
				bstrdStart, bstrdEnd = nil, nil
				return
			end

			local progress = math.Clamp((now - bstrdStart) / (bstrdEnd - bstrdStart), 0, 1)
			local sW, sH = ScrW(), ScrH()

			local size = (sH - 300) + (800 * progress)
			local x, y = (sW - size) * 0.5, (sH - size) * 0.5

			surface.SetAlphaMultiplier(1 - progress)

			surface.SetDrawColor(bstrdColor.r, bstrdColor.g, bstrdColor.b, 200)
			surface.DrawRect(0, 0, sW, sH)

			surface.SetMaterial(bstrdFace)
			surface.SetDrawColor(255, 255, 255)
			surface.DrawTexturedRect(x, y, size, size)

			surface.SetAlphaMultiplier(1)
		end
	end

	-- Bstrd = easter egg stuff shhh
	function SWEP:BstrdFace()
		local now = RealTime()

		bstrdStart, bstrdEnd = now, now + 2
	end
end