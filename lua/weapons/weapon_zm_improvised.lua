local cvCrowbarDelayName = "ttt2_crowbar_shove_delay"
local cvCrowbarUnlocks, cvCrowbarPushForce, cvCrowbarDelay

local nwFistStanceName, netFistStanceName = "TTTFistsHoldtype", "TTTFistsAttackGesture"

if SERVER then
	AddCSLuaFile()

	resource.AddFile("models/weapons/c_punch.mdl")

	---
	-- @realm server
	cvCrowbarDelay = CreateConVar(cvCrowbarDelayName, "1.0", { FCVAR_ARCHIVE, FCVAR_NOTIFY })

	---
	-- @realm server
	cvCrowbarUnlocks = CreateConVar("ttt_crowbar_unlocks", "1", { FCVAR_ARCHIVE, FCVAR_NOTIFY })

	---
	-- @realm server
	cvCrowbarPushForce = CreateConVar("ttt_crowbar_pushforce", "395", { FCVAR_ARCHIVE, FCVAR_NOTIFY })
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.HoldType = "slam"

if CLIENT then
	SWEP.PrintName = "Fists"
	SWEP.Slot = 0

	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 66

	SWEP.Icon = "vgui/ttt/icon_cbar"
end

SWEP.notBuyable = true

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_punch.mdl"
SWEP.WorldModel = "models/weapons/w_bugbait.mdl"
SWEP.ShowDefaultWorldModel = false
SWEP.idleResetFix = true

SWEP.Primary.Damage = 20
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Delay = 0.5
SWEP.Primary.Ammo = "none"
SWEP.Primary.SoundSwing = ")weapons/iceaxe/iceaxe_swing1.wav"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 5

SWEP.Kind = WEAPON_MELEE
SWEP.WeaponID = AMMO_CROWBAR
SWEP.builtin = true

SWEP.NoSights = true
SWEP.IsSilent = true

SWEP.DeploySpeed = 1.8

SWEP.Weight = 5
SWEP.AutoSpawnable = false

SWEP.AllowDelete = false -- never removed for weapon reduction
SWEP.AllowDrop = false
SWEP.overrideDropOnDeath = DROP_ON_DEATH_TYPE_DENY

-- only open things that have a name (and are therefore likely to be meant to
-- open) and are the right class. Opening behaviour also differs per class, so
-- return one of the OPEN_ values
local pmnc_tbl = {
	prop_door_rotating = OPEN_ROT,
	func_door = OPEN_DOOR,
	func_door_rotating = OPEN_DOOR,
	func_button = OPEN_BUT,
	func_movelinear = OPEN_NOTOGGLE,
}

local function OpenableEnt(ent)
	return ent:GetName() ~= "" and pmnc_tbl[ent:GetClass()] or OPEN_NO
end

local function CrowbarCanUnlock(t)
	return not GAMEMODE.crowbar_unlocks or GAMEMODE.crowbar_unlocks[t]
end

local function PlayPunchGesture(pl, hard)
	pl:AnimRestartGesture(GESTURE_SLOT_VCD, hard and ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE or ACT_HL2MP_GESTURE_RANGE_ATTACK_FIST, true)
	pl:AnimRestartGesture(GESTURE_SLOT_FLINCH, ACT_FLINCH_STOMACH, true)

	if SERVER then
		net.Start(netFistStanceName)
		net.WritePlayer(pl)
		net.WriteBool(hard)
		net.SendOmit(pl)
	end
end

local DoCorpseEffects = SERVER and function(rag)
	local data = rag.FistsCorpseData
	if not data then return end

	if data.HitHard then
		rag:EmitSound("ambient/explosions/explode_9.wav", 70, 125)
	end

	if data.PhysBoneId then
		local phys = rag:GetPhysicsObjectNum(data.PhysBoneId)

		if IsValid(phys) then
			phys:ApplyForceOffset(data.PointImpulse, data.HitPos or phys:GetPos())
			print("applied force offset", rag, data.PointImpulse, data.HitPos)
		end
	end
end or nil

