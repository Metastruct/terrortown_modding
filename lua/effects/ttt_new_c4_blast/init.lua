local particleMist = Material("particle/particle_noisesphere")
local particleMistGravity = Vector(0, 0, -40)
local particleMistColor = Color(135, 135, 135)

local particleExplod = Material("particles/flamelet5")

local particleSplash = Material("effects/splash4")
local particleSplashGravity = Vector(0, 0, -1000)

function EFFECT:Init(data)
	local pos = data:GetOrigin()
	local radius = data:GetRadius()

	local emitter = ParticleEmitter(pos)

	local randDist = math.random()
	local randPos = VectorRand()

	if data:GetFlags() == 1 then
		local shootUpwards

		for i = 1, 150 do
			shootUpwards = i >= 100

			randDist = math.random()

			if shootUpwards then
				randPos = Vector(math.Rand(-0.4, 0.4), math.Rand(-0.4, 0.4), math.Rand(0.8, 1))
			else
				randPos = VectorRand()
				if randPos.z < 0.6 then randPos.z = math.Rand(0.6, 1) end
			end

			randPos:Normalize()
			randPos:Mul(randDist * 50)

			local p = emitter:Add(particleSplash, pos + randPos)

			if p then
				p:SetDieTime(2)
				p:SetRoll(math.random(0, 360))
				p:SetRollDelta(math.Rand(-0.5, 0.5))

				p:SetStartSize(150)
				p:SetEndSize(200)
				p:SetStartAlpha(math.random(50, 100))
				p:SetEndAlpha(0)
				--p:SetLighting(true)

				randPos:Normalize()
				randPos:Mul(shootUpwards and math.Rand(1200, 2500) or 1200)

				p:SetGravity(particleSplashGravity)
				p:SetVelocity(randPos)
				p:SetAirResistance(50)
				p:SetBounce(0.25)
				p:SetCollide(true)
			end
		end

		emitter:Finish()
	else
		for i = 1, 50 do
			randDist = math.random()
			randPos = VectorRand()
			randPos:Normalize()
			randPos:Mul(randDist * 50)

			local p = emitter:Add(particleExplod, pos + randPos)

			if p then
				p:SetDieTime(0.4)
				p:SetRoll(math.random(0, 360))
				p:SetRollDelta(math.random() > 0.5 and 50 or -50)

				p:SetStartSize(20)
				p:SetEndSize(200)
				p:SetStartAlpha(255)
				p:SetEndAlpha(0)

				randPos:Normalize()
				randPos:Mul(2500)

				p:SetVelocity(randPos)
				p:SetAirResistance(600)
			end
		end

		timer.Simple(0.1, function()
			for i = 1, 200 do
				randDist = math.random()
				randPos = VectorRand()
				randPos:Normalize()
				randPos:Mul(randDist * radius * 0.33)

				local p = emitter:Add(particleMist, pos + randPos)

				if p then
					p:SetDieTime(math.Rand(8, 16))
					p:SetRoll(math.random(0, 360))
					p:SetRollDelta(math.Rand(-0.5, 0.5))

					p:SetStartSize(150)
					p:SetEndSize(200)
					p:SetStartAlpha(200)
					p:SetEndAlpha(0)
					p:SetColor(particleMistColor.r, particleMistColor.g, particleMistColor.b)
					p:SetLighting(true)

					randPos:Normalize()
					randPos:Mul(math.Rand(1250, 2500))

					p:SetGravity(particleMistGravity)
					p:SetVelocity(randPos)
					p:SetAirResistance(300)
				end
			end

			emitter:Finish()
		end)
	end
end

function EFFECT:Think()
	return false
end

function EFFECT:Render() end