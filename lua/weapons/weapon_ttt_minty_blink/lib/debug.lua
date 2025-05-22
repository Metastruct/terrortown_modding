-- SPDX-License-Identifier: BSD-3-Clause

AddCSLuaFile()

local _m = {}
local _d = debugoverlay

-- Variables
local collision_checks  = 0
local ledge_checks      = 0

_m.enabled              = false

-- Functions
function _m.aim_trace( marker_trace, ground_trace, ledge_trace, final_trace )
    if SERVER or not _m.enabled then return end
    
    local debug_scr_x           = ( 1.0 / ( CLIENT and ScrW() or 1.0 ) ) * 12
    local debug_scr_h_ratio     = 1.0 / ( CLIENT and ScrH() or 1.0 )
    local debug_marker_hit_wall = ( marker_trace.Hit and math.abs( marker_trace.HitNormal.z ) < 0.15 )
    local debug_marker_type     = debug_marker_hit_wall and ( ledge_trace and "ledge" or "wall" ) or "floor"
    
    -- Title
    _d.ScreenText( debug_scr_x, 0.5, "(BLINK)", 0.1 )

    -- Marker
    _d.Cross( marker_trace.HitPos + marker_trace.HitNormal * 16, 2, 0.1, Color( 0, 0, 255 ) )
    _d.Line( marker_trace.HitPos, marker_trace.HitPos + marker_trace.HitNormal * 16, 0.1, Color( 0, 0, 255 ) )
    _d.Text( marker_trace.HitPos + marker_trace.HitNormal * 8, "Marker (" ..  debug_marker_type .. ")", 0.1 )
    _d.ScreenText( debug_scr_x, 0.5 + debug_scr_h_ratio * 12, "Marker: type = " .. debug_marker_type .. ", position = " .. tostring( marker_trace.HitPos ) .. ", normal = " .. tostring( marker_trace.HitNormal ), 0.1 )

    -- Ledge
    if ledge_trace then
        _d.ScreenText( debug_scr_x, 0.5 + debug_scr_h_ratio * 24, "Ledge: checks = " .. ledge_checks .. ", position = " .. tostring( ledge_trace.StartPos ), 0.1 )
    else
        _d.ScreenText( debug_scr_x, 0.5 + debug_scr_h_ratio * 24, "Ledge: checks = " .. ledge_checks .. ", position = nil", 0.1 )
    end

    -- Ground
    _d.Cross( ground_trace.HitPos + ground_trace.HitNormal * 16, 2, 0.1, Color( 255, 127, 0 ) )
    _d.Line( ground_trace.HitPos, ground_trace.HitPos + ground_trace.HitNormal * 16, 0.1, Color( 255, 127, 0 ) )
    _d.Text( ground_trace.HitPos + ground_trace.HitNormal * 8, "Ground", 0.1 )
    _d.ScreenText( debug_scr_x, 0.5 + debug_scr_h_ratio * 36, "Ground: position = " .. tostring( ground_trace.HitPos ) .. ", normal = " .. tostring( ground_trace.HitNormal ), 0.1 )

    -- Final
    if final_trace then
        _d.ScreenText( debug_scr_x, 0.5 + debug_scr_h_ratio * 48, "Collision: checks = " .. tostring( collision_checks ) .. ", position = " .. tostring( final_trace.HitPos ), 0.1 )
    else
        _d.ScreenText( debug_scr_x, 0.5 + debug_scr_h_ratio * 48, "Collision: checks = " .. tostring( collision_checks ) .. ", position = nil", 0.1 )
    end

    collision_checks    = 0
    ledge_checks        = 0
end

function _m.collision_check( player_trace )
    if SERVER or not _m.enabled then return end

    collision_checks = collision_checks + 1

    if not player_trace.Hit then
        _d.Cross( player_trace.HitPos, 4, 0.1, Color( 0, 127, 255 ) )
        _d.Text( player_trace.HitPos, "Target", 0.1 )
    else
        _d.Cross( player_trace.HitPos, 2, 0.1, Color( 255, 0, 0 ) )
    end
end

function _m.ledge_check( ledge_trace )
    if SERVER or not _m.enabled then return end

    ledge_checks = ledge_checks + 1
    
    if not ledge_trace.Hit then
        _d.Cross( ledge_trace.StartPos, 2, 0.1, Color( 255, 0, 255 ) )
        _d.Line( ledge_trace.StartPos, ledge_trace.StartPos + ledge_trace.Normal * 8, 0.1, Color( 255, 0, 255 ) )
        _d.Text( ledge_trace.HitPos, "Ledge", 0.1 )
    else
        _d.Cross( ledge_trace.StartPos, 2, 0.1, Color( 255, 0, 127 ) )
        _d.Line( ledge_trace.StartPos, ledge_trace.StartPos + ledge_trace.Normal * 8, 0.1, Color( 255, 0, 127 ) )
    end
end

return _m