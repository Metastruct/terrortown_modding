-- SPDX-License-Identifier: BSD-3-Clause
-- Version 2.0 (c) 2025 ppr_minty

AddCSLuaFile()

local ENTITY = FindMetaTable( "Entity" )
local PLAYER = FindMetaTable( "Player" )

-- Modules
local effect    = include( "effect.lua" )
local cvar      = include( "cvar.lua" )
local dbg       = include( "debug.lua" )
local lut       = include( "lut.lua" )
local res       = include( "resource.lua" )

-- dbg.enabled     = true

--  Misc
local marker_effect_size    = 10
local marker_effect_rate    = 0.025

local ledge_step_max        = 4
local ledge_step_size       = 8

local trace_hull_size       = 4
local trace_ledge_depth     = 2

local post_process_fade_time    = 0.125
local post_process_class_name   = "weapon_ttt_minty_blink"

-- Info struct
SWEP.Base                   = "weapon_tttbase"

--  Base
SWEP.AutoSpawnable          = false
SWEP.HoldType               = "knife"
SWEP.Kind                   = WEAPON_EQUIP

SWEP.PrintName              = "Blink"
SWEP.Slot                   = 6

SWEP.DrawCrosshair          = false
SWEP.UseHands               = true
SWEP.ViewModel              = "models/weapons/c_slam.mdl"
SWEP.ViewModelFlip          = false
SWEP.ViewModelFOV           = 67
SWEP.WorldModel             = "models/weapons/w_slam.mdl"

SWEP.Primary.Recoil         = 0
SWEP.Primary.ClipSize       = -1
SWEP.Primary.DefaultClip    = -1
SWEP.Primary.Automatic      = false
SWEP.Primary.Delay          = 1
SWEP.Primary.Ammo           = "none"

--  TTT
SWEP.CanBuy                 = { ROLE_TRAITOR }
SWEP.LimitedStock           = true
SWEP.NoSights               = true

SWEP.EquipMenuData          = {
    type = "item_weapon",
    desc = "Woosh woosh.\n\nPrimary: Hold to target\nSecondary: Abort blink"
};

SWEP.Icon                   = res.icon

--  Special
SWEP.Timer      = {
    Particle    = 0,
    Recharge    = 0,
    PostProcess = 0,
}

SWEP.Charge = {
    Current = ( cvar.charge_count:GetInt() > 0 and cvar.charge_count:GetInt() or cvar.charge_max:GetInt() ),
    Maximum = ( cvar.charge_count:GetInt() > 0 and cvar.charge_count:GetInt() or cvar.charge_max:GetInt() ),
}

SWEP.Warp   = {
    Marker  = nil,
    Target  = nil,
    Player  = nil,
}

SWEP.Emitter    = nil
SWEP.State      = nil

-- Logic

--  Default
function SWEP:DryFire() return false end        -- Disable default behaviours
function SWEP:PrimaryAttack() return false end

function SWEP:Initialize()
    self:SetHoldType( self.HoldType )
    
    local charge_max = ( cvar.charge_count:GetInt() > 0 and cvar.charge_count:GetInt() or cvar.charge_max:GetInt() )
    self.Charge.Current = charge_max
    self.Charge.Maximum = charge_max

    if CLIENT then
        self.Emitter = ParticleEmitter( self:GetPos() )
    end

    self.BaseClass.Initialize( self )
end

function SWEP:OwnerChanged()
    self:Blink_ClampCharge()
    self:Blink_ForceReset()

    self.BaseClass.OwnerChanged( self )
end

function SWEP:OnRemove()
    self:Blink_SetTimers()
    if self.Emitter then self.Emitter:Finish() end
end

function SWEP:PreDrawViewModel()
    render.SetBlend( 0 ) -- Hide viewmodel
end

function SWEP:ViewModelDrawn()                  
    render.SetBlend( 1 ) -- Show hands
end

function SWEP:Deploy()
    self:Blink_DoViewModelAnimation()
    return true
end

--  Utility
function SWEP:Blink_SetTimers( particle, recharge, post_process )
    self.Timer.Particle = particle and CurTime() or 0
    self.Timer.Recharge = recharge and CurTime() or 0
    self.Timer.PostProcess = post_process and CurTime() or 0
end

function SWEP:Blink_DoViewModelAnimation()
    local owner = self.Owner
    if not IsValid( owner ) then return end

    local viewmodel = owner:GetViewModel()
    if not IsValid( viewmodel ) then return end

    if SERVER or IsFirstTimePredicted() then
        viewmodel:SendViewModelMatchingSequence( 12 )
    end
end

