if SERVER then
    AddCSLuaFile()

    util.AddNetworkString("ttt_deadshot_trail")
end

--#region CVars

local cvarNonbounceDamage = CreateConVar("ttt_deadshot_nonbouncedamage",
    50, { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED })
local cvarMaxBounces = CreateConVar("ttt_deadshot_maxbounces",
    20, { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED })
local cvarShotTrailTime = CreateConVar("ttt_deadshot_shottrail",
    1, { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED })
local cvarBounceOffPlayers = CreateConVar("ttt_deadshot_bounceoffplayers",
    1, { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED })

--#endregion

DEFINE_BASECLASS("weapon_tttbase")
SWEP.Base = "weapon_tttbase"

if CLIENT then
    SWEP.PrintName = "ttt_deadshot_name"
    SWEP.Author = "Lixquid"
    SWEP.Slot = 7

    SWEP.ViewModelFlip = true
    SWEP.ViewModelFOV = 54

    SWEP.EquipMenuData = {
        type = "item_weapon",
        desc = "ttt_deadshot_desc"
    }

    SWEP.Icon = "vgui/ttt/icon_deadshot"
    SWEP.IconLetter = "n"

    LANG.AddToLanguage("en", "ttt_deadshot_name", "Deadshot Rifle")
    LANG.AddToLanguage("en", "ttt_deadshot_desc",
        "A rifle with a rubberized round that can bounce off walls, and a "
        .. "scope that can infinitely zoom and show the trajectory of the "
        .. "round.\n" ..
        "Note that this weapon deals middling damage before bouncing; make "
        .. "sure you bounce it off a wall to maximize its potential!\n" ..
        "Use the mouse-wheel while scoped to zoom in and out.")

    LANG.AddToLanguage("en", "ttt_deadshot_nonbouncedamage_name",
        "Deadshot Rifle Non-Bounce Damage")
    LANG.AddToLanguage("en", "ttt_deadshot_nonbouncedamage_help",
        "The amount of damage the Deadshot Rifle deals if it hits a player "
        .. "without bouncing off a wall.")
    LANG.AddToLanguage("en", "ttt_deadshot_maxbounces_name",
        "Deadshot Rifle Max Bounces")
    LANG.AddToLanguage("en", "ttt_deadshot_maxbounces_help",
        "The maximum number of times the Deadshot Rifle's round can bounce.")
    LANG.AddToLanguage("en", "ttt_deadshot_shottrail_name",
        "Deadshot Rifle Shot Trail Time")
    LANG.AddToLanguage("en", "ttt_deadshot_shottrail_help",
        "The length of time the Deadshot Rifle's shot trail is visible, " ..
        "in seconds.\n" ..
        "Set to 0 to disable the shot trail.")
    LANG.AddToLanguage("en", "ttt_deadshot_bounceoffplayers_name",
        "Deadshot Rifle Bounce Off Players")
    LANG.AddToLanguage("en", "ttt_deadshot_bounceoffplayers_help",
        "If enabled, the Deadshot Rifle's round will continue to travel " ..
        "after hitting a player.")
end

SWEP.HoldType = "ar2"

SWEP.ViewModel = "models/weapons/v_snip_awp.mdl"
SWEP.WorldModel = "models/weapons/w_snip_awp.mdl"

SWEP.Primary.Damage = 1000
SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 1.5
SWEP.Primary.Ammo = "none"
SWEP.Primary.Sound = Sound("Weapon_AWP.Single")

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Kind = WEAPON_EQUIP2
SWEP.CanBuy = { ROLE_TRAITOR }
SWEP.DeploySpeed = 1
SWEP.NoSights = false
SWEP.IronSightsPos = Vector(5, -15, -2)
SWEP.IronSightsAng = Vector(2.6, 1.37, 3.5)

--#region Util
---@param startPos Vector
---@param direction Angle
---@param maxLength number
---@return {traces: TraceResult[], pos: Vector, ang: Angle}
local function calculateTrajectory(startPos, direction, maxLength, ignoredEnts)
    local bounceOffPlayers = cvarBounceOffPlayers:GetBool()

    local pos = startPos
    local dir = direction:Forward()
    local length = maxLength
    local traces = {}

    for i = 1, cvarMaxBounces:GetInt() do
        local endpos = pos + dir * length

        local trace = util.TraceLine({
            start = pos,
            endpos = endpos,
            mask = MASK_SHOT,
            filter = ignoredEnts
        })

        table.insert(traces, trace)

        if not trace.Hit then
            return { traces = traces, pos = endpos, ang = dir:Angle() }
        end

        -- Don't bounce off skybox or players
        if trace.HitSky or trace.Entity:IsPlayer() and not bounceOffPlayers then
            return { traces = traces, pos = trace.HitPos, ang = dir:Angle() }
        end

        -- Offset the position slightly to prevent the trace from hitting the
        -- same surface again
        pos = trace.HitPos + trace.HitNormal * 0.1

        dir = dir - 2 * dir:Dot(trace.HitNormal) * trace.HitNormal
        length = length - trace.Fraction * length
    end

    return { traces = traces, pos = pos, ang = dir:Angle() }
end

