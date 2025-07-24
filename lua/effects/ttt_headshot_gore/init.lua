-- Gore effect for Twist's Headshot gore script

local particleChunk = Material("effects/fleck_cement2")
local particleMist = Material("particle/particle_noisesphere")

local particleChunkGravity = Vector(0, 0, -420)
local particleBloodGravity = Vector(0, 0, -150)
local particleMistGravity = Vector(0, 0, -60)

local particleChunkColor = Color(255, 130, 130)
local particleBloodColor = Color(160, 0, 0)

local function applyBloodDecal(p, hitPos, hitNormal)
	util.Decal("Blood", hitPos, hitPos - (hitNormal * 4))

	p:SetDieTime(0)
end

function EFFECT:Init(data)
	local pos = data:GetOrigin()

	local emitter = ParticleEmitter(pos)

	for i = 1, 40 do
		local p = emitter:Add(particleChunk, pos + VectorRand(-3, 3))

		if p then
			p:SetDieTime(3)
			p:SetRoll(math.random(0, 360))

			local size = math.random(1, 2)

			p:SetStartSize(size)
			p:SetEndSize(size)
			p:SetStartAlpha(255)
			p:SetEndAlpha(0)
			p:SetColor(particleChunkColor.r, particleChunkColor.g, particleChunkColor.b)
			p:SetLighting(true)

			p:SetGravity(particleChunkGravity)
			p:SetVelocity(VectorRand(-150, 150))
			p:SetAirResistance(1)
			p:SetBounce(0.1)
			p:SetCollide(true)
		end
	end

	for i = 1, 25 do
		local p = emitter:Add(particleMist, pos + VectorRand(-3, 3))

		if p then
			p:SetDieTime(3)
			p:SetRoll(math.random(0, 360))

			p:SetStartSize(2)
			p:SetEndSize(2)
			p:SetStartLength(16)
			p:SetEndLength(16)
			p:SetStartAlpha(255)
			p:SetEndAlpha(255)
			p:SetColor(particleBloodColor.r, particleBloodColor.g, particleBloodColor.b)
			p:SetLighting(true)

			local vecDir = VectorRand()
			vecDir:Normalize()
			vecDir:Mul(500)

			p:SetGravity(particleBloodGravity)
			p:SetVelocity(vecDir)
			p:SetAirResistance(1)
			p:SetBounce(0)
			p:SetCollide(true)

			p:SetCollideCallback(applyBloodDecal)
		end
	end

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

	emitter:Finish()
end

function EFFECT:Think()
	return false
end

function EFFECT:Render() end