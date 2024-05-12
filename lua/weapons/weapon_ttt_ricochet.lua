if SERVER then
    AddCSLuaFile()
    resource.AddFile("materials/vgui/ttt/icon_ricochet.vmt")

    util.AddNetworkString("ttt_ricochet_trail")
end

--#region CVars

local HITPLAYERACT_STOP = 0
local HITPLAYERACT_BOUNCE = 1
local HITPLAYERACT_CONTINUE = 2

local cvarNonbounceDamage = CreateConVar("ttt_ricochet_nonbouncedamage",
    25, { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED })
local cvarMaxBounces = CreateConVar("ttt_ricochet_maxbounces",
    20, { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED })
local cvarShotTrailTime = CreateConVar("ttt_ricochet_shottrail",
    1.5, { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED })
local cvarHitPlayerAction = CreateConVar("ttt_ricochet_hitplayeraction",
    HITPLAYERACT_CONTINUE, { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED })
local cvarShotCount = CreateConVar("ttt_ricochet_shotcount",
    3, { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED })

--#endregion

DEFINE_BASECLASS("weapon_tttbase")
SWEP.Base = "weapon_tttbase"

if CLIENT then
    SWEP.PrintName = "ttt_ricochet_name"
    SWEP.Author = "Lixquid"
    SWEP.Slot = 7

    SWEP.ViewModelFlip = false
    SWEP.ViewModelFOV = 54
    SWEP.UseHands = true

    SWEP.EquipMenuData = {
        type = "item_weapon",
        desc = "ttt_ricochet_desc"
    }

    SWEP.Icon = "vgui/ttt/icon_ricochet"
    SWEP.IconLetter = "n"

    LANG.AddToLanguage("en", "ttt_ricochet_name", "Ricochet Rifle")
    LANG.AddToLanguage("en", "ttt_ricochet_desc",
        "A rifle with a rubberized round that can bounce off walls, and a "
        .. "scope that can infinitely zoom and show the trajectory of the "
        .. "round.\n" ..
        "Note that this weapon deals middling damage before bouncing; make"
        .. "sure you bounce it off a wall to maximize its potential!\n" ..
        "Use the mouse-wheel while scoped to zoom in and out.")

    LANG.AddToLanguage("en", "ttt_ricochet_nonbouncedamage_name",
        "Non-Bounce Damage")
    LANG.AddToLanguage("en", "ttt_ricochet_nonbouncedamage_help",
        "The amount of damage the Deadshot Rifle deals if it hits a player "
        .. "without bouncing off a wall.")
    LANG.AddToLanguage("en", "ttt_ricochet_maxbounces_name",
        "Max Bounces")
    LANG.AddToLanguage("en", "ttt_ricochet_maxbounces_help",
        "The maximum number of times the Deadshot Rifle's round can bounce.")
    LANG.AddToLanguage("en", "ttt_ricochet_shottrail_name",
        "Shot Trail Time")
    LANG.AddToLanguage("en", "ttt_ricochet_shottrail_help",
        "The length of time the Deadshot Rifle's shot trail is visible, " ..
        "in seconds.\n" ..
        "Set to 0 to disable the shot trail.")
    LANG.AddToLanguage("en", "ttt_ricochet_hitplayeraction_name",
        "Hit Players Action")
    LANG.AddToLanguage("en", "ttt_ricochet_hitplayeraction_help",
        "What to do upon hitting a player with a shot.")

    LANG.AddToLanguage("en", "ttt_ricochet_hitplayeraction_stop",
        "Stop the shot.")
    LANG.AddToLanguage("en", "ttt_ricochet_hitplayeraction_bounce",
        "Bounce off the player.")
    LANG.AddToLanguage("en", "ttt_ricochet_hitplayeraction_continue",
        "Penetrate through the player.")
    LANG.AddToLanguage("en", "ttt_ricochet_shotcount_name",
        "Shot Count")
    LANG.AddToLanguage("en", "ttt_ricochet_shotcount_help",
        "The number of shots the Deadshot Rifle spawns with.")

    language.Add("ttt_ricochet_scopeinfo",
        "Zoom: %du\n" ..
        "Bounces: %d / %d\n" ..
        "\n" ..
        "Scroll the mouse to zoom in and out.\n" ..
        "Zoom into a wall to follow the trajectory of the bounced round."
    )
end

SWEP.HoldType = "ar2"

SWEP.ViewModel = "models/weapons/cstrike/c_snip_scout.mdl"
SWEP.WorldModel = "models/weapons/w_snip_scout.mdl"

