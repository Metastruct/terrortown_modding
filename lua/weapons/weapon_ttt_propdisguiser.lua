local className = "weapon_ttt_propdisguiser"
local hookTag = "TTTPropDisguiser"
local convarBreatheDelayName = "ttt_propdisguiser_breathedelay"

local CurTime = CurTime
local IsValid = IsValid
local math = math
local utilTraceLine = util.TraceLine
local utilTraceHull = util.TraceHull

if SERVER then
	AddCSLuaFile()
	resource.AddFile("materials/vgui/ttt/icon_propdisguiser.vmt")
else
	SWEP.PrintName = "Prop Disguiser"
	SWEP.Author = "TW1STaL1CKY"
	SWEP.Slot = 8
	SWEP.SlotPos = 1

	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 54
	SWEP.DrawCrosshair = false

	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "Disguise as a prop to hide in plain sight."
	}

	SWEP.Icon = "vgui/ttt/icon_propdisguiser"
	SWEP.IconLetter = "c"
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.HoldType = "normal"

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_stunstick.mdl"
SWEP.WorldModel = "models/xqm/button2.mdl"

SWEP.DeploySpeed = 1.8

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 0.1
SWEP.Primary.Ammo = "none"
SWEP.Primary.Range = 120

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 0.1
SWEP.Secondary.DelaySuccess = 1.25
SWEP.Secondary.SoundOn = "npc/scanner/scanner_nearmiss1.wav"
SWEP.Secondary.SoundOff = "npc/scanner/scanner_nearmiss2.wav"
SWEP.Secondary.SoundBreathe = ")player/breathe1.wav"

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = {ROLE_TRAITOR, ROLE_DETECTIVE}
SWEP.LimitedStock = true

SWEP.MaxPropSize = 72

SWEP.EntityClassWhitelist = {
	prop_physics = true,
	prop_physics_multiplayer = true
}

local convarBreatheDelay = CreateConVar(convarBreatheDelayName, 45, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED})

function SWEP:SetupDataTables()
	self:NetworkVar("String", 0, "SelectedModelPath")
	self:NetworkVar("Bool", 0, "Disguised")
	self:NetworkVar("Entity", 0, "DisguisedProp")

	if CLIENT then
		self:NetworkVarNotify("SelectedModelPath", function(ent, name, oldVal, newVal)
			if oldVal != newVal then
				ent:RefreshHUDHelp()
			end
		end)

		self:NetworkVarNotify("Disguised", function(ent, name, oldVal, newVal)
			if oldVal != newVal then
				timer.Simple(0, function()
					if IsValid(ent) then
						ent:RefreshHUDHelp()
					end
				end)

				local pl = LocalPlayer()

				if ent:GetOwner() == pl then
					pl.PropDisguiseViewLerp = 1
				end
			end
		end)
	end
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)

	if GetRoundState() != ROUND_ACTIVE then return end
	if self:GetDisguised() then return end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	owner:LagCompensation(true)

	local pos = owner:GetShootPos()

	local tr = utilTraceLine({
		start = pos,
		endpos = pos + (owner:GetAimVector() * self.Primary.Range),
		mask = MASK_SHOT,
		filter = owner
	})

	owner:LagCompensation(false)

	local ent = tr.Entity

	if self:IsPropEligible(ent) then
		local mdl = ent:GetModel()

		if mdl != self:GetSelectedModelPath() then
			self:SetSelectedModelPath(mdl)

			if SERVER then
				self.SelectedModelSkin = ent:GetSkin()
			else
				self:RefreshHUDHelp()

				if IsFirstTimePredicted() then
					self:AddGhostProp(ent)
					self:EmitSound("weapons/physcannon/physcannon_drop.wav", 75, 80, 0.25)
				end
			end
		end
	end
end

function SWEP:SecondaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)

	if GetRoundState() != ROUND_ACTIVE then return end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local mdl = self:GetSelectedModelPath()
	if not mdl or mdl == "" then return end

	self:SetNextSecondaryFire(CurTime() + self.Secondary.DelaySuccess)

	local disguised = self:GetDisguised()

	if SERVER then
		self:TogglePropState(not disguised)
	end
end

