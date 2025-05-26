local nwTag = "TTTLobotomyGrenade"

local effectDuration = 13

if SERVER then
	AddCSLuaFile()

	resource.AddSingleFile("sound/weapons/lobotomy_explode.ogg")
	resource.AddSingleFile("sound/weapons/lobotomy.ogg")
end

DEFINE_BASECLASS("ttt_basegrenade_proj")

ENT.Model = Model("models/weapons/w_eq_flashbang_thrown.mdl")

function ENT:Initialize()
	self:SetColor(Color(175, 225, 255))

	return BaseClass.Initialize(self)
end

if SERVER then
	ENT.ExplodeSound = "weapons/lobotomy_explode.ogg"
	ENT.LobotomySound = "weapons/lobotomy.ogg"

	ENT.ExplodeColor = Color(255, 255, 255, 250)
	ENT.ExplodeFadedColor = Color(255, 255, 255, 100)

	ENT.ExplodeRange = 512

	function ENT:Explode(tr)
		local pos = self:GetPos()
		local rangeSqr = self.ExplodeRange ^ 2

		local fullCol, fadedCol = self.ExplodeColor, self.ExplodeFadedColor

		local trTab = {
			start = pos,
			mask = MASK_SOLID_BRUSHONLY - CONTENTS_WINDOW
		}

		local affectedPls = {}

		for k, v in ipairs(player.GetHumans()) do
			if not v:IsTerror() then continue end

			local eyePos = v:EyePos()

			if pos:DistToSqr(eyePos) <= rangeSqr then
				trTab.endpos = eyePos

				local trEye = util.TraceLine(trTab)

				if trEye.Hit then
					-- Check if the obstruction is thin enough that we just shouldn't care
					trTab.start = trEye.HitPos + (trEye.HitNormal * -0.1)

					trEye = util.TraceLine(trTab)

					-- Set .start back for future iterations
					trTab.start = pos

					if trEye.Fraction != 1 or trEye.StartPos:Distance(eyePos) * trEye.FractionLeftSolid > 8 then
						-- We hit a second obstruction, or the first obstruction is too thick, do a weaker shortened fade
						v:ScreenFade(SCREENFADE.IN, fadedCol, 2.5, 0.5)
						continue
					end
				end

				v:ScreenFade(SCREENFADE.IN, fullCol, 9, 1)
				v:SetEyeAngles(Angle(math.random(-45, 45), math.random(0, 360), 0))
				v:SetNWFloat(nwTag, CurTime() + effectDuration)

				v:SetDSP(23)

				affectedPls[#affectedPls + 1] = v
			end
		end

		if #affectedPls > 0 then
			local rf = RecipientFilter()
			rf:AddPlayers(affectedPls)

			EmitSound(self.LobotomySound, pos, -1, CHAN_AUTO, 1, 0, 0, 100, 0, rf)
		end

		sound.Play(self.ExplodeSound, pos, 80, 100)
		util.Decal("Scorch", pos, tr.HitPos + tr.Normal, self)

		local ef = EffectData()
		ef:SetStart(pos)
        ef:SetOrigin(pos)

		util.Effect("cball_explode", ef, true, true)

		SafeRemoveEntity(self)
	end
else
	local pl

	local lastTickCheck
	local now, timeEnd, timeFraction, timeFractionEased = 0, 0, 0, 0

	local particleMat, dotMat = "particle/particle_noisesphere", "particle/particle_glow_05"
	local particleGravity = Vector(0, 0, 64)

	local function ensureValues()
		if FrameNumber() != lastTickCheck then
			if not pl then
				pl = LocalPlayer()
			end

			lastTickCheck = FrameNumber()
			now, timeEnd = CurTime(), pl:GetNWFloat(nwTag)

			if now >= timeEnd then return end

			timeFraction = math.min((timeEnd - now) / effectDuration, 1)
			timeFractionEased = math.ease.OutCubic(timeFraction)
		end
	end

	ENT.AboutToExplode = false

	function ENT:Explode(tr)
		self.AboutToExplode = true
	end

	function ENT:OnRemove(fullUpdate)
		if fullUpdate or not self.AboutToExplode then return end

		local pos = self:GetPos()
		local emitter = ParticleEmitter(pos)
		if not emitter then return end

		for i = 1, 12 do
			local p = emitter:Add(particleMat, pos)
			if p then
				p:SetDieTime(3)

				p:SetRoll(math.random())
				p:SetRollDelta(math.random())

				p:SetStartAlpha(100)
				p:SetEndAlpha(0)
				p:SetStartSize(25)
				p:SetEndSize(40)

				p:SetGravity(particleGravity)
				p:SetVelocity(VectorRand(-250, 250))
				p:SetAirResistance(200)
				p:SetCollide(true)
				p:SetBounce(0.5)
			end
		end

		for i = 1, 32 do
			local p = emitter:Add(particleMat, pos)
			if p then
				p:SetDieTime(3)

				p:SetStartAlpha(255)
				p:SetEndAlpha(0)
				p:SetStartSize(1)
				p:SetEndSize(1)

				p:SetVelocity(VectorRand(-400, 400))
				p:SetAirResistance(40)
				p:SetCollide(true)
				p:SetBounce(1.1)
			end
		end

		emitter:Finish()

		timer.Simple(0.08, function()
			if not pl then
				pl = LocalPlayer()
			end

			if CurTime() >= pl:GetNWFloat(nwTag) then return end

			pos = pl:EyePos()

			emitter = ParticleEmitter(pos)
			if not emitter then return end

			for i = 1, 128 do
				local p = emitter:Add(dotMat, pos)
				if p then
					p:SetDieTime(effectDuration + 2)

					p:SetStartAlpha(255)
					p:SetEndAlpha(255)
					p:SetStartSize(12)
					p:SetEndSize(0.2)

					p:SetVelocity(VectorRand(-400, 400))
					p:SetAirResistance(0)
					p:SetCollide(true)
					p:SetBounce(1)
				end
			end

			emitter:Finish()

			-- Set the DSP back to normal clientside (supports restoring water DSP if underwater)
			timer.Simple(effectDuration, function()
				local defaultDsp = 0

				if pl:WaterLevel() == 3 then
					local waterDspConvar = GetConVar("dsp_water")
					if waterDspConvar then
						defaultDsp = waterDspConvar:GetInt()
					end
				end

				pl:SetDSP(defaultDsp)
			end)
		end)
	end

	hook.Add("RenderScreenspaceEffects", nwTag, function()
		ensureValues()

		if now < timeEnd then
			pl:SetDSP(23)

			DrawSharpen(8 * timeFractionEased, -2.5)

			if timeFraction < 0.98 then
				DrawMotionBlur(0.05, 0.85 * math.min(timeFractionEased * 2, 1), 0)
			end
		end
	end)
end