function SWEP:Blink_DoAimTrace()
    local owner = self.Owner
    if not IsValid( owner ) then return nil end

    local trace_hull = Vector( trace_hull_size, trace_hull_size, trace_hull_size )

    -- Initial trace
    local marker_trace = util.TraceLine( {
        start   = owner:EyePos() + owner:GetAimVector(),
        endpos  = owner:EyePos() + owner:GetAimVector() * cvar.range:GetInt(),
        mask    = MASK_ALL,
        filter  = owner
    } )

    -- Find ledge
    local marker_hit_wall = marker_trace.Hit and math.abs( marker_trace.HitNormal.z ) < 0.15
    local ledge_trace = nil

    if marker_hit_wall then
        for i = 1, ledge_step_max do
            local origin = marker_trace.HitPos + Vector( 0, 0, i * ledge_step_size )
            
            local candidate = util.TraceLine( {
                start   = origin,
                endpos  = origin - ( marker_trace.HitNormal * trace_ledge_depth ),
                mask    = MASK_PLAYERSOLID,
                filter  = owner
            } )

            dbg.ledge_check( candidate )

            if not candidate.Hit then
                ledge_trace = candidate
                break
            end
        end
    end

    -- Find ground
    local ground_trace_origin =
        ledge_trace and ledge_trace.HitPos or 
        marker_hit_wall and ( marker_trace.HitPos + marker_trace.HitNormal * trace_hull_size * 2 ) or
        marker_trace.HitPos

    local ground_trace = util.TraceLine( {
        start   = ground_trace_origin,
        endpos  = ground_trace_origin - Vector( 0, 0, 65535 ),
        mask    = MASK_PLAYERSOLID,
        filter  = owner
    } )

    ground_trace = util.TraceHull( { -- Detect highest point on uneven surface
        start   = ground_trace.HitPos - ( ground_trace.Normal * trace_hull_size ),
        endpos  = ground_trace.HitPos,
        mins    = -trace_hull,
        maxs    = trace_hull,
        mask    = MASK_PLAYERSOLID,
        filter  = owner
    } )

    -- Ensure player fit
    local player_mins, player_maxs = owner:GetCollisionBounds()
    local final_trace = nil

    local origin = ground_trace.HitPos
    local normal = ledge_trace and ledge_trace.Normal or marker_trace.HitNormal
    local angle = normal:Angle()

    local use_lut =
        ledge_trace and lut.ledge or 
        marker_hit_wall and lut.wall or
        lut.floor

    for k, v in pairs( use_lut ) do -- Evaluate points
        local point = Vector( v )
        point:Rotate( angle )
        
        point = ( origin + point * lut.__size )

        local player_trace = util.TraceHull( { 
            start   = point,
            endpos  = point,
            mins    = player_mins,
            maxs    = player_maxs,
            mask    = MASK_PLAYERSOLID,
            filter  = owner,
        } )
        
        dbg.collision_check( player_trace )

        if not player_trace.Hit then
            final_trace = player_trace
            break
        end
    end

    -- Debug
    dbg.aim_trace( marker_trace, ground_trace, ledge_trace, final_trace )

    -- Store variables
    if final_trace then
        self.Warp.Marker = marker_trace.HitPos
        self.Warp.Target = final_trace.HitPos
    else
        self.Warp.Marker = nil
        self.Warp.Target = nil
    end
end

function SWEP:Blink_ClampCharge()
    local charge_count = cvar.charge_count:GetInt()
    local charge_max = ( charge_count > 0 and charge_count or cvar.charge_max:GetInt() )

    if ( self.Charge.Current > charge_max ) then self.Charge.Current = charge_max end
    if ( self.Charge.Maximum > charge_max ) then self.Charge.Maximum = charge_max end
end

function SWEP:Blink_DoRecharge()
    if ( self.Timer.Recharge <= 0 ) then return false end
    local delta_seconds = ( CurTime() - self.Timer.Recharge )

    self:Blink_ClampCharge()
    if ( self.Charge.Current >= self.Charge.Maximum ) then return false end

    local charge_count = cvar.charge_count:GetInt()
    local recharge_amount =
        ( charge_count > 0 ) and 0 or 
        ( cvar.charge_recharge_rate:GetFloat() * delta_seconds )
    
    local new_charge = math.min( self.Charge.Current + recharge_amount, self.Charge.Maximum )

    self.Charge.Current = new_charge
    self.Timer.Recharge = CurTime()

    return true
end

function SWEP:Blink_TakeChargeOnce()
    if ( self.Charge.Current <= 0 ) then return false end
    
    self:Blink_ClampCharge()

    local charge_count = cvar.charge_count:GetInt()
    local charge_cost = ( charge_count > 0 and 1 or cvar.charge_cost:GetInt() )
    
    local penalty_amount = 
        ( charge_count > 0 ) and 1 or
        ( ( self.Charge.Current < self.Charge.Maximum ) and ( charge_cost * cvar.charge_exhaust_scalar:GetFloat() ) or 0 )
    
    local new_charge = math.max( self.Charge.Current - charge_cost, 0 )

    self.Charge.Current = new_charge
    self.Charge.Maximum = math.max( 0, self.Charge.Maximum - penalty_amount )

    return true
end

function SWEP:Blink_ForceReset()
    self:Blink_SetTimers()
    self.Warp.Marker    = nil
    self.Warp.Target    = nil
    self.State          = self.State_Idle
end

