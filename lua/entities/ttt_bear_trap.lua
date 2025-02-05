local markerVisionId = "beartrap_marker"
local trappedNwVar = "BeartrapPlayerTrapped"

if SERVER then
	AddCSLuaFile()

	resource.AddFile("models/stiffy360/beartrap.mdl")
	resource.AddFile("models/stiffy360/c_beartrap.mdl")
	resource.AddSingleFile("materials/models/freeman/beartrap_diffuse.vtf")
	resource.AddSingleFile("materials/models/freeman/beartrap_specular.vtf")
	resource.AddSingleFile("materials/models/freeman/trap_dif.vmt")
	resource.AddSingleFile("materials/vgui/ttt/hud_icon_beartrap.vmt")
	resource.AddSingleFile("materials/vgui/ttt/icon_beartrap.vmt")
	resource.AddSingleFile("sound/weapons/beartrap.ogg")
end

ENT.Type = "anim"
ENT.Author = "Loures (original code) + TW1STaL1CKY (fixes & changes)"

ENT.AutomaticFrameAdvance = true

function ENT:Think()
	self:NextThink(CurTime())
	return true
end

hook.Add("StartCommand", "ttt_beartrap_antimove", function(pl, cm)
	if not pl:GetNWBool(trappedNwVar) then return end

	cm:SetForwardMove(0)
	cm:SetSideMove(0)
	cm:SetUpMove(0)

	cm:SetButtons(bit.band(cm:GetButtons(), bit.bnot(IN_ATTACK), bit.bnot(IN_ATTACK2), bit.bnot(IN_RELOAD)))
end)

hook.Add("SetupMove", "ttt_beartrap_antimove", function(pl, mv, cm)
	if not pl:GetNWBool(trappedNwVar) then return end

	mv:SetForwardSpeed(0)
	mv:SetSideSpeed(0)
	mv:SetUpSpeed(0)

	mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP)))
end)