SWEP.Primary.Damage = 1000
SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 1.5
SWEP.Primary.Ammo = "none"
SWEP.Primary.Sound1 = Sound("npc/sniper/echo1.wav")
SWEP.Primary.Sound2 = Sound("npc/sniper/sniper1.wav")

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
    local playerHitMode = cvarHitPlayerAction:GetInt()

    local pos = startPos
    local dir = direction:Forward()
    local length = maxLength
    local traces = {}
    local ignored = table.Copy(ignoredEnts)

    -- Ignore all players if set to penetrate through them
    if playerHitMode == HITPLAYERACT_CONTINUE then
        for _, ply in ipairs(player.GetAll()) do
            table.insert(ignored, ply)
        end
    end

    local i = 0
    while i < cvarMaxBounces:GetInt() do
        i = i + 1
        local endpos = pos + dir * length

        local trace = util.TraceLine({
            start = pos,
            endpos = endpos,
            mask = MASK_SHOT,
            filter = ignored
        })

        table.insert(traces, trace)

        if not trace.Hit then
            return { traces = traces, pos = endpos, ang = dir:Angle() }
        end

        -- Don't bounce off skybox or players if set not to
        if trace.HitSky or trace.Entity:IsPlayer() and playerHitMode == HITPLAYERACT_STOP then
            return { traces = traces, pos = trace.HitPos, ang = dir:Angle() }
        end

        if trace.Entity and trace.Entity:IsPlayer() and cvarHitPlayerAction:GetInt() == HITPLAYERACT_CONTINUE then
            table.insert(ignored, trace.Entity)
            i = i - 1
        else
            -- Offset the position slightly to prevent the trace from hitting the
            -- same surface again
            pos = trace.HitPos + trace.HitNormal * 0.1

            dir = dir - 2 * dir:Dot(trace.HitNormal) * trace.HitNormal
            length = length - trace.Fraction * length
        end
    end

    return { traces = traces, pos = pos, ang = dir:Angle() }
end

