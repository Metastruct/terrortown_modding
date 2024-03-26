-- Traq Rifle created by https://steamcommunity.com/profiles/76561198813867340

if SERVER then
    AddCSLuaFile()
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.HoldType = "ar2"

if CLIENT then
    SWEP.PrintName = "Rifle (ZZZ)"
    SWEP.Slot = 6

    SWEP.ViewModelFlip = false
    SWEP.ViewModelFOV = 54
    
    SWEP.EquipMenuData = {
        type = "item_weapon",
        desc = "A Non-Lethal Rifle.\nHeadshots sleep instantly for 45 seconds.\nBodyshots take 10 seconds to sleep for 20 seconds."
    }
    
    SWEP.Icon = "vgui/ttt/icon_scout"
    SWEP.IconLetter = "n"
end

SWEP.Base = "weapon_tttbase"

SWEP.Kind = WEAPON_EQUIP
SWEP.WeaponID = AMMO_RIFLE
SWEP.CanBuy = { ROLE_DETECTIVE , ROLE_TRAITOR }
SWEP.LimitedStock = false
SWEP.builtin = true
SWEP.spawnType = WEAPON_TYPE_SNIPER

SWEP.Primary.Delay = 1.05
SWEP.Primary.Recoil = 1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "357"
SWEP.Primary.Damage = 0
SWEP.Primary.NumShots = 0
SWEP.Primary.Cone = 0.010
SWEP.Primary.ClipSize = 10
SWEP.Primary.ClipMax = 20 -- keep mirrored to ammo
SWEP.Primary.DefaultClip = 10
SWEP.Primary.Sound = Sound("Weapon_USP.SilencedShot")

SWEP.Secondary.Sound = Sound("Default.Zoom")

SWEP.HeadshotMultiplier = 3

SWEP.AutoSpawnable = false
SWEP.Spawnable = false

SWEP.UseHands = true
SWEP.ViewModel = Model("models/weapons/cstrike/c_snip_scout.mdl")
SWEP.WorldModel = Model("models/weapons/w_snip_scout.mdl")
SWEP.idleResetFix = true

SWEP.IronSightsPos = Vector(5, -15, -2)
SWEP.IronSightsAng = Vector(2.6, 1.37, 3.5)

---
-- @ignore
function SWEP:SetZoom(state)
    local owner = self:GetOwner()

    if not IsValid(owner) or not owner:IsPlayer() then
        return
    end

    if state then
        owner:SetFOV(20, 0.3)
    else
        owner:SetFOV(0, 0.2)
    end
end

//Stores the players weaponclasses and ammo in a table.
local function PlyStoreWeapons(ply)
	ply.storeweps = {}
	for k,v in pairs(ply:GetWeapons()) do
		table.insert(ply.storeweps, {cl = v:GetClass(), c1 = v:Clip1(), c2 = v:Clip2()})
	end
end

//Retrieves the stored weapons.
local function PlyRetrieveWeapons(ply)
	for k,v in pairs(ply.storeweps or {}) do
		ply:Give(v.cl)
		local wep = ply:GetWeapon(v.cl)
		if IsValid(wep) then
			wep:SetClip1(v.c1)
			wep:SetClip2(v.c2)
		end
	end
end

RIFLE_ZZZ = {}
/*
Makes a hull trace the size of a player.
*/
local data = {}
function RIFLE_ZZZ.PlayerHullTrace(pos, ply, filter)
	data.start = pos
	data.endpos = pos
	data.filter = filter
	
	return util.TraceEntity( data, ply )
end

//Transforms a (1,1,1,1) color table to (255,255,255,255)
local function FromPlyColor(v)
	v:Mul(255)
	return Color(v.x,v.y,v.z,255)
end

/*
Attemps to place the player at this position or as close as possible.
*/
// Directions to check
local directions = {
	Vector(0,0,0), Vector(0,0,1), //Center and up
	Vector(1,0,0), Vector(-1,0,0), Vector(0,1,0), Vector(0,-1,0) //All cardinals
	}