if SERVER then
	local escapeConVar = CreateConVar("ttt_beartrap_escape_pct", 0.03, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Escape chance each time you get damaged by the beartrap")
	local damageConVar = CreateConVar("ttt_beartrap_damage_per_tick", 8, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Amount of damage dealt per tick")
	local healthConVar = CreateConVar("ttt_beartrap_disarm_health", 80, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "How much damage the beartrap can take")

	local damageTimerName = "beartrap_dmg"

	function ENT:Initialize()
		self:SetModel("models/stiffy360/beartrap.mdl")
		self:SetRenderMode(RENDERMODE_TRANSCOLOR)

		self:PhysicsInitBox(Vector(-9, -9, -1), Vector(9, 9, 0.5), "metal")

		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:EnableMotion(false)
		end

		self:SetSequence("ClosedIdle")

		timer.Simple(0.666, function()
			if not IsValid(self) then return end

			self.ReadyToBite = true

			self:SetSequence("OpenIdle")
			self:SetColor(Color(255, 255, 255, 80))
		end)

		self:SetUseType(SIMPLE_USE)
		self.dmg = 0

		if TTT2 and IsValid(self.Owner) and self.Owner:IsPlayer() then
			local mvObject = self:AddMarkerVision(markerVisionId)
			mvObject:SetOwner(self.Owner:GetTeam())
			mvObject:SetVisibleFor(VISIBLE_FOR_TEAM)
			mvObject:SyncToClients()
		end
	end

	local function DoBleed(ent)
		if not IsValid(ent) or (ent:IsPlayer() and (not ent:Alive() or not ent:IsTerror())) then
		  return
		end

		local jitter = VectorRand() * 30
		jitter.z = 20

		util.PaintDown(ent:GetPos() + jitter, "Blood", ent)
	end

	util.AddNetworkString("ttt_bt_send_to_chat")
	local function LangChatPrint(pl, lang_key)
		net.Start("ttt_bt_send_to_chat")
		net.WriteString(lang_key)
		net.Send(pl)
	end

	function ENT:ReleaseTarget()
		local pl = self:GetNWEntity(trappedNwVar)
		if not IsValid(pl) then return end

		timer.Remove(damageTimerName .. pl:EntIndex())

		self:SetNWEntity(trappedNwVar, NULL)
		pl:SetNWBool(trappedNwVar, false)

		if TTT2 then
			-- Remove element to HUD if TTT2 is loaded
			STATUS:RemoveStatus(pl, "ttt2_beartrap")
		end
	end

	function ENT:Touch(toucher)
		if not IsValid(self) or not IsValid(toucher) then return end

		if self.ReadyToBite then
			-- Don't trigger from non-physical or frozen entities
			local toucherPhys = toucher:GetPhysicsObject()
			if not IsValid(toucherPhys) or not toucherPhys:IsMotionEnabled() then return end

			self.ReadyToBite = false

			self:SetPlaybackRate(1)
			self:SetCycle(0)
			self:SetSequence("Snap")
			self:SetColor(color_white)

			self:EmitSound("weapons/beartrap.ogg")

			if not toucher:IsPlayer() then
				timer.Simple(0.1, function()
					if not IsValid(self) then return end
					self:SetSequence("ClosedIdle")
				end)

				local dmg = DamageInfo()

				dmg:SetAttacker(self)
				dmg:SetInflictor(self)
				dmg:SetDamage(damageConVar:GetInt() * 3)
				dmg:SetDamageType(DMG_GENERIC)

				toucher:TakeDamageInfo(dmg)

				return
			end

			if toucher:GetNWBool(trappedNwVar) then return end

			self:SetNWEntity(trappedNwVar, toucher)
			toucher:SetNWBool(trappedNwVar, true)

			toucher:ViewPunch(Angle(10, 0, 0))
			toucher:ScreenFade(SCREENFADE.IN, Color(255, 40, 40, 50), 1, 0.1)

			local escpct = escapeConVar:GetFloat()

			if TTT2 then -- add element to HUD if TTT2 is loaded
				STATUS:AddStatus(toucher, "ttt2_beartrap")
			end

			LangChatPrint(toucher, "ttt_bt_catched")

			local timerName = damageTimerName .. toucher:EntIndex()

			timer.Create(timerName, 1, 0, function()
				if not IsValid(toucher) then
					timer.Remove(timerName)
					return
				end

				local randint = math.Rand(0, 1)
				randint = math.Round(randint, 2)

				if randint < escpct then
					self:ReleaseTarget()

					LangChatPrint(toucher, "ttt_bt_escaped")

					return
				end

				if not IsValid(self)
					or not toucher:IsTerror()
					or not toucher:Alive()
					or not toucher:GetNWBool(trappedNwVar)
				then
					self:ReleaseTarget()

					if toucher:Health() > 0 then
						LangChatPrint(toucher, "ttt_bt_freed")
					end

					return
				end

				local dmg = DamageInfo()

				local attacker = nil
				if self.Owner and IsValid(self.Owner) then
					attacker = self.Owner
				else
					attacker = toucher
				end

				if not self.InflictorWep then
					self.InflictorWep = ents.Create("weapon_ttt_beartrap")
					self.InflictorWep:SetOwner(attacker)
				end

				dmg:SetAttacker(attacker)
				dmg:SetInflictor(self.InflictorWep)
				dmg:SetDamage(damageConVar:GetInt())
				dmg:SetDamageType(DMG_GENERIC)

				toucher:AddEFlags(EFL_NO_DAMAGE_FORCES)
				toucher:TakeDamageInfo(dmg)
				toucher:RemoveEFlags(EFL_NO_DAMAGE_FORCES)

				DoBleed(toucher)
			end)

			timer.Simple(0.1, function()
				if not IsValid(self) then return end

				self:SetSequence("ClosedIdle")
				self:EmitSound("ambient/machines/slicer2.wav", 64, math.random(75, 85))
			end)
		end
	end

	function ENT:Use(act)
		if IsValid(act) and act:IsPlayer() and IsValid(self) then
			local owner = self:GetOwner()
			if IsValid(owner) and owner:IsTerror() and owner ~= act then return end

			local toucher = self:GetNWEntity(trappedNwVar)
			if IsValid(toucher) and toucher == act then return end

			if not act:HasWeapon("weapon_ttt_beartrap") then
				act:Give("weapon_ttt_beartrap")
				self:Remove()
			end
		end
	end

	function ENT:OnTakeDamage(dmg)
		if not IsValid(self) then return end

		local toucher = self:GetNWEntity(trappedNwVar)

		if self.ReadyToBite or IsValid(toucher) then
			self.dmg = self.dmg + dmg:GetDamage()

			if self.dmg >= healthConVar:GetInt() then
				self:SetPlaybackRate(1)
				self:SetCycle(0)
				self:SetSequence("Snap")
				self:SetColor(color_white)

				self.ReadyToBite = false

				self:ReleaseTarget()

				if toucher:Health() > 0 then
					LangChatPrint(toucher, "ttt_bt_freed")
				end

				timer.Simple(0.1, function()
					if not IsValid(self) then return end

					self:SetSequence("ClosedIdle")

					self:EmitSound("physics/metal/sawblade_stick3.wav", 64, math.random(60, 75))
				end)
			else
				self:EmitSound("physics/metal/metal_box_strain1.wav", 64, math.random(125, 150))
			end
		end
	end

	function ENT:OnRemove()
		if self.InflictorWep then
			SafeRemoveEntity(self.InflictorWep)
			self.InflictorWep = nil
		end
	end

	hook.Add("CanPlayerEnterVehicle", "ttt_beartrap_antimove", function(pl)
		if pl:GetNWBool(trappedNwVar) then return false end
	end)

	hook.Add("TTTPrepareRound", "ttt_beartrap_destroytimers", function()
		for _, v in ipairs(player.GetAll()) do
			if IsValid(v) then
				v:SetNWBool(trappedNwVar, false)
			end
		end
	end)
else
	function ENT:Draw()
		self:DrawModel()
	end

	if TTT2 then
		local TryT = LANG.TryTranslation
		local ParT = LANG.GetParamTranslation

		hook.Add("Initialize", "ttt_beartrap_init", function()
			STATUS:RegisterStatus("ttt2_beartrap", {
				hud = Material("vgui/ttt/hud_icon_beartrap.png"),
				type = "bad"
			})
		end)

		hook.Add("TTTRenderEntityInfo", "ttt2_beartrap_highlight", function(tData)
			local client = LocalPlayer()
			local ent = tData:GetEntity()

			if not IsValid(client) or not client:IsTerror() or not client:Alive()
				or not IsValid(ent) or tData:GetEntityDistance() > 100 or ent:GetClass() ~= "ttt_bear_trap"
			then
				return
			end

			local owner = ent:GetNWEntity("BTOWNER")
			if IsValid(owner) and owner ~= client and owner:IsTerror() then return end

			local toucher = ent:GetNWEntity(trappedNwVar)
			if IsValid(toucher) and toucher == client then return end

			tData:EnableText()
			tData:EnableOutline()
			tData:SetOutlineColor(client:GetRoleColor())

			tData:SetTitle(TryT("beartrap_name"))
			tData:SetSubtitle(ParT("target_pickup", {usekey = Key("+use", "USE")}))
			tData:SetKeyBinding("+use")

			tData:AddDescriptionLine(TryT("beartrap_desc"))
		end)

		local materialIcon = Material("vgui/ttt/hud_icon_beartrap.png")

		hook.Add("TTT2RenderMarkerVisionInfo", "ttt2_beartrap_marker", function(mvData)
			local ent = mvData:GetEntity()
			local mvObject = mvData:GetMarkerVisionObject()

			if not mvObject:IsObjectFor(ent, markerVisionId)
				or (mvData:IsOnScreenCenter() and mvData:GetEntityDistance() <= 100) then return end

			local isActive = ent:GetSequence() == 1

			mvData:EnableText()

			mvData:SetTitle(TryT("beartrap_name"))
			mvData:AddDescriptionLine(isActive and "Armed! Watch your step!" or "Closed shut.")
			mvData:AddDescriptionLine(TryT(mvObject:GetVisibleForTranslationKey()), COLOR_SLATEGRAY)

			mvData:AddIcon(
				materialIcon,
				(mvData:IsOffScreen() or not mvData:IsOnScreenCenter()) and (isActive and COLOR_WHITE or COLOR_SLATEGRAY)
			)
		end)

		net.Receive("ttt_bt_send_to_chat", function(len, pl)
			local langKey = net.ReadString()

			MSTACK:AddColoredImagedMessage(
				LANG.TryTranslation(langKey),
				nil,
				materialIcon
			)
		end)
	end
end