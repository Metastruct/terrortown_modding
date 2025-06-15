-- Code cloned from the TTT2, some changes applied to make it feel better to use:
--		* Players now only need to press once, toggling a healing area for themselves
--		* HUD text changes

if SERVER then
	AddCSLuaFile()
end

DEFINE_BASECLASS("ttt_base_placeable")

if CLIENT then
	ENT.Icon = "vgui/ttt/icon_health"
	ENT.PrintName = "hstation_name"
end

ENT.Base = "ttt_base_placeable"
ENT.Model = "models/props/cs_office/microwave.mdl"

ENT.CanHavePrints = true
ENT.MaxHeal = 25
ENT.MaxStored = 200

ENT.NextCharge = 0
ENT.RechargeRate = 1
ENT.RechargeFreq = 2 -- in seconds

ENT.NextHeal = 0
ENT.HealRate = 1
ENT.HealFreq = 0.15
ENT.HealingList = {}

ENT.MaxUseDist = 100
ENT.NextUseList = {}

---
-- @realm shared
function ENT:SetupDataTables()
	BaseClass.SetupDataTables(self)

	self:NetworkVar("Int", 0, "StoredHealth")
end

---
-- @realm shared
function ENT:Initialize()
	self:SetModel(self.Model)

	BaseClass.Initialize(self)

	local b = 32

	self:SetCollisionBounds(Vector(-b, -b, -b), Vector(b, b, b))

	if SERVER then
		self:SetMaxHealth(200)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(200)
		end
	end

	self:SetHealth(200)
	self:SetColor(Color(180, 180, 250, 255))
	self:SetStoredHealth(200)

	self.NextHeal = 0
	self.fingerprints = {}
end

---
-- @param number amount
-- @realm shared
function ENT:AddToStorage(amount)
	self:SetStoredHealth(math.min(self.MaxStored, self:GetStoredHealth() + amount))
end

---
-- @param number amount
-- @return number
-- @realm shared
function ENT:TakeFromStorage(amount)
	-- if we only have 5 healthpts in store, that is the amount we heal
	amount = math.min(amount, self:GetStoredHealth())

	self:SetStoredHealth(math.max(0, self:GetStoredHealth() - amount))

	return amount
end

