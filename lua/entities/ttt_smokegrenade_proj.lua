if SERVER then
	AddCSLuaFile()
end

DEFINE_BASECLASS("ttt_basegrenade_proj")

ENT.Model = Model("models/weapons/w_eq_smokegrenade_thrown.mdl")

AccessorFunc(ENT, "radius", "Radius", FORCE_NUMBER)

function ENT:Initialize()
	if not self:GetRadius() then
		self:SetRadius(20)
	end

	return BaseClass.Initialize(self)
end

if CLIENT then
	local smokeparticles = {
		"particle/particle_smokegrenade",
		"particle/particle_noisesphere",
	}

	function ENT:CreateSmoke(center)
		local em = ParticleEmitter(center)

		local r = self:GetRadius()

		for i = 1, 20 do
			local prpos = VectorRand() * r
			prpos.z = prpos.z + 32

			local p = em:Add(table.Random(smokeparticles), center + prpos)
			if p then
				local gray = math.random(75, 200)

				p:SetColor(gray, gray, gray)
				p:SetStartAlpha(255)
				p:SetEndAlpha(200)
				p:SetVelocity(VectorRand() * math.Rand(900, 1300))
				p:SetLifeTime(0)

				p:SetDieTime(math.Rand(50, 70))

				p:SetStartSize(math.random(140, 150))
				p:SetEndSize(math.random(1, 40))
				p:SetRoll(math.random(-180, 180))
				p:SetRollDelta(math.Rand(-0.1, 0.1))
				p:SetAirResistance(600)

				p:SetCollide(true)
				p:SetBounce(0.4)

				p:SetLighting(false)
			end
		end

		em:Finish()
	end
end

function ENT:Explode(tr)
	local traceCut = tr.Fraction != 1

	if SERVER then
		self:SetNoDraw(true)
		self:SetSolid(SOLID_NONE)

		-- Pull out of the surface
		if traceCut then
			self:SetPos(tr.HitPos + tr.HitNormal * 0.6)
		end

		self:Remove()
	else
		self:SetDetonateExact(0)

		local spos = self:GetPos()
		util.PaintDown(spos, "SmallScorch", self)

		sound.Play("ambient/levels/canals/toxic_slime_sizzle4.wav", spos, 66, 75, 0.25)

		if traceCut then
			spos = tr.HitPos + tr.HitNormal * 0.6
		end

		-- Smoke particles can't get cleaned up when a round restarts, so prevent them from existing post-round.
		if gameloop.GetRoundState() == ROUND_POST then return end

		self:CreateSmoke(spos)
	end
end