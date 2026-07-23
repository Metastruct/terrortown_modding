-- Gore effect for Twist's Headshot gore script

local particleChunk = Material("effects/fleck_cement2")
local particleMist = Material("particle/particle_noisesphere")
local particleBlood = Material("particle/smokesprites_0006")

local particleChunkGravity = Vector(0, 0, -400)
local particleMistGravity = Vector(0, 0, -60)
local particleBloodGravity = Vector(0, 0, -200)

local particleChunkColor = Color(230, 120, 120)
local particleBloodColor = Color(140, 0, 0)

local function applyBloodDecal(p, hitPos, hitNormal)
	util.Decal("Blood", hitPos, hitPos - (hitNormal * 4))

	p:SetDieTime(0)
end

local function setupBloodParticle(p, vel, lifeTime)
	p:SetDieTime(lifeTime)
	p:SetRoll(math.random(0, 360))

	p:SetStartSize(2)
	p:SetEndSize(2)
	p:SetStartLength(12.5)
	p:SetEndLength(12.5)
	p:SetStartAlpha(200)
	p:SetEndAlpha(20)
	p:SetColor(particleBloodColor.r, particleBloodColor.g, particleBloodColor.b)
	p:SetLighting(true)

	p:SetGravity(particleBloodGravity)
	p:SetVelocity(vel)
	p:SetAirResistance(1)
	p:SetBounce(0)
	p:SetCollide(true)

	p:SetCollideCallback(applyBloodDecal)
end

function EFFECT:Init(data)
	local pos = data:GetOrigin()
	local dir = data:GetNormal()

	local emitter = ParticleEmitter(pos)

	-- Chunks
	for i = 1, 50 do
		local p = emitter:Add(particleChunk, pos + VectorRand(-3, 3))

		if p then
			p:SetDieTime(3)
			p:SetRoll(math.random(0, 360))

			local size = math.Rand(1, 2.5)

			p:SetStartSize(size)
			p:SetEndSize(size)
			p:SetStartAlpha(255)
			p:SetEndAlpha(0)
			p:SetColor(particleChunkColor.r, particleChunkColor.g, particleChunkColor.b)
			p:SetLighting(true)

			p:SetGravity(particleChunkGravity)
			p:SetVelocity(VectorRand(-180, 180))
			p:SetAirResistance(1)
			p:SetBounce(0.1)
			p:SetCollide(true)
		end
	end

	-- Mist
	for i = 1, 15 do
		local p = emitter:Add(particleMist, pos)

		if p then
			p:SetDieTime(2.5)
			p:SetRoll(math.random(0, 360))
			p:SetRollDelta(math.Rand(-0.5, 0.5))

			p:SetStartSize(16)
			p:SetEndSize(32)
			p:SetStartAlpha(150)
			p:SetEndAlpha(0)
			p:SetColor(particleBloodColor.r, particleBloodColor.g, particleBloodColor.b)
			p:SetLighting(true)

			p:SetGravity(particleMistGravity)
			p:SetVelocity(VectorRand(-150, 150))
			p:SetAirResistance(400)
			p:SetCollide(true)
			p:SetBounce(0.75)
		end
	end

	-- Bloodsplatters (random directions)
	for i = 1, 25 do
		local p = emitter:Add(particleBlood, pos + VectorRand(-3, 3))

		if p then
			local vecDir = VectorRand()
			vecDir:Normalize()
			vecDir:Mul(400)

			setupBloodParticle(p, vecDir, 2)
		end
	end

	-- Bloodsplatters (directed by GetNormal)
	local isDirected = dir and dir != vector_origin
	local spread, dirRight, dirUp

	if isDirected then
		spread = 0.3

		local dirAng = dir:Angle()

		dirRight = dirAng:Right()
		dirUp = dirAng:Up()
	end

	for i = 1, 40 do
		local p = emitter:Add(particleBlood, pos + VectorRand(-3, 3))

		if p then
			local spreadDir = isDirected
				and (dir + (math.Rand(-spread, spread) * dirRight) + (math.Rand(-spread, spread) * dirUp))
				or VectorRand()

			spreadDir:Normalize()
			spreadDir:Mul(math.random(300, 450))

			setupBloodParticle(p, spreadDir, 0.8)
		end
	end

	emitter:Finish()
end

function EFFECT:Think()
	return false
end

function EFFECT:Render() end