local function playerIsHoldingZoomedDeadshot(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    local wep = ply:GetActiveWeapon()
    return IsValid(wep) and wep:GetClass() == "weapon_ttt_deadshot" and wep.GetIronsights and wep:GetIronsights()
end
--#endregion

--#region SWEP Hooks
function SWEP:Initialize()
    self:ResetZoom()

    return BaseClass.Initialize(self)
end

function SWEP:Think()
    if CLIENT then
        self.ZoomDisplay = math.Approach(
            self.ZoomDisplay, self.Zoom,
            (self.Zoom - self.ZoomDisplay) * FrameTime()
        )
    end

    return BaseClass.Think(self)
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    self:TakePrimaryAmmo(1)

    if CLIENT then return end

    local t = calculateTrajectory(
        self.Owner:GetShootPos(),
        self.Owner:EyeAngles(),
        10000,
        { self.Owner }
    )

    local trails = {}

    for i, trace in ipairs(t.traces) do
        local bullet = {
            Num = 1,
            Src = trace.StartPos,
            Dir = trace.Normal,
            Spread = Vector(0, 0, 0),
            Tracer = 0,
            Force = 100,
            Damage = i == 1 and cvarNonbounceDamage:GetInt() or self.Primary.Damage,
        }
        self.Owner:FireBullets(bullet)

        table.insert(trails, { trace.StartPos, trace.HitPos })

        if trace.Hit then
            -- scorch mark
            util.Decal("Scorch", trace.HitPos + trace.HitNormal, trace.HitPos - trace.HitNormal)

            -- bounce sound
            EmitSound(Sound("weapons/ric1.wav"), trace.HitPos)
        end
    end

    if cvarShotTrailTime:GetFloat() > 0 then
        net.Start("ttt_deadshot_trail")
        net.WriteInt(#trails, 8)
        for _, v in ipairs(trails) do
            net.WriteVector(v[1])
            net.WriteVector(v[2])
        end
        net.Broadcast()
    end

    self:EmitSound(self.Primary.Sound, 100)
end

function SWEP:SecondaryAttack()
    if self:GetNextSecondaryFire() > CurTime() then return end

    self:SetNextSecondaryFire(CurTime() + 0.3)
    self:SetIronsights(not self:GetIronsights())

    self.Zoom = 0
    self:EmitSound("weapons/sniper/sniper_zoomin.wav")
end

function SWEP:Holster()
    self:ResetZoom()

    return BaseClass.Holster(self)
end

function SWEP:PreDrop()
    self:ResetZoom()

    return BaseClass.PreDrop(self)
end

function SWEP:CalcView(ply, origin, angles, fov)
    if SERVER or self.ZoomDisplay < 1 then return end

    local t = calculateTrajectory(origin, angles, self.ZoomDisplay, { ply })
    return t.pos, t.ang, fov
end

function SWEP:AdjustMouseSensitivity()
    if SERVER or self.ZoomDisplay < 1 then return end

    return math.min(100 / self.ZoomDisplay, 1)
end

--#endregion

--#region Private
function SWEP:ResetZoom()
    self.Zoom = 0
    if CLIENT then
        self.ZoomDisplay = 0
    end
end

--#endregion

--#region Gamemode Hooks
if CLIENT then
    -- Capture the mouse wheel input to zoom in and out
    hook.Add("CreateMove", "ttt_deadshot", function(cmd)
        if not playerIsHoldingZoomedDeadshot(LocalPlayer()) then return end

        local wep = LocalPlayer():GetActiveWeapon()

        wep.Zoom = wep.Zoom or 0

        if cmd:GetMouseWheel() > 0 then
            wep.Zoom = wep.Zoom + 20
        elseif cmd:GetMouseWheel() < 0 then
            wep.Zoom = math.max(0, wep.Zoom - 20)
        end
    end)

    -- Don't scroll the weapon select while using the scope
    hook.Add("PlayerBindPress", "ttt_deadshot", function(_, bind, pressed)
        if not pressed or not playerIsHoldingZoomedDeadshot(LocalPlayer()) then return end

        if bind == "invprev" or bind == "invnext" then
            return true
        end
    end)

    ---@type {from: Vector, to: Vector, timeStarted: number, timeEnd: number}[]
    local deadshotTrails = {}
    net.Receive("ttt_deadshot_trail", function()
        local count = net.ReadInt(8)

        for i = 1, count do
            local from = net.ReadVector()
            local to = net.ReadVector()

            table.insert(deadshotTrails, {
                from = from,
                to = to,
                timeStarted = CurTime(),
                timeEnd = CurTime() + cvarShotTrailTime:GetFloat()
            })
        end
    end)
    hook.Add("PostDrawTranslucentRenderables", "ttt_deadshot", function()
        for k, v in pairs(deadshotTrails) do
            if v.timeEnd < CurTime() then
                deadshotTrails[k] = nil
            else
                local s = (v.timeEnd - CurTime()) / (v.timeEnd - v.timeStarted)

                render.SetColorMaterial()
                render.SetMaterial(Material("trails/tube"))
                render.DrawBeam(v.from, v.to, s * 16, 0, 0, COLOR_WHITE)
            end
        end
    end)
end
--#endregion