function SWEP:Deploy()
	self:SetDisguised(false)
	self:DrawShadow(false)

	if SERVER then
		-- Call this from the server in case Deploy isn't called properly on the client
		self:CallOnClient("RefreshHUDHelp")
	else
		self:RefreshHUDHelp()
	end

	return true
end

function SWEP:Holster()
	return not self:GetDisguised()
end

function SWEP:IsPropEligible(ent)
	if not IsValid(ent) or not self.EntityClassWhitelist[ent:GetClass()] then return false end

	if ent:GetModelRadius() > self.MaxPropSize then return false, "This prop is too big!" end

	return true
end

hook.Add("SetupMove", hookTag, function(pl, mv, cm)
	if not pl:IsTerror() then return end

	local wep = pl:GetActiveWeapon()

	if not IsValid(wep)
		or wep:GetClass() != className
		or not wep.GetDisguised
		or not wep:GetDisguised() then return end

	local p = wep:GetDisguisedProp()
	if not IsValid(p) then return end

	-- Prevent jumping (just in case), force ducking
	local buttons = bit.bor(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP)), IN_DUCK)

	mv:SetButtons(buttons)
	mv:SetVelocity(vector_origin)

	local center = p:WorldSpaceCenter()
	if CLIENT then
		-- The client wants a position local to the prop, otherwise the clientside player position goes apeshit and makes using traitor buttons while disguised impossible
		center = p:WorldToLocal(center)
	end

	mv:SetOrigin(center)

	if SERVER then
		local now = CurTime()
		local updateLastPos = true

		if now >= (p.PropDisguiserNextCheck or 0) then
			if p.PropDisguiserLastPos then
				p.PropDisguiserNextCheck = now + 0.08

				local phys = p:GetPhysicsObject()
				local velSqr = phys:GetVelocity():LengthSqr()

				if velSqr > 0 then
					local velLen = math.sqrt(velSqr)
					local score = ((center - p.PropDisguiserLastPos):Length() / math.max(velLen, 100)) * 2

					-- If score is below 1, continue checking for playerclips, otherwise assume we've teleported and don't check
					if score < 1 then
						local tr = utilTraceLine({
							start = p.PropDisguiserLastPos,
							endpos = center,
							mask = CONTENTS_PLAYERCLIP
						})

						if tr.Hit then
							updateLastPos = false

							p:ForcePlayerDrop()

							-- Being held by a magneto-stick which is unaffected by ForcePlayerDrop, find it and force it to drop
							if p:IsPlayerHolding() then
								local carryClass = "weapon_zm_carry"

								for k,v in ipairs(player.GetAll()) do
									local vWep = v:GetActiveWeapon()

									if IsValid(vWep) and vWep:GetClass() == carryClass and vWep:GetCarryTarget() == p then
										vWep:Reset(true)
										break
									end
								end
							end

							phys:SetPos(p.PropDisguiserLastPos + (p:GetPos() - center))
							phys:SetVelocityInstantaneous(tr.HitNormal * math.max(velLen, 250))
						end
					end
				end
			end

			if updateLastPos then
				p.PropDisguiserLastPos = center
			end
		end
	end
end)

