local className = "weapon_ttt_robloxbazooka"

if SERVER then
	AddCSLuaFile()

	resource.AddFile("models/robloxstuff/classic/c_bazooka.mdl")
	resource.AddFile("models/robloxstuff/classic/w_bazooka.mdl")
	resource.AddFile("materials/models/robloxstuff/classic/bazooka.vmt")

	resource.AddFile("materials/vgui/ttt/icon_robloxbazooka.vmt")
else
	SWEP.PrintName = "ROBLOX Bazooka"
	SWEP.Author = "RetroSource (Ported to TTT by TW1STaL1CKY)"
	SWEP.Slot = 8
	SWEP.SlotPos = 1

	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 60

	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "A bazooka from another world. Fires one slow funny rocket."
	}

	SWEP.Icon = "vgui/ttt/icon_robloxbazooka"
	SWEP.IconLetter = "c"
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.ClassName = className
SWEP.HoldType = "rpg"

SWEP.ViewModel = "models/robloxstuff/classic/c_bazooka.mdl"
SWEP.WorldModel = "models/robloxstuff/classic/w_bazooka.mdl"

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 0.5
SWEP.Primary.Ammo = "none"

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = {ROLE_TRAITOR}
SWEP.LimitedStock = true

SWEP.DeploySpeed = 1
SWEP.NoSights = true

SWEP.RocketEntity = "ttt_roblox_rocket"
SWEP.RocketVelocity = 500

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", 0, "Fired")
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )

	if self:GetFired() then
		self:EmitSound("weapons/pistol/pistol_empty.wav", 70, 100, 0.5, CHAN_ITEM)

		return
	end

	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )

	self:SetFired(true)

	if SERVER then
		local ply = self:GetOwner()
		if not IsValid( ply ) then return end

		local pos = ply:GetShootPos()
		local ang = ply:EyeAngles()
		local vel = ang:Forward() * self.RocketVelocity

		self:CreateEntity( pos, ang, vel, ply )
		self:SetClip1(0)
	end
end

function SWEP:SecondaryAttack() return end

function SWEP:Reload() return end

if SERVER then
	function SWEP:CreateEntity( pos, ang, vel, ply )
		local ent = ents.Create( self.RocketEntity )
		if not IsValid( ent ) then return end

		ent:SetPos( pos )
		ent:SetAngles( ang )
		ent:SetOwner( ply )

		ent:Spawn()
		ent:PhysWake()

		local phys = ent:GetPhysicsObject()
		if !IsValid( phys ) then ent:Remove() return end
		phys:EnableGravity( false )
		phys:EnableDrag( false )
		phys:SetBuoyancyRatio( 0 )
		phys:SetVelocity( vel )

		return ent
	end
end