function SWEP:Initialize()
	if not cvCrowbarDelay then
		cvCrowbarDelay = GetConVar(cvCrowbarDelayName)
	end

	self.Secondary.Delay = cvCrowbarDelay:GetFloat()

	return BaseClass.Initialize(self)
end

---
-- Will open door AND return what it did
-- @param Entity hitEnt
-- @return number Entity types a crowbar might open
-- @realm shared
function SWEP:OpenEnt(hitEnt)
	-- Get ready for some prototype-quality code, all ye who read this
	if SERVER and cvCrowbarUnlocks:GetBool() then
		local openable = OpenableEnt(hitEnt)

		if openable == OPEN_DOOR or openable == OPEN_ROT then
			local unlock = CrowbarCanUnlock(openable)
			if unlock then
				hitEnt:Fire("Unlock", nil, 0)
			end

			if unlock or hitEnt:HasSpawnFlags(256) then -- SF_DOOR_PUSE
				if openable == OPEN_ROT then
					hitEnt:Fire("OpenAwayFrom", self:GetOwner(), 0)
				end

				hitEnt:Fire("Toggle", nil, 0)
			else
				return OPEN_NO
			end
		elseif openable == OPEN_BUT then
			if CrowbarCanUnlock(openable) then
				hitEnt:Fire("Unlock", nil, 0)
				hitEnt:Fire("Press", nil, 0)
			else
				return OPEN_NO
			end
		elseif openable == OPEN_NOTOGGLE then
			if CrowbarCanUnlock(openable) then
				hitEnt:Fire("Open", nil, 0)
			else
				return OPEN_NO
			end
		end

		return openable
	else
		return OPEN_NO
	end
end

---
-- @ignore
function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

	local owner = self:GetOwner()
	if not IsValid(owner) then
		return
	end

	local willHitHard = owner:KeyDown(IN_RELOAD)
	if willHitHard then
		self:SetNextPrimaryFire(CurTime() + self.Primary.Delay + 0.5)
	end

	if isfunction(owner.LagCompensation) then -- for some reason not always true
		owner:LagCompensation(true)
	end

	local spos = owner:GetShootPos()
	local sdest = spos + owner:GetAimVector() * 100

	local tr_main = util.TraceLine({
		start = spos,
		endpos = sdest,
		filter = owner,
		mask = MASK_SHOT_HULL
	})

	local hitEnt = tr_main.Entity

	self:SendWeaponAnim(willHitHard and ACT_VM_SWINGMISS or ACT_VM_PRIMARYATTACK)
	PlayPunchGesture(owner, willHitHard)

	if IsValid(hitEnt) or tr_main.HitWorld then
		local hitFlesh = tr_main.MatType == MAT_FLESH or tr_main.MatType == MAT_BLOODYFLESH

		self:EmitSound(string.format("physics/body/body_medium_impact_hard%s.wav", math.random(5, 6)), 70, math.random(95, 100), hitFlesh and 0.8 or 0.4)

		if SERVER or IsFirstTimePredicted() then
			local efName = hitFlesh and "Impact" or "Impact_GMOD"
            local ef = EffectData()

            ef:SetStart(spos)
            ef:SetOrigin(tr_main.HitPos)
            ef:SetNormal(tr_main.Normal)
            ef:SetSurfaceProp(tr_main.SurfaceProps)
            ef:SetHitBox(tr_main.HitBox)
            ef:SetEntity(hitEnt)

			if not hitFlesh then
				ef:SetFlags(1) -- IMPACT_NODECAL
			end

			util.Effect(efName, ef)
		end
	else
		self:EmitSound(self.Primary.SoundSwing, 70, math.random(95, 100), 0.5)
	end

	if SERVER then
		-- Do another trace that sees nodraw stuff like func_button
		local tr_all = util.TraceLine({
			start = spos,
			endpos = sdest,
			filter = owner,
		})

		local trEnt = tr_all.Entity

		if IsValid(hitEnt) then
			if hitEnt:IsPlayer() then
				hitEnt.FistsCorpseData = {
					HitHard = willHitHard,
					Velocity = tr_main.Normal * (willHitHard and 250 or 50),
					PointImpulse = tr_main.Normal * (willHitHard and 30000 or 10000),
					PhysBoneId = tr_main.PhysicsBone,
					HitPos = tr_main.HitPos
				}

				-- Use this wacky utility var that TTT2 runs as a function straight after setting corpse velocity
				hitEnt.effect_fn = DoCorpseEffects

				timer.Simple(0, function()
					if IsValid(hitEnt) then
						hitEnt.FistsCorpseData = nil

						if hitEnt.effect_fn == DoCorpseEffects then
							hitEnt.effect_fn = nil
						end
					end
				end)
			end

			if self:OpenEnt(hitEnt) == OPEN_NO and IsValid(trEnt) then
				self:OpenEnt(trEnt) -- See if there's a nodraw thing we should open
			end

			local dmg = DamageInfo()
			dmg:SetDamage(self.Primary.Damage)
			dmg:SetAttacker(owner)
			dmg:SetInflictor(self)
			dmg:SetDamageForce(owner:GetAimVector() * 1500)
			dmg:SetDamagePosition(owner:GetPos())
			dmg:SetDamageType(DMG_CLUB)

			hitEnt:DispatchTraceAttack(dmg, spos + owner:GetAimVector() * 3, sdest)
		elseif IsValid(trEnt) then -- See if our nodraw trace got the goods
			self:OpenEnt(trEnt)
		end
	end

	if isfunction(owner.LagCompensation) then
		owner:LagCompensation(false)
	end
