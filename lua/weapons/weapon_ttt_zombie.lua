local Tag = "weapon_ttt_zombie"
SWEP.WorldModel = Model("models/weapons/w_stunbaton.mdl")
SWEP.PrintName = "Claws"
SWEP.Purpose = "Brains."
SWEP.Instructions = [[Primary: Slap the crap out of stuff
Secondary: Climb walls]]
SWEP.Spawnable = false
SWEP.DrawAmmo = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.Ammo = "none"

local function simple(d, f, ...)
	local x = {...}

	timer.Simple(d, function()
		f(unpack(x))
	end)
end

local m

function SWEP:DrawWeaponSelection(x, y, w, h, a)
	m = m or Material"vgui/hud/markfordeath"
	if m:IsError() then return end
	surface.SetDrawColor(255, 222, 22, a * 0.6)
	surface.SetMaterial(m)
	local sz = math.min(w, h) * .7
	x, y = x + w * .5 - sz * .5, y + h * .5 - sz * .5
	surface.DrawTexturedRect(x, y, sz, sz)
end

function SWEP:PrimaryAttack()
	if SERVER and self:GetOwner():GetDTInt(3) == 0 then
		self:GetOwner():SetDTInt(2, 1)
	end
end

function SWEP:DrawWorldModel()
	self:DestroyShadow()
	self:DrawShadow(false)

	if not IsValid(self:GetOwner()) then
		self:DrawModel()
	end
end

function SWEP:SecondaryAttack()
	local tr, att
	if self:GetOwner():GetDTInt(3) > 0 then return end
	local pl = self:GetOwner()
	pl.HeadBone = pl.HeadBone or pl:LookupAttachment("head")

	att = pl.HeadBone and pl:GetAttachment(pl.HeadBone) or {
		Pos = pl:GetShootPos()
	}

	tr = {}
	tr.start = att.Pos
	tr.endpos = tr.start + self:GetOwner():GetForward() * 48
	tr.filter = self:GetOwner()
	tr = util.TraceLine(tr)

	if tr.Hit and not (tr.Entity:IsNPC() or tr.Entity:IsPlayer()) and tr.StartPos:Distance(tr.HitPos) < 32 and self:GetOwner():GetDTInt(3) == 0 then
		self:GetOwner():SetDTInt(3, 2)
		--timer.Simple( 1, pcall, self:GetOwner().SetDTInt, self:GetOwner(), 3, 2 )
		--self:GetOwner():SetPos( Vector( tr.HitPos.x, tr.HitPos.y, self:GetOwner():GetPos( ).z ) )
	end
end

function SWEP:Reload()
	if self:GetOwner():GetGroundEntity() ~= NULL and self:GetOwner():GetDTInt(2) == 0 then
		self:GetOwner():EmitSound("NPC_FastZombie.LeapAttack")
		self:GetOwner():SetDTInt(2, 1)
		self:GetOwner():SetGroundEntity(NULL)
		local av = self:GetOwner():EyeAngles()
		av.r = 0
		av.p = 0
		av:RotateAroundAxis(av:Right(), 45)
		av = av:Forward()
		av:Mul(512)
		self:GetOwner():SetLocalVelocity(av)
		simple(1, pcall, self:GetOwner().SetDTInt, self:GetOwner(), 2, 0)
	end
end

function SWEP:Think()
	local pl = self:GetOwner()

	if SERVER then
		if not pl:IsValid() then
			self:Remove()

			return
		end

		if not self:GetOwner():KeyDown(IN_ATTACK) then
			self:GetOwner():SetDTInt(2, 0)
		end
	end

	self.LastSwipe = self.LastSwipe or CurTime()
	local vel, tr, forw, tr2
	vel = Vector(0)
	forw = self:GetOwner():GetForward()
	forw.z = 0

	if self:GetOwner():GetDTInt(3) == 2 then
		vel = vel + Vector(0, 0, 1) * 80
		vel = vel + forw * 8
	end

	pl.HeadBone = pl.HeadBone or pl:LookupAttachment("head")

	local att = pl.HeadBone and pl:GetAttachment(pl.HeadBone) or {
		Pos = pl:GetShootPos()
	}

	tr = {}
	tr.start = att.Pos
	tr.endpos = tr.start + forw * 32
	tr.filter = self:GetOwner()
	tr = util.TraceLine(tr)
	self.LastSwipe = self.LastSwipe or CurTime()

	if self:GetOwner():GetDTInt(2) == 1 and self:GetOwner():GetDTInt(3) == 0 and self.LastSwipe + .2 <= CurTime() then
		tr2 = {}
		tr2.start = self:GetOwner():GetShootPos()
		tr2.endpos = tr2.start + self:GetOwner():GetAimVector() * 80
		tr2.filter = self:GetOwner()
		tr2 = util.TraceLine(tr2)
		self:GetOwner():EmitSound(tr2.Hit and "NPC_FastZombie.AttackHit" or "NPC_FastZombie.AttackMiss")

		if IsValid(tr2.Entity) and SERVER then
			local info
			info = DamageInfo()
			info:SetAttacker(self:GetOwner())
			info:SetInflictor(self)
			info:SetDamage(20)
			info:SetDamageType(bit.bor(DMG_SLASH, DMG_CLUB))
			info:SetDamagePosition(tr2.HitPos)
			info:SetMaxDamage(20)
			info:SetDamageForce(tr2.Normal * 16)
			tr2.Entity:TakeDamageInfo(info)
			tr2.Entity:TakePhysicsDamage(info)
		end

		self.LastSwipe = CurTime()
	end

	if (self:GetOwner():GetDTInt(3) == 2 and tr.HitPos:Distance(tr.StartPos) > 16) and not tr.Hit then
		--We"ve reached a ledge, so stop climbing and go over there
		if SERVER then
			self:GetOwner():SetDTInt(3, 3)
			simple(.5, pcall, self:GetOwner().SetDTInt, self:GetOwner(), 3, 0)
		end
	end

	if self:GetOwner():GetDTInt(3) == 3 then
		vel = vel + Vector(0, 0, 1) * 128
		vel = vel + forw * 32
	end

	if self:GetOwner():GetDTInt(3) > 0 then
		if SERVER and self:GetOwner():GetDTInt(3) == 3 then
			if self:GetOwner():GetGroundEntity() == Entity(0) then
				self:GetOwner():SetDTInt(3, 0)
			end
		end

		self:GetOwner():SetGroundEntity(NULL)
		self:GetOwner():SetLocalVelocity(vel)
	end