for deg=45,315,90 do //Diagonals
	local r = math.rad(deg)
	table.insert(directions, Vector(math.Round(math.cos(r)), math.Round(math.sin(r)), 0))
end

local magn = 15 // How much increment for each iteration
local iterations = 2 // How many iterations
function RIFLE_ZZZ.PlayerSetPosNoBlock( ply, pos, filter )
	local tr
	
	local dirvec
	local m = magn
	local i = 1
	local its = 1
	repeat
		dirvec = directions[i] * m
		i = i + 1
		if i > #directions then
			its = its + 1
			i = 1
			m = m + magn
			if its > iterations then
				ply:SetPos(pos) // We've done as many checks as we wanted, lets just force him to get stuck then.
				return false
			end
		end
		
		tr = RIFLE_ZZZ.PlayerHullTrace(dirvec + pos, ply, filter)
	until tr.Hit == false
	
	ply:SetPos(pos + dirvec)
	return true
end

/*
Sets the player invisible/visible
*/
function RIFLE_ZZZ.PlayerInvis( ply, bool )
	ply:SetNoDraw(bool)
	ply:DrawShadow(not bool)

	if pac and pac.TogglePartDrawing then
		pac.TogglePartDrawing(ply, not bool)
	end
	/*
	ply:SetMaterial( bool and "models/effects/vol_light001" or "" )
	ply:SetRenderMode( bool and RENDERMODE_TRANSALPHA or RENDERMODE_NORMAL )
	ply:Fire( "alpha", bool and 0 or 255, 0 )
	*/
end


/*
Deploy player ragdoll
*/
function RIFLE_ZZZ.Ragdoll( ply, pushdir )
	if not SERVER then return end
	local plyphys = ply:GetPhysicsObject()
	local plyvel = Vector(0,0,0)
	if plyphys:IsValid() then
		plyvel = plyphys:GetVelocity()
	end
	
	ply.sleepdpos = ply:GetPos() // Store pos incase the ragdoll is missing when we're to unrag him.
	
	local rag = ents.Create("prop_ragdoll")
		rag:SetModel(ply:GetModel())
		rag:SetPos(ply:GetPos())
		rag:SetAngles(Angle(0,ply:GetAngles().y,0))
		//FromPlyColor(ply:GetPlayerColor())) //Clothes get correct color, but the head gets pitchblack. :(
		rag:SetColor(ply:GetColor())
		rag:SetMaterial(ply:GetMaterial())
		rag:Spawn()
		rag:Activate()
	
	if not IsValid(rag:GetPhysicsObject()) then
		MsgN("A sleepd player didn't get a valid ragdoll. Model ("..ply:GetModel()..")!")
		SafeRemoveEntity(rag)
		return false
	end
	
	//Lower inertia makes the ragdoll have trouble rolling. Citizens have 1,1,1 as default, while combines have 0.2,0.2,0.2.
	rag:GetPhysicsObject():SetInertia(Vector(1,1,1)) 
	
	//Push him back abit
	plyvel = plyvel + pushdir*200
	rag:GetPhysicsObject():SetVelocity(plyvel)
		
	//Stop firing of weapons
	PlyStoreWeapons(ply)
	ply:StripWeapons()
	
	//Makes him not collide with anything, including traces.
	ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	
	//Make him follow the ragdoll, if the player gets away from the ragdoll he won't get stuff rendered properly.
	ply:SetParent(rag)
	
	//Make the player invisible.
	RIFLE_ZZZ.PlayerInvis(ply, true)

	ply.sleepragdoll = rag
	rag.sleepplayer = ply
	
	ply:SetNWEntity("tazerviewrag", rag)
	rag:SetNWEntity("plyowner", ply)
	
	ply.lasthp = ply:Health()
	net.Start("tazersendhealth")
		net.WriteEntity(ply)
		net.WriteInt(ply:Health(),32)
	net.Broadcast()
	
	return true
end