end

---
-- @ignore
function SWEP:SecondaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self:SetNextSecondaryFire(CurTime() + 0.1)

	local owner = self:GetOwner()
	if not IsValid(owner) then
		return
	end

	if isfunction(owner.LagCompensation) then
		owner:LagCompensation(true)
	end

	local tr = owner:GetEyeTrace(MASK_SHOT)
	local ply = tr.Entity

	if
		tr.Hit
		and IsValid(ply)
		and ply:IsPlayer()
		and (owner:EyePos() - tr.HitPos):LengthSqr() < 10000 -- 100hu
	then
		---
		-- @realm shared
		if SERVER and not ply:IsFrozen() and not hook.Run("TTT2PlayerPreventPush", owner, ply) then
			local pushvel = tr.Normal * cvCrowbarPushForce:GetFloat()
			pushvel.z = math.Clamp(pushvel.z, 50, 100) -- limit the upward force to prevent launching

			ply:SetVelocity(ply:GetVelocity() + pushvel)

			ply.was_pushed = {
				att = owner,
				t = CurTime(),
				wep = self:GetClass(),
				-- infl = self
			}
		end

		self:EmitSound(string.format("physics/flesh/flesh_impact_hard%s.wav", math.random(2, 3)), 66, math.random(80, 85), 0.5)
		self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
		owner:SetAnimation(PLAYER_ATTACK1)

		self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)
	end

	if isfunction(owner.LagCompensation) then
		owner:LagCompensation(false)
	end
end

function SWEP:Deploy()
	local owner = self:GetOwner()
	if not IsValid(owner) then return true end

	owner:SetNWBool(nwFistStanceName, true)

	return true
end

function SWEP:Holster()
	if SERVER or IsFirstTimePredicted() then
		local owner = self:GetOwner()
		if not IsValid(owner) then return true end

		owner:SetNWBool(nwFistStanceName, false)
	end

	return true
end

function SWEP:OnRemove()
	BaseClass.OnRemove(self)

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	owner:SetNWBool(nwFistStanceName, false)
end

local blendTime, stanceWeight = 0.3, 0.66