if SERVER then
	local testMaxsSize = 0.3
	local trTab = {
		start = nil,
		endpos = nil,
		mins = nil,
		maxs = nil,
		mask = MASK_PLAYERSOLID,
		filter = nil
	}

	local function isPlStuck(pl, pos, hullMins, hullMaxs)
		trTab.start = pos
		trTab.endpos = pos
		trTab.mins = hullMins
		trTab.maxs = hullMaxs
		trTab.filter = pl

		local tr = utilTraceHull(trTab)

		return tr.StartSolid
	end

	local function findBestRestorePos(pl, pos)
		-- Before doing any of our epic checking, check if we're stuck in a playerclip first - just respawn us if we are
		local pointContents = util.PointContents(pos)
		if bit.band(pointContents, CONTENTS_PLAYERCLIP) != 0 then
			local spawnPoint = plyspawn.GetRandomSafePlayerSpawnPoint(pl)

			if spawnPoint then
				print("[Prop Disguiser]", pl, "tried undisguising inside a playerclip! Moved them to a spawnpoint for safety!")
				return spawnPoint.pos
			end

			print("[Prop Disguiser]", pl, "tried undisguising inside a playerclip and a suitable spawnpoint wasn't found somehow! They might be fucked!")
		end

		local newPos = pos * 1

		local hullMins, hullMaxs = pl:GetHullDuck()

		local checkHullMins, checkHullMaxs = hullMins * 1, hullMaxs * 1

		checkHullMins.z = 0
		checkHullMaxs.z = testMaxsSize

		trTab.start = pos
		trTab.endpos = pos - (vector_up * ((pl.PropDisguiserSavedOffsets and pl.PropDisguiserSavedOffsets.Full.z or 64) + 1))
		trTab.mins = checkHullMins
		trTab.maxs = checkHullMaxs
		trTab.filter = pl

		local tr = utilTraceHull(trTab)

		if tr.Hit then
			newPos = tr.HitPos + vector_up
		end

		if tr.StartSolid then
			-- Check we aren't still stuck after that

			checkHullMins.z = hullMins.z
			checkHullMaxs.z = hullMaxs.z

			if isPlStuck(pl, newPos, hullMins, hullMaxs) then
				-- We are stuck... try pushing our position away from any nearby walls in each direction

				-- Reuse this vector object
				local testVec = Vector()

				local testDirs = {
					{hullMins.x, 0},
					{hullMaxs.x, 0},
					{0, hullMins.y},
					{0, hullMaxs.y}
				}

				for i = 1, #testDirs do
					local dir = testDirs[i]

					testVec.x = dir[1]
					testVec.y = dir[2]

					if testVec.x > 0 then
						checkHullMins.x = -testMaxsSize
						checkHullMaxs.x = 0
					elseif testVec.x < 0 then
						checkHullMins.x = 0
						checkHullMaxs.x = testMaxsSize
					else
						checkHullMins.x = hullMins.x
						checkHullMaxs.x = hullMaxs.x
					end

					if testVec.y > 0 then
						checkHullMins.y = -testMaxsSize
						checkHullMaxs.y = 0
					elseif testVec.y < 0 then
						checkHullMins.y = 0
						checkHullMaxs.y = testMaxsSize
					else
						checkHullMins.y = hullMins.y
						checkHullMaxs.y = hullMaxs.y
					end

					trTab.start = newPos
					trTab.endpos = newPos + testVec
					trTab.mins = checkHullMins
					trTab.maxs = checkHullMaxs
					trTab.filter = pl

					tr = utilTraceHull(trTab)

					if tr.Hit and not tr.AllSolid then
						local correction
						if tr.HitNormal != vector_origin then
							correction = tr.HitNormal * ((hullMaxs.x * (1 - tr.Fraction)) + 0.5)
						else
							correction = testVec
						end

						newPos = newPos + correction
					end

					if not isPlStuck(pl, newPos, hullMins, hullMaxs) then return newPos end
				end

				-- Pushing against walls hasn't worked, try finding two good directions and creeping towards them
				local maxTestRange = 64
				local desiredDirs = {}

				testDirs = {
					{1, 0},
					{-1, 0},
					{0, 1},
					{0, -1}
				}

				for i = 1, #testDirs do
					local dir = testDirs[i]

					testVec.x = dir[1] * maxTestRange
					testVec.y = dir[2] * maxTestRange

					trTab.start = newPos
					trTab.endpos = newPos + testVec

					tr = utilTraceLine(trTab)

					local len = maxTestRange * tr.Fraction
					len = len > hullMaxs.x and len or 0

					if len > 0 then
						desiredDirs[#desiredDirs + 1] = {Dir = dir, Len = len}
					end
				end

				if #desiredDirs > 0 then
					table.sort(desiredDirs, function(a, b) return a.Len > b.Len end)

					local dir1, dir2 = desiredDirs[1], desiredDirs[2]
					dir1, dir2 = dir1 and dir1.Dir, dir2 and dir2.Dir

					local dir1X, dir1Y, dir2X, dir2Y

					-- Lift the traces off the ground a bit, restore it after
					testVec.z = newPos.z + 8

					for i = 1, maxTestRange do
						dir1X, dir1Y = dir1[1] * i, dir1[2] * i

						testVec.x = newPos.x + dir1X
						testVec.y = newPos.y + dir1Y

						if not isPlStuck(pl, testVec, hullMins, hullMaxs) then
							testVec.z = newPos.z
							return testVec
						end

						if dir2 then
							dir2X, dir2Y = dir2[1] * i, dir2[2] * i

							testVec.x = newPos.x + dir2X
							testVec.y = newPos.y + dir2Y

							if not isPlStuck(pl, testVec, hullMins, hullMaxs) then
								testVec.z = newPos.z
								return testVec
							end

							if (dir1X - dir2X) != 0 and (dir1Y - dir2Y) != 0 then
								testVec.x = newPos.x + dir1X + dir2X
								testVec.y = newPos.y + dir1Y + dir2Y

								if not isPlStuck(pl, testVec, hullMins, hullMaxs) then
									testVec.z = newPos.z
									return testVec
								end
							end
						end
					end
				else
					-- We have no good directions, try lifting us upwards instead...

					testVec.x = newPos.x
					testVec.y = newPos.y

					for i = 1, maxTestRange do
						testVec.z = newPos.z + i

						if not isPlStuck(pl, testVec, hullMins, hullMaxs) then return testVec end
					end
				end
			end
		end

		return newPos
	end

	function SWEP:Equip()
		self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
		self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)

		self.AllowDropOriginal = self.AllowDropOriginal or self.AllowDrop
	end

	function SWEP:PreDrop()
		self:DrawShadow(true)

		if not self:GetDisguised() then return end

		self:TogglePropState(false)
	end

	SWEP.OnRemove = SWEP.PreDrop

	function SWEP:Think()
		if not self:GetDisguised() then return end

		local pl = self:GetOwner()
		if not IsValid(pl) then return end

		-- This is the only suitable place where SetGroundEntity actually affects the magneto-stick's anti-pickup
		pl:SetGroundEntity(NULL)
	end

	function SWEP:TogglePropState(state, pl)
		pl = pl or self:GetOwner()
		if not IsValid(pl) then return end

		if state then
			if self:GetDisguised() then return end

			local mdl = self:GetSelectedModelPath()
			if not mdl or mdl == "" then return end

			local pos = pl:GetPos()
			local ang = pl:EyeAngles()

			local p = ents.Create("prop_physics")
			p:SetModel(mdl)
			p:SetPos(pos)
			p:SetAngles(Angle(0, ang.y, 0))
			p:SetSkin(self.SelectedModelSkin)
			p:Spawn()

			if not IsValid(p) then return end

			p:CallOnRemove(hookTag, function(ent, wep)
				if not IsValid(wep) then return end

				wep:TogglePropState(false)
			end, self)

			p.PropDisguiserOwner = pl

			pl.PropDisguiserProp = p
			pl.PropDisguiserColGroup = pl:GetCollisionGroup()

			-- Correct the position with its own OBBMins
			pos.z = pos.z - p:OBBMins().z
			p:SetPos(pos)

			local plVel = pl:GetVelocity()

			local phys = p:GetPhysicsObject()
			if IsValid(phys) then
				phys:Wake()
				phys:SetVelocity(plVel)
			end

			if pac and pac.TogglePartDrawing then
				pac.TogglePartDrawing(pl, false)
			end

			if IsValid(pl.hat) then
				pl.hat:Drop()
			end

			pl:SetVelocity(-plVel)

			pl:SetNoDraw(true)
			pl:DrawShadow(false)
			pl:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)

			pl.PropDisguiserSavedOffsets = {
				Full = pl:GetViewOffset(),
				Ducked = pl:GetViewOffsetDucked()
			}

			pl:SetViewOffset(vector_origin)
			pl:SetViewOffsetDucked(vector_origin)

			pl:SetParent(p)
			pl:SetLocalPos(vector_origin)
			pl:SetMoveType(MOVETYPE_NONE)

			p.PropDisguiserBreatheTimer = className .. pl:EntIndex()

			timer.Create(p.PropDisguiserBreatheTimer, convarBreatheDelay:GetFloat(), 1, function()
				if not IsValid(self) or not IsValid(p) then return end

				local filter = RecipientFilter()
				filter:AddAllPlayers()

				p.PropDisguiserBreatheSound = CreateSound(p, self.Secondary.SoundBreathe, filter)
				p.PropDisguiserBreatheSound:SetSoundLevel(68)
				p.PropDisguiserBreatheSound:PlayEx(0.2, math.random(92, 102))
			end)
		else
			pl:SetParent()

			local pos, vel

			if IsValid(pl.PropDisguiserProp) then
				pos = pl.PropDisguiserProp:GetPos()
				pos.z = pos.z + pl.PropDisguiserSavedOffsets.Ducked.z

				vel = pl.PropDisguiserProp:GetVelocity()

				if pl.PropDisguiserProp.PropDisguiserBreatheTimer then
					timer.Remove(pl.PropDisguiserProp.PropDisguiserBreatheTimer)
				end

				if pl.PropDisguiserProp.PropDisguiserBreatheSound then
					pl.PropDisguiserProp.PropDisguiserBreatheSound:Stop()
					pl.PropDisguiserProp.PropDisguiserBreatheSound = nil
				end

				pl.PropDisguiserProp:RemoveCallOnRemove(hookTag)
				pl.PropDisguiserProp:Remove()
			else
				pos = pl:EyePos()
			end

			pos = findBestRestorePos(pl, pos)

			pl:SetPos(pos)

			if pl.PropDisguiserSavedOffsets then
				pl:SetViewOffset(pl.PropDisguiserSavedOffsets.Full)
				pl:SetViewOffsetDucked(pl.PropDisguiserSavedOffsets.Ducked)

				pl:SetCurrentViewOffset(pl.PropDisguiserSavedOffsets.Ducked)
			end

			pl.PropDisguiserProp = nil
			pl.PropDisguiserZOffset = nil
			pl.PropDisguiserSavedOffsets = nil

			-- To pass the prop velocity over to corpses and whatever else
			pl.PropDisguiserVelocity = vel

			if pac and pac.TogglePartDrawing then
				pac.TogglePartDrawing(pl, true)
			end

			pl:SetNoDraw(false)
			pl:DrawShadow(true)

			timer.Simple(0, function()
				if not IsValid(pl) then return end

				pl:SetCollisionGroup(pl.PropDisguiserColGroup or COLLISION_GROUP_PLAYER)

				pl.PropDisguiserColGroup = nil
				pl.PropDisguiserVelocity = nil

				if pl:Alive() then
					pl:SetMoveType(MOVETYPE_WALK)
					pl:SetVelocity(-pl:GetVelocity() + (vel or vector_origin))

					if utilTraceLine({
						start = pos,
						endpos = pl:GetPos(),
						mask = MASK_PLAYERSOLID_BRUSHONLY,
						filter = pl
					}).HitWorld then
						-- Some absolute source engine DOGSHIT just happened where the player got teleported through the floor, bring them back
						pl:SetPos(pos)
					end
				end
			end)
		end

		if IsValid(self) then
			-- If statement to avoid confusion with falses and nils
			if state then
				self.AllowDrop = false
			else
				self.AllowDrop = self.AllowDropOriginal
			end

			self:SetDisguised(state)
			self:SetDisguisedProp(pl.PropDisguiserProp)
		end

		pl:EmitSound(state and self.Secondary.SoundOn or self.Secondary.SoundOff, 60, math.random(98, 102), 0.3)
	end

	hook.Add("EntityTakeDamage", hookTag, function(ent, dmg)
		if not IsValid(ent.PropDisguiserOwner) then return end

		local pl = ent.PropDisguiserOwner
		local beforeHp = ent:Health()

		-- Prop is breakable and is about to be broken, take the full
		if beforeHp > 0 and (beforeHp - dmg:GetDamage()) <= 0 then
			pl:TakeDamageInfo(dmg)
			return
		end

		-- The player already takes explosion damage even when disguised, don't apply more damage
		if dmg:GetDamageType() == DMG_BLAST then return end

		local orginalDmg = dmg:GetDamage()
		dmg:SetDamage(math.ceil(orginalDmg * 0.5))

		pl:TakeDamageInfo(dmg)

		-- Set it back to normal for the prop
		dmg:SetDamage(orginalDmg)
	end)

	local function denyIfDisguised(pl)
		if IsValid(pl.PropDisguiserProp) then return false end
	end

	-- Don't let disguised people use stuff (traitor buttons are handled differently so they are still useable)
	hook.Add("PlayerUse", hookTag, denyIfDisguised)

	-- Don't let disguised people pick up guns
	hook.Add("PlayerCanPickupWeapon", hookTag, denyIfDisguised)

	-- Don't let disguised people pick up items like ammo
	hook.Add("PlayerCanPickupItem", hookTag, denyIfDisguised)

	-- We need to force people out of disguises before the next round starts, otherwise people don't respawn properly
	hook.Add("TTTEndRound", hookTag, function()
		for k,v in ipairs(player.GetAll()) do
			if not v:IsTerror() then continue end

			local p = v.PropDisguiserProp
			if not IsValid(p) then continue end

			-- Removing the prop is sufficent enough, it will handle undisguising the player
			p:Remove()
		end
	end)

	-- If a player dies while disguised, pass the prop velocity to their corpse
	hook.Add("TTT2ModifyRagdollVelocity", hookTag, function(pl, rag, vel)
		if pl.PropDisguiserVelocity then return pl.PropDisguiserVelocity end
	end)