function RIFLE_ZZZ.UnRagdoll( ply )
	if not SERVER then return end
	local ragvalid = IsValid(ply.sleepragdoll)
	local pos
	if ragvalid then // Sometimes the ragdoll is missing when we want to unrag, not good!
		if ply.sleepragdoll.hasremoved then return end // It has already been removed.
		
		pos = ply.sleepragdoll:GetPos()
		ply:SetModel(ply.sleepragdoll:GetModel())
		ply.sleepragdoll.hasremoved = true
	else
		pos = ply.sleepdpos // Put him at the place he got sleepd, works great.
	end
	ply:SetParent()
	
	RIFLE_ZZZ.PlayerSetPosNoBlock(ply, pos, {ply, ply.sleepragdoll})
	
	ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
	
	timer.Simple(0,function()
		SafeRemoveEntity(ply.sleepragdoll)
		RIFLE_ZZZ.PlayerInvis(ply, false)
	end)
	
	timer.Simple(.5, function()
		PlyRetrieveWeapons(ply)
	end)
	
	net.Start("tazeendview")
	net.Send(ply)
end

hook.Add("EntityTakeDamage", "SleepDamageHandler", function(ent, dmginfo)
	if ent:IsPlayer() and IsValid(ent.sleepragdoll) and not ent.ragdolldamage then // If we're hitting the player somehow we won't let, the ragdoll should take the damage.
		dmginfo:SetDamage(0)
		return
	end
	
	if IsValid(ent.sleepplayer) and (dmginfo:GetAttacker() != game.GetWorld()) then //Worldspawn appears to be very eager to damage ragdolls. Don't!		
		local ply = ent.sleepplayer
		//To prevent infiniteloop and other trickery, we need to know if it was ragdamage.
		ply.ragdolldamage = true
		ply:TakeDamageInfo(dmginfo) // Apply all ragdoll damage directly to the player.
		ply.ragdolldamage = false
	end
end)

hook.Add( "PlayerUse", "ZZZ_RagdollWake", function( ply, ent )
    if IsValid(ent) and IsValid(ent.sleepplayer) then
        plytarg = ent.sleepplayer
        RIFLE_ZZZ.UnRagdoll(plytarg)
        if timer.Exists("Unsleep".. plytarg:UserID()) then
            timer.Remove( "Unsleep".. plytarg:UserID())
        end
	
        if not SERVER then return end
        
	if ply:IsWalking() then
            dmgtable = DamageInfo()
            dmgtable:SetDamage((plytarg:Health())*1.5)
            dmgtable:SetAttacker(ply)
            dmgtable:SetDamageForce(Vector(0,0,-1))
            dmgtable:SetDamagePosition(plytarg:GetPos())
            dmgtable:SetDamageType(4)
            dmgtable:SetInflictor(ply)
            timer.Create("KillAfterUnsleep".. plytarg:UserID(), 0.1, 1, function()
                plytarg:TakeDamageInfo( dmgtable )
                
            end)
        end
    end
end)
	
function RIFLE_ZZZ.Sleep( ply, pushdir, timedur )
	
	//Ragdoll
	RIFLE_ZZZ.Ragdoll(ply, pushdir)
	
	//Gag
	ply.tazeismuted = true
	
	local id = ply:UserID()
	timer.Create("Unsleep"..id, timedur, 1, function()
		if IsValid(ply) then RIFLE_ZZZ.UnRagdoll( ply ) end
	end)
	timer.Create("tazeUngag"..id, timedur, 1, function()
		if IsValid(ply) then ply.tazeismuted = false end
	end)
	
end