hook.Add("Think", "TTT2FistsHoldType", function()
	local now = CurTime()

	for k, v in player.Iterator() do
		-- Reset their fistStance var if they have left PVS, so the stance can be reapplied when they enter PVS again
		if CLIENT and v:IsDormant() then
			v._fistStance = false
			continue
		end

		local isStance = v:GetNWBool(nwFistStanceName)

		if isStance != v._fistStance then
			if isStance then
				v:AnimRestartGesture(GESTURE_SLOT_GRENADE, ACT_HL2MP_FIST_BLOCK)
				v:AnimSetGestureWeight(GESTURE_SLOT_GRENADE, 0)
			end

			local currentProg = v._fistBlendEnd and math.min(1 - ((v._fistBlendEnd - now) / blendTime), 1) or 1

			v._fistBlendEnd = (now - (blendTime * (1 - currentProg))) + blendTime
			v._fistStance = isStance
		end

		if v._fistBlendEnd then
			local prog = 1 - ((v._fistBlendEnd - now) / blendTime)

			if prog > 1 then
				if not isStance then
					v:AnimSetGestureWeight(GESTURE_SLOT_GRENADE, 1)
					v:AnimResetGestureSlot(GESTURE_SLOT_GRENADE)
				end

				v._fistBlendEnd = nil
			else
				prog = math.min(prog, 1)

				if not isStance then
					prog = 1 - prog
				end

				v:AnimSetGestureWeight(GESTURE_SLOT_GRENADE, math.ease.InOutSine(prog) * stanceWeight)
			end
		end
	end
end)

if SERVER then
	---
	-- A cancelable hook that is called if a player tries to push another player.
	-- @param Player ply The player that tries to push
	-- @param Player pushPly The player that is about to be pushed
	-- @return boolean Return true to cancel the push
	-- @hook
	-- @realm server
	function GAMEMODE:TTT2PlayerPreventPush(ply, pushPly) end

	-- Ensure the fist stance isn't stuck when dropped in any way
	function SWEP:OwnerChanged()
		local owner = self.LastOwner

		if IsValid(owner) then
			owner:SetNWBool(nwFistStanceName, false)
		end

		self.LastOwner = self:GetOwner()
	end

	util.AddNetworkString(netFistStanceName)

	hook.Add("TTT2ModifyRagdollVelocity", "TTT2FistsVelocity", function(pl, rag, vel)
		local data = pl.FistsCorpseData

		if data and data.Velocity then
			vel:Add(data.Velocity)

			-- Pass this to the ragdoll so it can be used in pl.effect_fn (DoCorpseEffects)
			rag.FistsCorpseData = data
		end
	end)
else
	---
	-- @ignore
	function SWEP:Initialize()
		self:AddTTT2HUDHelp("crowbar_help_primary", "crowbar_help_secondary")

		return BaseClass.Initialize(self)
	end

	---
	-- @ignore
	function SWEP:AddToSettingsMenu(parent)
		local form = vgui.CreateTTT2Form(parent, "header_equipment_additional")

		form:MakeCheckBox({
			serverConvar = "ttt_crowbar_unlocks",
			label = "label_crowbar_unlocks",
		})

		form:MakeSlider({
			serverConvar = "ttt_crowbar_pushforce",
			label = "label_crowbar_pushforce",
			min = 0,
			max = 750,
			decimal = 0,
		})

		form:MakeSlider({
			serverConvar = "ttt2_crowbar_shove_delay",
			label = "label_crowbar_shove_delay",
			min = 0,
			max = 10,
			decimal = 1,
		})
	end

	-- Yes we need a netmessage to do this because player gestures aren't networked automatically!!
	net.Receive(netFistStanceName, function()
		local pl = net.ReadPlayer()
		if not IsValid(pl) then return end

		local willHitHard = net.ReadBool()

		PlayPunchGesture(pl, willHitHard)
	end)

	-- Ensure fists stance persists after a full update happens
	gameevent.Listen("OnRequestFullUpdate")
	hook.Add("OnRequestFullUpdate", "TTT2FistsHoldType", function(data)
		timer.Simple(0, function()
			for k, v in player.Iterator() do
				local isStance = v:GetNWBool(nwFistStanceName)

				if isStance then
					v:AnimRestartGesture(GESTURE_SLOT_GRENADE, ACT_HL2MP_FIST_BLOCK)
					v:AnimSetGestureWeight(GESTURE_SLOT_GRENADE, stanceWeight)
				end
			end
		end)
	end)
end