else
	local LocalPlayer = LocalPlayer
	local Lerp = Lerp
	local FrameTime = FrameTime

	local textCopyProp = "Copy prop"
	local textCopyPropBad = "Can't copy prop"
	local textCopyPropPrompt = "Press [LMB] to copy this prop for disguising."
	local textBecomeProp = "Disguise as: "
	local textUnbecomeProp = "Undisguise"
	local textFirstPerson = "[Hold] First-person"
	local textBreakableWarning = "Careful, this prop is breakable!"

	local handBoneName = "ValveBiped.Bip01_R_Hand"
	local materialKeyLMB = Material("vgui/ttt/hudhelp/lmb")
	local warningColor, disallowedColor = Color(250, 175, 0), Color(255, 80, 0)

	local minViewRadius, extraViewRadius, viewTraceLen = 32, 32, 16

	local function renderOverride(ent)
		local pl = LocalPlayer()

		local lerp = pl.PropDisguiseViewLerp

		if lerp > 0.95 or lerp < 0.01 then
			lerp = pl.PropDisguiseViewIntentScale
		end

		if lerp > 0 then
			render.SetBlend(lerp)
			ent:DrawModel()
			render.SetBlend(1)
		end
	end

	SWEP.GhostProps = {}

	function SWEP:CalcView(pl, pos, ang, fov)
		if not self:GetDisguised() then return end

		local p = self:GetDisguisedProp()
		if not IsValid(p) then return end
		if p.RenderOverride != renderOverride then
			p:SetRenderMode(RENDERMODE_TRANSCOLOR)
			p.RenderOverride = renderOverride
		end

		ang = pl:EyeAngles()

		pl.PropDisguiseViewIntentScale = pl:KeyDown(IN_WALK) and 0 or 1
		pl.PropDisguiseViewLerp = Lerp(10 * FrameTime(), pl.PropDisguiseViewLerp or 1, pl.PropDisguiseViewIntentScale)

		local radius = math.max(p:GetModelRadius() or minViewRadius, minViewRadius) + extraViewRadius + viewTraceLen
		local basePos = p:WorldSpaceCenter()
		local angForward = ang:Forward()

		local traceVec = angForward * -radius

		local tr = utilTraceLine({
			start = basePos,
			endpos = basePos + traceVec,
			mask = MASK_SOLID_BRUSHONLY
		})

		return
			basePos + ((traceVec * tr.Fraction) + (angForward * viewTraceLen)) * pl.PropDisguiseViewLerp,
			ang,
			fov
	end

	function SWEP:ShouldDrawViewModel()
		return not self:GetDisguised()
	end

	function SWEP:DrawWorldModel(flags)
		local owner = self:GetOwner()

		if IsValid(owner) then return end

		self:DrawModel(flags)
	end

	function SWEP:AddGhostProp(ent)
		local now = RealTime()
		local model = ClientsideModel(ent:GetModel())

		model:SetNoDraw(true)
		model:SetSkin(ent:GetSkin())

		local entAng = ent:GetAngles()
		local eyeYaw = EyeAngles().y

		local angDiff = entAng.y - eyeYaw

		-- Correct yaw for overspinning
		if angDiff > 180 then
			eyeYaw = eyeYaw + 360
		elseif angDiff < -180 then
			eyeYaw = eyeYaw - 360
		end

		self.GhostProps[#self.GhostProps + 1] = {
			Model = model,
			StartPos = ent:GetPos(),
			StartAng = entAng,
			EndAng = Angle(0, eyeYaw, 0),
			StartTime = now,
			EndTime = now + 0.75
		}
	end

	function SWEP:RefreshHUDHelp()
		if self:GetDisguised() then
			self:AddTTT2HUDHelp(nil, textUnbecomeProp)
			self:AddHUDHelpLine(textFirstPerson, Key("+walk", "WALK"))
		else
			local mdl = self:GetSelectedModelPath()

			if mdl and mdl != "" then
				self:AddTTT2HUDHelp(textCopyProp, textBecomeProp .. self:GetModelName(mdl))
			else
				self:AddTTT2HUDHelp(textCopyProp)
			end
		end
	end

	function SWEP:GetModelName(modelPath)
		if not modelPath then return end
		return string.gsub(modelPath, "^models/.+/", "")
	end

	function SWEP:AddToSettingsMenu(parent)
		local form = vgui.CreateTTT2Form(parent, "header_equipment_additional")

		form:MakeSlider({
			serverConvar = convarBreatheDelayName,
			label = "Secs before disguised players make breathing sounds",
			min = 0,
			max = 180,
			decimal = 0
		})
	end

	hook.Add("PostDrawTranslucentRenderables", hookTag, function(depth, skybox)
		if skybox then return end

		local pl = LocalPlayer()

		if not IsValid(pl) or not pl:IsTerror() then return end

		local wep = pl:GetActiveWeapon()

		if not IsValid(wep)
			or wep:GetClass() != className
			or not wep.GetDisguised
			or wep:GetDisguised() then return end

		local now = RealTime()

		for k,v in next,wep.GhostProps do
			if not IsValid(v.Model) then
				wep.GhostProps[k] = nil
				continue
			elseif now > v.EndTime then
				v.Model:Remove()
				wep.GhostProps[k] = nil
				continue
			end

			local duration = v.EndTime - v.StartTime
			local progress = math.ease.InSine((now - v.StartTime) / duration)

			local eyeAng = pl:EyeAngles()
			local destPos = pl:EyePos() + (eyeAng:Up() * -36)

			destPos = destPos + (v.Model:WorldSpaceCenter() - v.Model:GetPos())

			local pos = v.StartPos + ((destPos - v.StartPos) * progress)
			local ang = v.StartAng + ((v.EndAng - v.StartAng) * progress)

			v.Model:SetPos(pos)
			v.Model:SetAngles(ang)

			render.SetBlend(1 - progress)
			v.Model:DrawModel()
			render.SetBlend(1)
		end
	end)

	hook.Add("TTT2ModifyOverheadIcon", hookTag, function(pl, default)
		if not default then return end

		local wep = pl:GetActiveWeapon()

		if IsValid(wep)
			and wep:GetClass() == className
			and wep.GetDisguised
			and wep:GetDisguised() then return false end
	end)

	hook.Add("TTTRenderEntityInfo", hookTag, function(tData)
		local pl = LocalPlayer()

		if not IsValid(pl) or not pl:IsTerror() then return end

		local wep = pl:GetActiveWeapon()

		if not IsValid(wep)
			or wep:GetClass() != className
			or not wep.GetDisguised
			or wep:GetDisguised()
			or tData:GetEntityDistance() > wep.Primary.Range then return end

		local ent = tData:GetEntity()

		local allowed, disallowReason = wep:IsPropEligible(ent)
		if not allowed and not disallowReason then return end

		local roleColor = pl:GetRoleColor()

		-- Enable TargetID rendering
		tData:EnableText()
		tData:EnableOutline()
		tData:SetOutlineColor(roleColor)

		if allowed then
			tData:AddIcon(materialKeyLMB)

			tData:SetTitle(textCopyProp)
			tData:SetSubtitle(textCopyPropPrompt)

			tData:AddDescriptionLine(wep:GetModelName(ent:GetModel()))

			if ent:Health() > 0 then
				tData:AddDescriptionLine(textBreakableWarning, warningColor)
			end
		else
			tData:SetTitle(textCopyPropBad)
			tData:AddDescriptionLine(disallowReason, disallowedColor)
		end
	end)
end