--  State machine
function SWEP:State_Idle()
    local owner = self.Owner
    if not IsValid( owner ) then return end

    if owner:KeyDown( IN_ATTACK ) and ( self.Charge.Current > 0 ) then
        -- Emit aim sound
        self:EmitSound(
            res.sound.aim[ math.random( 1, #res.sound.aim ) ],
            75,
            math.random( 95, 105 )
        )

        -- Change state
        self:Blink_SetTimers( false, false, true )
        self.State = self.State_Aim
    else -- owner:KeyDown( IN_ATTACK ) and ( self.Charge.Current > 0 )
        self:Blink_DoRecharge()
    end
end

function SWEP:State_Aim()
    local owner = self.Owner
    if not IsValid( owner ) then return end

    local should_cancel = owner:KeyDown( IN_ATTACK2 )

    if owner:KeyDown( IN_ATTACK ) then
        self:Blink_DoAimTrace()
        effect.Marker( owner, marker_effect_rate, marker_effect_size )
    else -- owner:KeyDown( IN_ATTACK )
        local target = self.Warp.Target

        if target then
            -- Take charge
            if not self:Blink_TakeChargeOnce() then return end

            -- Emit teleport sound
            self:EmitSound(
                res.sound.teleport[ math.random( 1, #res.sound.teleport ) ],
                75,
                math.random( 95, 105 )
            )

            -- Effects
            effect.Dissolve( owner )
            effect.FOV( owner )

            -- Teleport player
            owner:SetPos( target )
            owner:SetLocalVelocity( Vector( 0, 0, 0 ) )

            -- Change state
            self:Blink_SetTimers( false, true, false )
            self.Warp.Marker    = nil
            self.Warp.Target    = nil
            self.State          = self.State_Idle
        else
            -- Released without valid warp target
            should_cancel = true
        end
    end

    if should_cancel then
        -- Change state    
        self:Blink_SetTimers()
        self.Warp.Marker    = nil
        self.Warp.Target    = nil
        self.State          = self.State_Cancel
    end
end

function SWEP:State_Cancel()
    local owner = self.Owner
    if not IsValid( owner ) then return end
    
    if not owner:KeyDown( IN_ATTACK ) and not owner:KeyDown( IN_ATTACK2 ) then
        self:Blink_SetTimers( false, true, false )
        self.State          = self.State_Idle
    end
end

function SWEP:Think()
    if not IsFirstTimePredicted() then return end 

    -- State machine
    if not self.State then self.State = self.State_Idle end
    self.State( self )
end

-- TODO: Cleanup
function SWEP:DrawHUD()
    local x = ( ScrW() / 2.0 )
    local y = ( ScrH() / 2.0 )

    y = ( y + ( y / 3 ) )

    local charge_count = cvar.charge_count:GetInt()
    local charge_max = ( charge_count > 0 ) and charge_count or cvar.charge_max:GetInt()
    local charge_ratio = self.Charge.Current / charge_max
    local charge_max_ratio = self.Charge.Maximum / charge_max

    local w, h = 200, 20

    if charge_max_ratio > 0 then
        surface.SetDrawColor( 0, 0, 255, 78 )
    else
        surface.SetDrawColor( 255, 0, 0, 155 )
    end

    surface.DrawOutlinedRect( x - w/2, y - h, w, h )
    surface.DrawRect( x - w/2, y - h, w * charge_max_ratio, h )

    surface.SetDrawColor( 0, 75, 255, 100 )
    surface.DrawRect( x - w/2, y - h, w * charge_ratio, h )

    surface.SetFont( "TabLarge" )
    surface.SetTextColor( 255, 255, 255, 180 )
    surface.SetTextPos( ( x - w/2 ) + 3, y - h - 15 )
    surface.DrawText( "CHARGE" )

    if ( charge_count > 0 ) then
        local num_total = charge_count
        local num_remaining = math.ceil( charge_max_ratio * num_total )

        surface.SetTextPos( ( x - w/2 ) + 3, y + h - 15 )
        surface.DrawText( "(" .. num_remaining .. "/" .. num_total .. ")" )
    end

    self.BaseClass.DrawHUD( self )
end

-- Post-processing
if CLIENT then
    hook.Remove( "RenderScreenspaceEffects", "Blink_RenderScreenspaceEffects" )
    hook.Add( "RenderScreenspaceEffects", "Blink_RenderScreenspaceEffects", function()
        if ( cvar.post_process:GetInt() > 0 ) and IsValid( LocalPlayer() ) then
            local weapon = LocalPlayer():GetActiveWeapon()

            if IsValid( weapon ) and ( weapon.ClassName == post_process_class_name ) then
                local timer = weapon.Timer.PostProcess

                if ( timer > 0 ) then
                    local scalar = math.max( 0.0, math.min( 1.0, ( CurTime() - timer ) / post_process_fade_time ) )

                    DrawColorModify( { 
                        [ "$pp_colour_brightness" ] = -( scalar * 0.1 ),
                        [ "$pp_colour_contrats" ] = 1.0 + ( scalar * 0.1 ),
                        [ "$pp_colour_colour" ] = 1.0 - ( scalar * 0.75 ),
                    } )
                end
            end
        end
    end )
end