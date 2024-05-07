local className = "ttt_roblox_rocket"

if SERVER then
	AddCSLuaFile()

	resource.AddFile("models/robloxstuff/classic/rocket.mdl")
	resource.AddFile("materials/models/robloxstuff/surface/stud.vmt")

	-- HL1 explosion sprite for the funny
	resource.AddFile("materials/hl1/sprites/zerogxplode.vmt")

	resource.AddSingleFile("sound/robloxstuff/classic/explode.mp3")
	resource.AddSingleFile("sound/robloxstuff/classic/swoosh.mp3")
end

ENT.Type = "anim"
ENT.ClassName = className

ENT.Model = "models/robloxstuff/classic/rocket.mdl"

ENT.CanPickup = false
ENT.Projectile = true

ENT.FireSound = ")robloxstuff/classic/swoosh.mp3"
ENT.ExplodeSound = ")robloxstuff/classic/explode.mp3"

if SERVER then
	function ENT:Initialize()
		self:SetModel( self.Model )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )

		self:EmitSound( self.FireSound, 80 )
	end

	function ENT:Explode( pos, nor )
		self:StopSound( self.FireSound )
		self:EmitSound( self.ExplodeSound, 90 )

		-- hl1_explosion effect code by Upset
		local exp = EffectData()
		exp:SetOrigin(pos + (nor * -32))
		exp:SetNormal(nor)
		exp:SetScale(50)
		exp:SetFlags(1)
		util.Effect("hl1_explosion", exp)

		local ply = self:GetOwner()

		util.BlastDamage( self, IsValid( ply ) and ply or self, self:GetPos(), 250, 100 )

		util.ScreenShake( self:GetPos(), 80, 1, 1, 800, true )
		util.Decal( "Scorch", pos + (nor * -2),  pos + (nor * 2), self )

		self:Remove()
	end

	function ENT:PhysicsCollide( data, phys )
		self:Explode( data.HitPos, data.HitNormal )
	end
end