---
-- @ignore
function SWEP:PrimaryAttack(worldsnd)
    BaseClass.PrimaryAttack(self, worldsnd)

    if self:Clip1() == 0 then return end
    local bullet = {}
    bullet.Num = 1
    bullet.Src = self:GetOwner():GetShootPos()
    bullet.Dir = self:GetOwner():GetAimVector()
    bullet.Spread = Vector(0.010, 0.010, 0)
    bullet.Tracer = 4
    bullet.Force = 5
    bullet.Damage = 5
    bullet.Callback = function(att, tr, dmginfo)
        if SERVER or (CLIENT and IsFirstTimePredicted()) then
            local ent = tr.Entity
            if (not tr.HitWorld) and IsValid(ent) and ent:IsPlayer() then
                print(dmginfo:GetDamage())
                if tr.HitGroup == 1 then
                    RIFLE_ZZZ.Sleep(ent, Vector(0,0,0),45)
		    if timer.Exists("SleepIn".. ent:UserID()) then
                        timer.Remove("SleepIn".. ent:UserID())
                    end
                    return
                end
		if timer.Exists("SleepIn".. ent:UserID()) then return end
                timer.Create("SleepIn"..ent:UserID(), 10, 1, function()
                    if IsValid(ent) then RIFLE_ZZZ.Sleep(ent, Vector(0,0,0),20) end
                end)
            end
        end
    end

    self:GetOwner():FireBullets(bullet)
    self:SetNextSecondaryFire(CurTime() + 0.1)
end

---
-- Add some zoom to ironsights for this gun
-- @ignore
function SWEP:SecondaryAttack()
    if not self.IronSightsPos or self:GetNextSecondaryFire() > CurTime() then
        return
    end

    local bIronsights = not self:GetIronsights()

    self:SetIronsights(bIronsights)
    self:SetZoom(bIronsights)

    if CLIENT then
        self:EmitSound(self.Secondary.Sound)
    end

    self:SetNextSecondaryFire(CurTime() + 0.3)
end

---
-- @ignore
function SWEP:PreDrop()
    self:SetIronsights(false)
    self:SetZoom(false)

    return BaseClass.PreDrop(self)
end

---
-- @ignore
function SWEP:Reload()
    if
        self:Clip1() == self.Primary.ClipSize
        or self:GetOwner():GetAmmoCount(self.Primary.Ammo) <= 0
    then
        return
    end

    self:DefaultReload(ACT_VM_RELOAD)

    self:SetIronsights(false)
    self:SetZoom(false)
end

---
-- @ignore
function SWEP:Holster()
    self:SetIronsights(false)
    self:SetZoom(false)

    return true
end

if CLIENT then
    local scope = surface.GetTextureID("sprites/scope")

    ---
    -- @ignore
    function SWEP:DrawHUD()
        if self:GetIronsights() then
            surface.SetDrawColor(0, 0, 0, 255)

            local scrW = ScrW()
            local scrH = ScrH()

            local x = 0.5 * scrW
            local y = 0.5 * scrH
            local scope_size = scrH

            -- crosshair
            local gap = 80
            local length = scope_size

            surface.DrawLine(x - length, y, x - gap, y)
            surface.DrawLine(x + length, y, x + gap, y)
            surface.DrawLine(x, y - length, x, y - gap)
            surface.DrawLine(x, y + length, x, y + gap)

            gap = 0
            length = 50

            surface.DrawLine(x - length, y, x - gap, y)
            surface.DrawLine(x + length, y, x + gap, y)
            surface.DrawLine(x, y - length, x, y - gap)
            surface.DrawLine(x, y + length, x, y + gap)

            -- cover edges
            local sh = 0.5 * scope_size
            local w = x - sh + 2

            surface.DrawRect(0, 0, w, scope_size)
            surface.DrawRect(x + sh - 2, 0, w, scope_size)

            -- cover gaps on top and bottom of screen
            surface.DrawLine(0, 0, scrW, 0)
            surface.DrawLine(0, scrH - 1, scrW, scrH - 1)

            surface.SetDrawColor(255, 0, 0, 255)
            surface.DrawLine(x, y, x + 1, y + 1)

            -- scope
            surface.SetTexture(scope)
            surface.SetDrawColor(255, 255, 255, 255)

            surface.DrawTexturedRectRotated(x, y, scope_size, scope_size, 0)
        else
            return BaseClass.DrawHUD(self)
        end
    end

    ---
    -- @ignore
    function SWEP:AdjustMouseSensitivity()
        return self:GetIronsights() and 0.2 or nil
    end
end