local function playerIsHoldingZoomedDeadshot(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    local wep = ply:GetActiveWeapon()
    return IsValid(wep) and wep:GetClass() == "weapon_ttt_ricochet" and wep.GetIronsights and wep:GetIronsights()
end
--#endregion

--#region SWEP Hooks
function SWEP:Initialize()
    self:ResetZoom()
    self:SetClip1(cvarShotCount:GetInt())

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
    self:EmitSound(self.Primary.Sound1, 75, 100, 1, CHAN_VOICE)
    self:EmitSound(self.Primary.Sound2, 125, 100, 1, CHAN_VOICE2)
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    if CLIENT then return end

    SuppressHostEvents(NULL)

    local t = calculateTrajectory(
        self:GetOwner():GetShootPos(),
        self:GetOwner():EyeAngles(),
        10000,
        { self:GetOwner() }
    )

    self:GetOwner():LagCompensation(true)

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
        self:GetOwner():FireBullets(bullet)

        table.insert(trails, { trace.StartPos, trace.HitPos })

        if trace.Hit then
            -- scorch mark
            util.Decal("FadingScorch", trace.HitPos + trace.HitNormal, trace.HitPos - trace.HitNormal)

            -- bounce sound
            EmitSound(Sound("weapons/ric1.wav"), trace.HitPos)

            -- sparks
            local effectData = EffectData()
            effectData:SetOrigin(trace.HitPos)
            effectData:SetNormal(trace.HitNormal)
            util.Effect("ManhackSparks", effectData)
        end
    end

    if cvarShotTrailTime:GetFloat() > 0 then
        net.Start("ttt_ricochet_trail")
        net.WriteInt(#trails, 8)
        for _, v in ipairs(trails) do
            net.WriteVector(v[1])
            net.WriteVector(v[2])
        end
        net.Broadcast()
    end

    SuppressHostEvents(self:GetOwner())
    self:GetOwner():LagCompensation(false)
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

function SWEP:AdjustMouseSensitivity()
    if SERVER or self.ZoomDisplay < 1 then return end

    return math.min(100 / self.ZoomDisplay, 1)
end

function SWEP:AddToSettingsMenu(parent)
    local form = vgui.CreateTTT2Form(parent, "header_equipment_additional")

    form:MakeHelp({
        label = "ttt_ricochet_nonbouncedamage_help"
    })
    form:MakeSlider({
        serverConvar = "ttt_ricochet_nonbouncedamage",
        label = "ttt_ricochet_nonbouncedamage_name",
        min = 0,
        max = 200,
        decimal = 0
    })
    form:MakeHelp({
        label = "ttt_ricochet_maxbounces_help"
    })
    form:MakeSlider({
        serverConvar = "ttt_ricochet_maxbounces",
        label = "ttt_ricochet_maxbounces_name",
        min = 0,
        max = 50,
        decimal = 0
    })
    form:MakeHelp({
        label = "ttt_ricochet_shottrail_help"
    })
    form:MakeSlider({
        serverConvar = "ttt_ricochet_shottrail",
        label = "ttt_ricochet_shottrail_name",
        min = 0,
        max = 20,
        decimal = 1
    })
    form:MakeHelp({
        label = "ttt_ricochet_bounceoffplayers_help"
    })
    form:MakeComboBox({
        serverConvar = "ttt_ricochet_hitplayeraction",
        label = "ttt_ricochet_bounceoffplayers_name",
        choices = {
            { title = "ttt_ricochet_hitplayeraction_stop",     value = HITPLAYERACT_STOP },
            { title = "ttt_ricochet_hitplayeraction_bounce",   value = HITPLAYERACT_BOUNCE },
            { title = "ttt_ricochet_hitplayeraction_continue", value = HITPLAYERACT_CONTINUE }
        }
    })
    form:MakeHelp({
        label = "ttt_ricochet_shotcount_help"
    })
    form:MakeSlider({
        serverConvar = "ttt_ricochet_shotcount",
        label = "ttt_ricochet_shotcount_name",
        min = 1,
        max = 10,
        decimal = 0
    })
end

function SWEP:DrawHUD()
    if not self:GetIronsights() then return end

    local w = ScrW()
    local h = ScrH()
    local scope = surface.GetTextureID("sprites/scope")

    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawLine(0, h / 2, w, h / 2)
    surface.DrawLine(w / 2, 0, w / 2, h)
    surface.DrawRect(0, 0, (w - h) / 2, h)
    surface.DrawRect((w + h) / 2, 0, (w - h) / 2, h)

    surface.SetTexture(scope)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect((w - h) / 2, 0, h, h)

    local bounces = self.LastTraces and #self.LastTraces - 1 or 0
    local text = language.GetPhrase("ttt_ricochet_scopeinfo"):format(self.ZoomDisplay, bounces, cvarMaxBounces:GetInt())
    draw.DrawText(text, "HudDefault", w / 2 + 22, h / 2 + 22, Color(0, 0, 0, 255))
    draw.DrawText(text, "HudDefault", w / 2 + 20, h / 2 + 20, COLOR_WHITE)
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
    hook.Add("CreateMove", "ttt_ricochet", function(cmd)
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
    hook.Add("PlayerBindPress", "ttt_ricochet", function(_, bind, pressed)
        if not pressed or not playerIsHoldingZoomedDeadshot(LocalPlayer()) then return end

        if bind == "invprev" or bind == "invnext" then
            return true
        end
    end)

    ---@type {from: Vector, to: Vector, timeStarted: number, timeEnd: number}[]
    local ricochetTrails = {}
    local deathTime = nil
    net.Receive("ttt_ricochet_trail", function()
        local killshot = not LocalPlayer():Alive() and (deathTime == nil or deathTime + 0.5 > CurTime())
        local count = net.ReadInt(8)

        for i = 1, count do
            local from = net.ReadVector()
            local to = net.ReadVector()

            table.insert(ricochetTrails, {
                from = from,
                to = to,
                timeStarted = CurTime(),
                timeEnd = CurTime() +
                    (killshot and 45 or cvarShotTrailTime:GetFloat()) +
                    i * 0.2,
                killshot = killshot and true or nil
            })
        end
    end)
    hook.Add("PostDrawTranslucentRenderables", "ttt_ricochet", function()
        for k, v in pairs(ricochetTrails) do
            if v.timeEnd < CurTime() then
                ricochetTrails[k] = nil
            else
                local s = (v.timeEnd - CurTime()) / (v.timeEnd - v.timeStarted)

                render.SetColorMaterial()
                render.SetMaterial(
                    v.killshot and Material("trails/laser") or Material("trails/smoke"))
                render.DrawBeam(v.from, v.to, s * 16, 0, 0,
                    v.killshot and Color(255, 0, 0, 255) or Color(200, 200, 200, 255 * s))
            end
        end
    end)

    hook.Add("CalcView", "ttt_ricochet", function(ply, origin, angles)
        if not playerIsHoldingZoomedDeadshot(ply) then return end

        -- Needs to be in hook to allow for rendering player model
        local wep = ply:GetActiveWeapon()
        local t = calculateTrajectory(origin, angles, wep.Zoom, { ply })
        wep.LastTraces = t.traces
        return {
            origin = t.pos,
            angles = t.ang,
            drawviewer = wep.Zoom > 20
        }
    end)


    hook.Add("Think", "ttt_ricochet", function()
        if LocalPlayer():Alive() then
            deathTime = nil
        elseif deathTime == nil then
            deathTime = CurTime()
        end
    end)
end
--#endregion

-- Scope:
-- Pitch indicator
-- Yaw
-- Warning: Reduced damage on low bounce
