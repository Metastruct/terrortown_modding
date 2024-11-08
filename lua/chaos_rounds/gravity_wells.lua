local ROUND = {}
TEST = ROUND
ROUND.Name = "Gravity Wells"
ROUND.Description = "Mysterious gravity wells appear around the map, pulling in players and props! Watch your step..."

local TAG = "ChaosRoundGravityWells"

-- Config
local WELL_COUNT = 4
local WELL_LIFETIME = 20
local WELL_RADIUS = 600
local PULL_FORCE = 2000
local MIN_SPAWN_INTERVAL = 5
local MAX_SPAWN_INTERVAL = 15

if SERVER then
	util.AddNetworkString(TAG .. "_NewWell")
	local activeWells = {}
	local playerPositions = {}

	local function TryPosition()
		-- Get random position from where players have been
		local pos
		if #playerPositions == 0 then
			-- Fallback to random player position if no history
			local players = player.GetAll()
			if #players == 0 then return end
			local randomPlayer = players[math.random(#players)]
			pos = randomPlayer:GetPos()
		else
			pos = table.Random(playerPositions)
		end

		-- Check if there's already a well nearby
		for _, well in ipairs(activeWells) do
			if well.pos:DistToSqr(pos) < WELL_RADIUS * WELL_RADIUS * 2 then
				return nil
			end
		end

		return pos
	end

	local function CreateGravityWell()
		-- Try up to 3 times to find a valid position
		local pos
		for i = 1, 3 do
			pos = TryPosition()
			if pos then break end
		end

		-- If we couldn't find a position after 3 tries, use the last attempted one
		if not pos then return end

		-- Create well data
		local well = {
			pos = pos,
			endTime = CurTime() + WELL_LIFETIME,
			reverse = math.random() < 0.5 -- 50% chance for repulsion instead of attraction
		}
		table.insert(activeWells, well)

		sound.Play("ambient/machines/teleport" .. math.random(3, 4) .. ".wav", well.pos)

		-- Notify clients
		net.Start(TAG .. "_NewWell")
		net.WriteVector(pos)
		net.WriteBool(well.reverse)
		net.Broadcast()

		return well
	end

	function ROUND:Start()
		-- Start tracking player positions
		playerPositions = {}
		timer.Create(TAG .. "_TrackPlayers", 1, 0, function()
			for _, ply in ipairs(player.GetAll()) do
				if ply:IsTerror() then
					local target_pos = ply:EyePos() + Vector(math.random(-1000, 1000), math.random(-1000, 1000), 0)
					if util.IsInWorld(target_pos) then
						table.insert(playerPositions, target_pos)
					end
				end
			end
		end)

		-- Create initial wells
		for i = 1, WELL_COUNT do
			CreateGravityWell()
		end

		-- Continuously create new wells
		timer.Create(TAG .. "_Spawn", math.random(MIN_SPAWN_INTERVAL, MAX_SPAWN_INTERVAL), 0, function()
			-- Create new well if below count
			if #activeWells < WELL_COUNT then
				CreateGravityWell()
			end
		end)

		-- Apply gravity well forces
		hook.Add("Think", TAG, function()
			for i, well in ipairs(activeWells) do
				if well.endTime < CurTime() then
					-- Play multiple layered sounds
					sound.Play("ambient/explosions/explode_7.wav", well.pos)
					sound.Play("ambient/levels/citadel/weapon_disintegrate" .. math.random(1,4) .. ".wav", well.pos)

					table.remove(activeWells, i)
					continue
				end

				-- Affect players
				for _, ent in ipairs(ents.FindInSphere(well.pos, WELL_RADIUS)) do
					if not IsValid(ent) then continue end

					local phys = ent:GetPhysicsObject()
					if not IsValid(phys) then continue end

					local direction = well.pos - ent:GetPos()
					local distance = direction:Length()
					local force = direction:GetNormalized() * PULL_FORCE * (1 - distance / WELL_RADIUS)

					if well.reverse then
						force = -force
					end

					if ent:IsPlayer() and ent:IsTerror() then
						-- Players get moved directly
						ent:SetVelocity(force * 0.1)

						-- Random chance to lose weapon grip
						if math.random() < 0.01 then
							local wep = ent:GetActiveWeapon()
							if IsValid(wep) then
								ent:DropWeapon(wep)
								wep:GetPhysicsObject():ApplyForceCenter(force * 2)
							end
						end
					else
						if not phys:IsMotionEnabled() then
							phys:EnableMotion(true)
							phys:Wake()
						end

						-- Props and other physics objects
						phys:ApplyForceCenter(force)
					end
				end
			end
		end)
	end

	function ROUND:Finish()
		timer.Remove(TAG .. "_Spawn")
		hook.Remove("Think", TAG)
		activeWells = {}
	end
end

if CLIENT then
	local activeWells = {}
	local wellMaterial = Material("effects/strider_bulge_dudv")
	local glowMaterial = Material("sprites/light_glow02_add")
	local ringMaterial = Material("effects/select_ring")
	local vortexMaterial = Material("effects/combinemuzzle2")

	net.Receive(TAG .. "_NewWell", function()
		local pos = net.ReadVector()
		local reverse = net.ReadBool()

		table.insert(activeWells, {
			pos = pos,
			reverse = reverse,
			endTime = CurTime() + WELL_LIFETIME,
			startTime = CurTime()
		})
	end)

	local function draw_effects()
		local curTime = CurTime()

		-- Remove expired wells and create removal effects
		for i = #activeWells, 1, -1 do
			if activeWells[i].endTime < curTime then
				-- Create implosion effect
				local pos = activeWells[i].pos
				local effectData = EffectData()
				effectData:SetOrigin(pos)
				effectData:SetScale(WELL_RADIUS)
				util.Effect("cball_explode", effectData)

				-- Create additional particle effects
				local emitter = ParticleEmitter(pos)
				for _ = 1, 50 do
					local particle = emitter:Add("effects/blueflare1", pos)
					if particle then
						local vel = VectorRand() * 300
						particle:SetVelocity(vel)
						particle:SetDieTime(2)
						particle:SetStartAlpha(255)
						particle:SetEndAlpha(0)
						particle:SetStartSize(20)
						particle:SetEndSize(0)
						particle:SetRoll(math.Rand(0, 360))
						particle:SetRollDelta(math.Rand(-2, 2))

						if activeWells[i].reverse then
							particle:SetColor(255, 50, 0) -- Red for repelling
						else
							particle:SetColor(0, 100, 255) -- Blue for pulling
						end

						particle:SetCollide(true)
						particle:SetBounce(0.4)
						particle:SetGravity(Vector(0, 0, -400))
					end
				end
				emitter:Finish()

				-- Add screen shake
				util.ScreenShake(pos, 15, 5, 2, WELL_RADIUS * 2)

				table.remove(activeWells, i)
			end
		end

		for _, well in ipairs(activeWells) do
			local timeLeft = well.endTime - curTime
			local alpha = math.min(timeLeft * 50, 255)
			local size = WELL_RADIUS * 2
			local pulseSize = size * (1 + math.sin(curTime * 2) * 0.05)

			-- Draw the event horizon (deep black void)
			render.SetMaterial(wellMaterial)
			render.DrawSprite(well.pos, pulseSize * 0.4, pulseSize * 0.4, Color(0, 0, 0, alpha))

			-- Draw the photon sphere (intense light ring)
			render.SetMaterial(glowMaterial)
			local photonRingSize = pulseSize * 0.45
			render.DrawSprite(well.pos, photonRingSize, photonRingSize, Color(255, 200, 100, alpha * 0.8))

			-- Draw the accretion disk (spinning hot matter)
			render.SetMaterial(vortexMaterial)
			local diskCount = 12
			for i = 1, diskCount do
				local angle = curTime * 80 + (i * 360 / diskCount)
				-- Doppler effect - blue on approaching side, red on receding side
				local blueShift = math.abs(math.sin(math.rad(angle)))
				local redShift = math.abs(math.cos(math.rad(angle)))
				local diskColor = Color(
					255 * redShift,
					100 + 50 * (blueShift + redShift),
					255 * blueShift,
					alpha * 0.6
				)

				render.DrawSprite(well.pos, size * 1.4, size * 0.15, diskColor, angle)
			end

			-- Draw gravitational lensing rings
			render.SetMaterial(ringMaterial)
			local ringCount = 6
			for i = 1, ringCount do
				local scale = 1 - (i / ringCount) ^ 0.7 -- Non-linear scaling for more realistic distortion
				local ringColor = Color(100, 100, 150, alpha * 0.2 * scale)
				render.DrawSprite(well.pos, size * scale * 1.2, size * scale * 1.2, ringColor)
			end

			-- Draw matter being pulled in (with relativistic beaming effect)
			local streamCount = 15
			for i = 1, streamCount do
				local t = curTime * 4 + i * 0.3
				local radius = WELL_RADIUS * (1 - (t % 1) ^ 2) -- Non-linear acceleration
				local angle = t * 20 + i * (360 / streamCount)

				local offset = Vector(
					math.cos(math.rad(angle)) * radius,
					math.sin(math.rad(angle)) * radius,
					0
				)

				-- Particles get smaller and brighter as they approach the center
				local distScale = (1 - (t % 1))
				local particleSize = 8 * distScale
				local streamColor = Color(
					255,
					150 * distScale,
					50 * distScale,
					alpha * (1 - distScale^2) * 2
				)
				render.DrawSprite(well.pos + offset, particleSize, particleSize, streamColor)
			end
		end
	end

	local function draw_screen_effects()
		local ply = LocalPlayer()
		if not ply:IsTerror() then return end

		for _, well in ipairs(activeWells) do
			local dist = ply:GetPos():Distance(well.pos)
			if dist < WELL_RADIUS then
				local strength = (1 - dist / WELL_RADIUS) * 0.8
				local pulseStrength = strength * (1 + math.sin(CurTime() * 4) * 0.2)

				DrawMotionBlur(0.2, pulseStrength, 0.01)
				DrawSharpen(pulseStrength * 2, 0.5)

				local colorModify = {
					["$pp_colour_addr"] = well.reverse and pulseStrength * 0.4 or 0,
					["$pp_colour_addg"] = 0,
					["$pp_colour_addb"] = well.reverse and 0 or pulseStrength * 0.2,
					["$pp_colour_brightness"] = -pulseStrength * 0.3,
					["$pp_colour_contrast"] = 1 + pulseStrength * 0.8,
					["$pp_colour_colour"] = 1 - pulseStrength * 0.5,
					["$pp_colour_mulr"] = 1,
					["$pp_colour_mulb"] = 1
				}
				DrawColorModify(colorModify)

				if dist < WELL_RADIUS * 0.3 then
					DrawToyTown(pulseStrength * 5, ScrH() * pulseStrength)
				end
			end
		end
	end

	function ROUND:Start()
		-- Draw gravity well effects
		hook.Add("PostDrawTranslucentRenderables", TAG, draw_effects)

		-- Add screen effects when near wells
		hook.Add("RenderScreenspaceEffects", TAG, draw_screen_effects)
	end

	function ROUND:Finish()
		hook.Remove("PostDrawTranslucentRenderables", TAG)
		hook.Remove("RenderScreenspaceEffects", TAG)
	end
end

return RegisterChaosRound(ROUND)