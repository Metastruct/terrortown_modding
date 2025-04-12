local particleFleck = Material("effects/fleck_cement2")
local particleDust = Material("particle/particle_noisesphere")
local particleFleckGravity = Vector(0, 0, -420)
local particleDustGravity = Vector(0, 0, -80)
local particleColor = Color(200, 200, 200)

function EFFECT:Init(data)
	local pos = data:GetOrigin()

	local emitter = ParticleEmitter(pos)

	for i = 1, 24 do
		local p = emitter:Add(particleFleck, pos + VectorRand(-3, 3))

		if p then
			p:SetDieTime(3)
			p:SetRoll(math.random(0, 360))

			p:SetStartSize(2)
			p:SetEndSize(2)
			p:SetStartAlpha(255)
			p:SetEndAlpha(0)
			p:SetColor(particleColor.r, particleColor.g, particleColor.b)
			p:SetLighting(true)

			p:SetGravity(particleFleckGravity)
			p:SetVelocity(VectorRand(-400, 400))
			p:SetAirResistance(1)
			p:SetBounce(0.333)
			p:SetCollide(true)
		end
	end

	for i = 1, 8 do
		local p = emitter:Add(particleDust, pos)

		if p then
			p:SetDieTime(4)
			p:SetRoll(math.random(0, 360))
			p:SetRollDelta(math.Rand(-1, 1))

			p:SetStartSize(40)
			p:SetEndSize(60)
			p:SetStartAlpha(100)
			p:SetEndAlpha(0)
			p:SetColor(particleColor.r, particleColor.g, particleColor.b)
			p:SetLighting(true)

			p:SetGravity(particleDustGravity)
			p:SetVelocity(VectorRand(-500, 500))
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