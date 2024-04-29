local className = "weapon_ttt_brick"

if SERVER then
	AddCSLuaFile()

	resource.AddFile("materials/vgui/ttt/icon_brick.vmt")
	resource.AddFile("models/weapons/tbrick01.mdl")
	resource.AddFile("materials/models/weapons/tbrick/tbrick01.vmt")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/throw.mp3")
else
	SWEP.PrintName = "Brick"
	SWEP.Slot = 3

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

SWEP.detonate_timer = 3			-- Time it takes to get to full power - doesn't detonate, we're just keeping the base's naming
SWEP.throwForceMin = 0.75		-- Base throw force (at zero power)
SWEP.throwForceMax = 4			-- Max throw force (at full power)
SWEP.throwForce = SWEP.throwForceMin

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

function SWEP:Think()
	-- Skip calling weapon_tttbasegrenade's Think, only call weapon_tttbase's Think :)
    BaseClass.BaseClass.Think(self)

    local pl = self:GetOwner()

    if not IsValid(pl) then return end

    if self:GetPin() then
		local pullTime = self:GetPullTime()
		local powerScale = math.Clamp((CurTime() - pullTime) / (self:GetDetTime() - pullTime), 0, 1)

		self.throwForce = self.throwForceMin + (self.throwForceMax - self.throwForceMin) * powerScale

        -- Throw now
        if not pl:KeyDown(IN_ATTACK) then
			self:EmitSound(self.ThrowSound, 70, math.random(92, 101), 0.66)
            self:StartThrow()

            self:SetPin(false)
            self:SendWeaponAnim(ACT_VM_THROW)

            if SERVER then
                pl:SetAnimation(PLAYER_ATTACK1)
            end
        end
    elseif self:GetThrowTime() > 0 and self:GetThrowTime() < CurTime() then
        self:Throw()
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
    gren:SetOwner(pl)
    gren:SetThrower(pl)
    gren:SetElasticity(0.15)

	gren.damageScaling = self.damageScaling

    gren:Spawn()
    gren:PhysWake()

    local phys = gren:GetPhysicsObject()

    if IsValid(phys) then
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
    local force = tang:Forward() * vel * self.throwForce + pl:GetVelocity()

    return src, force
end

if SERVER then
	function SWEP:Initialize()
		BaseClass.Initialize(self)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(25)
		end
	end
else
    local draw = draw
    local hudTextColor = Color(255, 255, 255, 180)

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

        if self:GetPin() and self:GetPullTime() > 0 then
            local client = LocalPlayer()

            y = y + (y / 3)

			local pullTime = self:GetPullTime()

            local pct = math.Clamp((CurTime() - pullTime) / (self:GetDetTime() - pullTime), 0, 1)

            local scale = appearance.GetGlobalScale()
            local w, h = 100 * scale, 20 * scale
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
            draw.Box(x - w / 2 + scale, y - h + scale, w * pct, h, COLOR_BLACK)
            draw.OutlinedShadowedBox(x - w / 2, y - h, w, h, scale, drawColor)
            draw.Box(x - w / 2, y - h, w * pct, h, drawColor)
        else
            self:DoDrawCrosshair(x, y, true)
        end
    end

	function SWEP:ToggleViewModelVisibility(vm, state)
		if not IsValid(vm) then return end

		vm:SetMaterial(state and "debug/occlusionproxy" or nil)

		vm._brickHack = state
	end

	function SWEP:Deploy()
		local owner = self:GetOwner()

		if IsValid(owner) then
			self.CurrentOwner = owner

			self:ToggleViewModelVisibility(owner:GetViewModel(), true)
		end

		return BaseClass.Deploy(self)
	end

	function SWEP:Holster()
		local owner = self:GetOwner()

		if IsValid(owner) then
			self:ToggleViewModelVisibility(owner:GetViewModel(), false)
		end

		return BaseClass.Holster(self)
	end

	function SWEP:OnRemove()
		local owner = self:GetOwner()

		if IsValid(owner) then
			self:ToggleViewModelVisibility(owner:GetViewModel(), false)
		end

		if IsValid(self.ClientsideWorldModel.Model) then
			self.ClientsideWorldModel.Model:Remove()
		end

		if IsValid(self.ClientsideViewModel.Model) then
			self.ClientsideViewModel.Model:Remove()
		end

		BaseClass.OnRemove(self)
	end

	function SWEP:OwnerChanged()
		local owner = self:GetOwner()

		if not IsValid(owner) and IsValid(self.CurrentOwner) then
			self:ToggleViewModelVisibility(self.CurrentOwner:GetViewModel(), false)
		end

		self.CurrentOwner = owner
	end

	function SWEP:PostDrawViewModel(vm, pl, wep)
		if not vm._brickHack then
			self:ToggleViewModelVisibility(vm, true)
		end

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

		modelData.Model:DrawModel()

		BaseClass.PostDrawViewModel(self, vm, pl, wep)
	end

	function SWEP:DrawWorldModel(flags)
		if not self:TryDrawWorldModel() then
			self:DrawModel(flags)
		end
	end

	function SWEP:TryDrawWorldModel()
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

		modelData.Model:DrawModel()

		return true
	end
end