if SERVER then
    AddCSLuaFile()
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.HoldType = "physgun"

if CLIENT then
    SWEP.PrintName = "newton_name"
    SWEP.Slot = 7

    SWEP.ViewModelFlip = false
    SWEP.ViewModelFOV = 54

    SWEP.EquipMenuData = {
        type = "item_weapon",
        desc = "newton_desc",
    }

    SWEP.Icon = "vgui/ttt/icon_launch"
end

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 3
SWEP.Primary.Cone = 0.005
SWEP.Primary.Sound = "weapons/ar2/fire1.wav"
SWEP.Primary.SoundLevel = 54

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 3

SWEP.NoSights = true

SWEP.Kind = WEAPON_EQUIP2
SWEP.CanBuy = { ROLE_TRAITOR }
SWEP.WeaponID = AMMO_PUSH
SWEP.builtin = true

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_superphyscannon.mdl"
SWEP.WorldModel = "models/weapons/w_physics.mdl"

local math = math

function SWEP:Initialize()
    if SERVER then
        self:SetSkin(1)
	else
        self:AddTTT2HUDHelp("Pushing shot", "Pulling shot")
    end

    return BaseClass.Initialize(self)
end

function SWEP:SetupDataTables() end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:SetNextSecondaryFire(CurTime() + self.Primary.Delay)

    self:FirePulse(750, 300)
end

function SWEP:SecondaryAttack()
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:SetNextSecondaryFire(CurTime() + self.Primary.Delay)

    self:FirePulse(-750, 300)
end

function SWEP:FirePulse(forceFwd, forceUp)
	local owner = self:GetOwner()
    if not IsValid(owner) then return end

    owner:SetAnimation(PLAYER_ATTACK1)
    self:SendWeaponAnim(ACT_VM_IDLE)

	if not IsFirstTimePredicted() then return end

	self:EmitSound(self.Primary.Sound, self.Primary.SoundLevel)

    local cone = self.Primary.Cone or 0.1

    local bullet = {}
    bullet.Num = 1
    bullet.Src = owner:GetShootPos()
    bullet.Dir = owner:GetAimVector()
    bullet.Spread = Vector(cone, cone, 0)
    bullet.Force = 0.000000001	-- Source whines if this is 0, but we want 0, so...
    bullet.Damage = 5
    bullet.Tracer = 1
    bullet.TracerName = "AirboatGunHeavyTracer"

	if SERVER then
		bullet.Callback = function(att, tr, dmginfo)
			local ent = tr.Entity

			if IsValid(ent) then
				local pushVel = tr.Normal * forceFwd

				if ent:IsPlayer() then
					if ent:IsFrozen() then return end

					pushVel.z = math.max(pushVel.z, forceUp)

					ent:SetGroundEntity(nil)
					ent:SetLocalVelocity(ent:GetVelocity() + pushVel)

					ent.was_pushed = {
						att = owner,
						t = CurTime(),
						wep = self:GetClass(),
					}
				else
					local phys = ent:GetPhysicsObject()

					if not IsValid(phys) or not phys:IsMotionEnabled() then return end

					-- Scale the push force by the entity's mass a bit (40 mass seems to be the sweet spot)
					pushVel:Mul(math.Clamp((phys:GetMass() + 80) / 120, 0.933, 1.666))

					-- "Where does 66 come from?"
					-- How Source automatically applies damage force from bullets to PhysicsObjects is it reads from the SMG1 ammo type's force value, which is ~66.8,
					-- then multiplies that by the Force value in our Bullet table... so we need to do the same if we want to replicate how bullets push things.
					phys:Wake()
					phys:ApplyForceOffset(pushVel * 66, tr.HitPos)
				end
			end
		end
	end

    owner:FireBullets(bullet)
end

if CLIENT then
    local surface = surface
    local TryT = LANG.TryTranslation

    function SWEP:DrawHUD()
        self:DrawHelp()

        local x = ScrW() / 2
        local y = ScrH() / 2

        local nxt = self:GetNextPrimaryFire()

        if LocalPlayer():IsTraitor() then
            surface.SetDrawColor(255, 0, 0, 255)
        else
            surface.SetDrawColor(0, 255, 0, 255)
        end

        if nxt < CurTime() or CurTime() % 0.5 < 0.2 then
            local length = 10
            local gap = 5

            surface.DrawLine(x - length, y, x - gap, y)
            surface.DrawLine(x + length, y, x + gap, y)
            surface.DrawLine(x, y - length, x, y - gap)
            surface.DrawLine(x, y + length, x, y + gap)
        end

        if nxt > CurTime() then
            local w = 40

            w = (w * (math.max(0, nxt - CurTime()) / self.Primary.Delay)) / 2

            local bx = x + 30
            surface.DrawLine(bx, y - w, bx, y + w)

            bx = x - 30
            surface.DrawLine(bx, y - w, bx, y + w)
        end
    end
end