end

function SWEP:Deploy()
	local own = self:GetOwner()

	if SERVER then
		own.pac_last_modifier_model = false
		self:GetOwner():SetModel("models/Zombie/Fast.mdl")
		self:GetOwner():DrawWorldModel(false)
		--gamemode.Call("SetPlayerSpeed", self:GetOwner(), 55, 218)
	end

	return true
end

function SWEP:Holster()
	if SERVER then
		gamemode.Call("PlayerSetModel", self:GetOwner())
		self:GetOwner():DrawWorldModel(true)
		--gamemode.Call("SetPlayerSpeed", self:GetOwner(), 250, 500)
	end

	return true
end

SWEP.mr_grundley = true

local function IsGood(pl)
	local wep = pl:GetActiveWeapon()
	if not wep:IsValid() then return false end
	if not wep.mr_grundley then return end
	if not pl:Alive() then return false end

	return not pl:InVehicle()
end

local function UpdateAnimation(pl, vel, maxspeed)
	if not IsGood(pl) then return end
	local ang, eyaw, myaw
	ang = pl:EyeAngles()
	pl:SetLocalAngles(ang)

	if CLIENT then
		pl:SetRenderAngles(ang)
	end

	eyaw = math.Clamp(math.deg(math.atan2(vel.y, vel.x)), -180, 180)
	myaw = math.NormalizeAngle(math.NormalizeAngle(ang.y) - eyaw)
	pl:SetPoseParameter("move_yaw", myaw)

	--Attacking
	if pl:GetDTInt(2) > 0 then
		pl:SetPlaybackRate(2)
	else
		pl:SetPlaybackRate(1)
	end

	return true
end

local function CalcMainActivity(pl, vel)
	if not IsGood(pl) then return end
	local len, int
	len = vel:Length2D()
	int = pl:GetDTInt(3)
	pl.CalcIdeal = ACT_IDLE
	pl.CalcSeqOverride = -1

	if len > 0 and len < 60 then
		pl.CalcIdeal = ACT_WALK
	elseif len >= 60 then
		pl.CalcIdeal = ACT_RUN
	end

	if int > 0 then
		--Climbing
		if int == 1 then
			--Mount
			--The mounting animation fast zombies have doesn"t seem to work, so just jump instead
			pl.CalcIdeal = ACT_JUMP
		elseif int == 2 then
			--Climb
			pl.CalcIdeal = ACT_CLIMB_UP
		elseif int == 3 then
			--Dismount
			pl.CalcIdeal = ACT_CLIMB_DISMOUNT
		end
	end

	if pl:GetDTInt(2) > 0 then
		pl.CalcIdeal = ACT_MELEE_ATTACK1
	end

	return pl.CalcIdeal, pl.CalcSeqOverride
end

local function GetFallDamage(pl)
	if IsGood(pl) and not pl.in_rpland then return 0 end
end

local function PlayerFootstep(pl, pos, foot, snd, vol, rf)
	if not IsGood(pl) then return end

	if pl:GetVelocity():Length2D() >= 60 then
		sound.Play(foot == 1 and "NPC_FastZombie.GallopRight" or "NPC_FastZombie.GallopLeft", pos, vol)
	else
		sound.Play(foot == 1 and "NPC_FastZombie.FootstepRight" or "NPC_FastZombie.FootstepLeft", pos, vol)
	end

	return true
end

hook.Add("UpdateAnimation", Tag, UpdateAnimation)
hook.Add("CalcMainActivity", Tag, CalcMainActivity)
hook.Add("GetFallDamage", Tag, GetFallDamage)
hook.Add("PlayerFootstep", Tag, PlayerFootstep)

if CLIENT then
	local tr = {}
	local view = {}

	local function CalcView(pl, origin, angles, fov)
		if not IsGood(pl) then return end
		if GetViewEntity() ~= pl then return end
		pl.HeadBone = pl.HeadBone or pl:LookupAttachment("head")

		local att = pl.HeadBone and pl:GetAttachment(pl.HeadBone) or {
			Pos = pl:GetShootPos()
		}

		tr.start = att.Pos
		tr.endpos = tr.start + pl:GetAimVector() * 8
		tr.filter = pl
		tr = util.TraceLine(tr)
		view.origin = tr.HitPos - tr.Normal * 8 -- + pl:GetUp( ) * 16 + pl:GetRight( ) * 16
		view.fov = fov

		return view
	end

	local function ShouldDrawLocalPlayer()
		if IsGood(LocalPlayer()) then return true end
	end

	hook.Add("CalcView", Tag, CalcView)
	hook.Add("ShouldDrawLocalPlayer", Tag, ShouldDrawLocalPlayer)
end

function SWEP:ShouldDropOnDie()
	return false
end

function SWEP:OnDrop()
	self:SetTrigger(false)
	SafeRemoveEntity(self, 0.1)
end