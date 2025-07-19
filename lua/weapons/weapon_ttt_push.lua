if SERVER then
	AddCSLuaFile()
end

local antiMoveTag = "TTTPushAntiMove"

DEFINE_BASECLASS("weapon_tttbase")

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

SWEP.HoldType = "physgun"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.Damage = 4
SWEP.Primary.Delay = 1.25
SWEP.Primary.Cone = 0.005
SWEP.Primary.Sound = "weapons/ar2/fire1.wav"
SWEP.Primary.Sound2 = "weapons/airboat/airboat_gun_energy2.wav"
SWEP.Primary.SoundLevel = 55

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 1.25

SWEP.NoSights = true

SWEP.Kind = WEAPON_EQUIP2
SWEP.CanBuy = { ROLE_TRAITOR }
SWEP.WeaponID = AMMO_PUSH
SWEP.builtin = true

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_superphyscannon.mdl"
SWEP.WorldModel = "models/weapons/w_physics.mdl"

SWEP.idleResetFix = true

SWEP.HeadshotMultiplier = 1
SWEP.DoorDamageMultiplier = 75

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

	self:FirePulse(800, 300)
end

function SWEP:SecondaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self:SetNextSecondaryFire(CurTime() + self.Primary.Delay)

	self:FirePulse(-800, 300)
end

function SWEP:FirePulse(forceFwd, forceUp)
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	owner:SetAnimation(PLAYER_ATTACK1)
	self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)

	owner:ViewPunch(Angle(-1, 0, 0))

	if not IsFirstTimePredicted() then return end

	self:EmitSound(self.Primary.Sound, self.Primary.SoundLevel)
	self:EmitSound(self.Primary.Sound2, self.Primary.SoundLevel, math.random(66, 88), 0.225, CHAN_VOICE)

	local cone = self.Primary.Cone or 0.1

	local bullet = {
		Inflictor = self,
		Num = 1,
		Src = owner:GetShootPos(),
		Dir = owner:GetAimVector(),
		Spread = Vector(cone, cone, 0),
		Force = 0.000000001,	-- Source whines if this is 0, but we want 0, so...
		Damage = self.Primary.Damage or 1,
		Tracer = 1,
		TracerName = "AirboatGunHeavyTracer"
	}

	if SERVER then
		bullet.Callback = function(att, tr, dmginfo)
			local ent = tr.Entity

			if IsValid(ent) then
				local pushVel = tr.Normal * forceFwd

				if ent:IsPlayer() then
					if ent:IsFrozen() then return end

					pushVel.z = math.max(pushVel.z, forceUp)

					ent:SetGroundEntity(nil)
					ent:SetVelocity(-ent:GetVelocity() + pushVel)

					ent:SetNWFloat(antiMoveTag, CurTime() + 0.4)

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

hook.Add("SetupMove", antiMoveTag, function(pl, mv, cm)
	if pl:GetNWFloat(antiMoveTag) > CurTime() then
		mv:SetForwardSpeed(0)
		mv:SetSideSpeed(0)
		mv:SetUpSpeed(0)

		cm:SetForwardMove(0)
		cm:SetSideMove(0)
		cm:SetUpMove(0)
	end
end)

if CLIENT then
	local surface = surface
	local TryT = LANG.TryTranslation

	local barX, barH = 50, 40

	function SWEP:DrawHUD()
		local pl = LocalPlayer()
		if not IsValid(pl) then return end

		local nxt = self:GetNextPrimaryFire()

		if nxt > CurTime() then
			local sX, sY = ScrW() / 2, ScrH() / 2

			local bH = (barH * (math.max(0, nxt - CurTime()) / self.Primary.Delay)) / 2
			local bX = sX + barX

			local col = pl:GetRoleColor()

			surface.SetDrawColor(col.r, col.g, col.b, col.a)

			surface.DrawLine(bX, sY - bH, bX, sY + bH)

			bX = sX - barX

			surface.DrawLine(bX, sY - bH, bX, sY + bH)
		end

		BaseClass.DrawHUD(self)
	end
end