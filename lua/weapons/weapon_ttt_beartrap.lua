if SERVER then
	AddCSLuaFile()
else
	SWEP.PrintName = "beartrap_name"

	SWEP.Slot = 7
	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 54

	SWEP.Icon = "vgui/ttt/icon_beartrap.png"

	SWEP.EquipMenuData = {
		type = "item_weapon",
		name = "beartrap_name",
		desc = "beartrap_desc",
	}
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.HoldType = "normal"

SWEP.ViewModel = "models/stiffy360/c_beartrap.mdl"
SWEP.WorldModel = "models/stiffy360/beartrap.mdl"
SWEP.UseHands = true

SWEP.NoSights = true

SWEP.AutoSpawnable = false

SWEP.Kind = WEAPON_EQUIP2
SWEP.CanBuy = { ROLE_TRAITOR }
SWEP.LimitedStock = true

SWEP.DeploySpeed = 3.5

function SWEP:PrimaryAttack()
	if CLIENT then return end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local pos = owner:GetShootPos()

	local tr = util.TraceLine({
		start = pos,
		endpos = pos + (owner:GetAimVector() * 100),
		filter = owner
	})

	if tr.HitWorld then
		local dot = vector_up:Dot(tr.HitNormal)

		if dot > 0.55 and dot <= 1 then
			local ent = ents.Create("ttt_bear_trap")

			ent:SetPos(tr.HitPos + tr.HitNormal)

			local ang = tr.HitNormal:Angle()

			ang:RotateAroundAxis(ang:Right(), -90)
			ent:SetAngles(ang)

			ent.Owner = owner

			ent:Spawn()
			ent:SetNWEntity("BTOWNER", owner)

			ent.fingerprints = self.fingerprints

			self:Remove()
		end
	end
end

if CLIENT then
	function SWEP:Initialize()
		BaseClass.Initialize(self)

		self:AddTTT2HUDHelp("beartrap_help_primary")
	end

	function SWEP:DrawWorldModel()
		if IsValid(self:GetOwner()) then return end
		self:DrawModel()
	end

	function SWEP:GetViewModelPosition(pos, ang)
		return pos + ang:Forward() * 15, ang
	end

	function SWEP:AddToSettingsMenu(parent)
		local form = vgui.CreateTTT2Form(parent, "header_equipment_additional")

		form:MakeSlider({
			serverConvar = "ttt_beartrap_disarm_health",
			label = "label_beartrap_disarm_health",
			min = 0,
			max = 300,
			decimal = 0,
		})

		form:MakeSlider({
			serverConvar = "ttt_beartrap_escape_pct",
			label = "label_beartrap_escape_pct",
			min = 0,
			max = 1,
			decimal = 2,
		})

		form:MakeSlider({
			serverConvar = "ttt_beartrap_damage_per_tick",
			label = "label_beartrap_damage_per_tick",
			min = 0,
			max = 100,
			decimal = 0,
		})
	end
end