if SERVER then
	local soundHealStart = "items/medshot4.wav"
	local soundHealing = "items/medcharge4.wav"
	local soundFail = "items/medshotno1.wav"

	local healFadeColor = Color(100, 180, 255, 12)

	---
	-- This hook that is called on the use of this entity, but only if the player
	-- can be healed.
	-- @param Player ply The player that is healed
	-- @param Entity ent The healthstation entity that is used
	-- @param number healed The amount of health receivde in this tick
	-- @return boolean Return false to cancel the heal tick
	-- @hook
	-- @realm server
	function GAMEMODE:TTTPlayerUsedHealthStation(ply, ent, healed) end

	function ENT:GiveHealth(ply, healthMax)
		if self:GetStoredHealth() > 0 then
			healthMax = healthMax or self.MaxHeal

			local dmg = ply:GetMaxHealth() - ply:Health()
			if dmg > 0 then
				-- constant clamping, no risks
				local healed = self:TakeFromStorage(math.min(healthMax, dmg))
				local new = math.min(ply:GetMaxHealth(), ply:Health() + healed)

				if hook.Run("TTTPlayerUsedHealthStation", ply, self, healed) == false then
					return false
				end

				ply:SetHealth(new)
				ply:ScreenFade(SCREENFADE.IN, healFadeColor, 1, 0.05)

				if not table.HasValue(self.fingerprints, ply) then
					self.fingerprints[#self.fingerprints + 1] = ply
				end

				return true
			end
		end

		return false
	end

	local trTable

	function ENT:PlayerIsLookingAt(ply)
		if not trTable then
			trTable = {
				mask = MASK_SOLID
			}
		end

		trTable.start = ply:EyePos()
		trTable.endpos = trTable.start + (ply:GetAimVector() * self.MaxUseDist)
		trTable.filter = ply

		local tr = util.TraceLine(trTable)

		return tr.Entity == self
	end

	function ENT:Think()
		local t = CurTime()

		if self.NextCharge <= t then
			self:AddToStorage(self.RechargeRate)

			self.NextCharge = t + self.RechargeFreq
		end

		if self.NextHeal <= t then
			local pos = self:GetPos()

			local toRemove = {}

			local trTable

			for v in pairs(self.HealingList) do
				local isValid = IsValid(v)

				if isValid
					and v:IsPlayer()
					and v:KeyDown(IN_USE)   -- Is the player still holding E?
					and v:IsActive()	-- Is the round active?
				then
					-- Is the player still looking at the station?
					if self:PlayerIsLookingAt(v) then
						if self:GiveHealth(v, self.HealRate)	-- Attempt to heal them, returns true if it succeeded
							or v:Health() < v:GetMaxHealth()	-- Do they still need healing?
						then
							-- All passed, keep them in the list
							continue
						else
							v:EmitSound(soundFail)
						end
					end
				end

				-- If we reached this point, this player shouldn't be healed anymore, take them out the list
				toRemove[#toRemove + 1] = v

				if isValid then
					v:StopSound(soundHealing)
				end
			end

			for k, v in ipairs(toRemove) do
				self.HealingList[v] = nil
			end

			self.NextHeal = t + self.HealFreq
		end
	end

	---
	-- @param Player ply
	-- @realm server
	function ENT:Use(ply)
		if not IsValid(ply) or not ply:IsPlayer() or not ply:IsActive() then
			return
		end

		local nextUse = self.NextUseList[ply]
		if nextUse and nextUse > CurTime() then
			return
		end

		self.NextUseList[ply] = CurTime() + 0.25

		if not self:PlayerIsLookingAt(ply) then
			return
		end

		if ply:Health() >= ply:GetMaxHealth() then
			ply:EmitSound(soundFail, 70, 100, 0.3)
			return
		end

		if not self.HealingList[ply] then
			self.HealingList[ply] = true

			ply:EmitSound(soundHealStart)
			ply:EmitSound(soundHealing, 70, 100, 0.3)
		end
	end

	function ENT:OnRemove()
		for v in pairs(self.HealingList) do
			if IsValid(v) then
				v:StopSound(soundHealing)
			end
		end
	end

	---
	-- @realm server
	function ENT:WasDestroyed()
		local originator = self:GetOriginator()

		if not IsValid(originator) then
			return
		end

		LANG.Msg(originator, "hstation_broken", nil, MSG_MSTACK_WARN)
	end
else
	local TryT = LANG.TryTranslation
	local ParT = LANG.GetParamTranslation

	local key_params = {
		usekey = Key("+use", "USE"),
		walkkey = Key("+walk", "WALK"),
	}

	---
	-- Hook that is called if a player uses their use key while focusing on the entity.
	-- Early check if client can use the health station
	-- @return bool True to prevent pickup
	-- @realm client
	function ENT:ClientUse()
		local client = LocalPlayer()

		if not IsValid(client) or not client:IsPlayer() or not client:IsActive() then
			return true
		end
	end

	-- handle looking at healthstation
	hook.Add("TTTRenderEntityInfo", "HUDDrawTargetIDHealthStation", function(tData)
		local client = LocalPlayer()
		local ent = tData:GetEntity()

		if
			not IsValid(client)
			or not client:IsTerror()
			or not client:Alive()
			or not IsValid(ent)
			or ent:GetClass() ~= "ttt_health_station"
			or tData:GetEntityDistance() > (ent.MaxUseDist or 100)
		then
			return
		end

		-- enable targetID rendering
		tData:EnableText()
		tData:EnableOutline()
		tData:SetOutlineColor(client:GetRoleColor())

		tData:SetTitle(TryT(ent.PrintName))
		tData:SetSubtitle(ParT("hstation_subtitle", key_params))
		tData:SetKeyBinding("+use")

		local hstation_charge = ent:GetStoredHealth() or 0

		tData:AddDescriptionLine("When activated, the station will heal you while you stay near.")
		tData:AddDescriptionLine("Slowly recharges over time.")

		tData:AddDescriptionLine(
			(hstation_charge > 0) and ParT("hstation_charge", { charge = hstation_charge })
				or TryT("hstation_empty"),
			(hstation_charge > 0) and roles.DETECTIVE.ltcolor or COLOR_ORANGE
		)

		if client:Health() < client:GetMaxHealth() then
			return
		end

		tData:AddDescriptionLine(TryT("hstation_maxhealth"), COLOR_ORANGE)
	end)
end
