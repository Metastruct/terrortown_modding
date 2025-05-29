AddCSLuaFile()
if SERVER then return end

-- Variables
local color_bar_front       = Color( 0, 0, 255, 64 )
local color_bar_back        = Color( 24, 24, 24, 100 )
local color_bar_max         = Color( 0, 75, 255, 155 )
local color_bar_depleted    = Color( 255, 0, 0, 155 )
local color_bar_overcharge  = Color( 255, 0, 50, 255 )
local color_text            = Color( 255, 255, 255, 180 )

-- Legacy
local function draw_hud_legacy( self )
    local charge_count = self:Clip1()
    local charge_max = self:GetMaxClip1()

    local charge_ratio = math.min( 
        1.0,
        1.0 - ( ( self:GetNextPrimaryFire() - CurTime() ) / self.Primary.Delay )
    )

    local charge_max_ratio = charge_count / charge_max

    local color_bar_outline = ( charge_max_ratio > 0 ) and color_bar_back or color_bar_depleted

    if ( self.Timer.Overcharge > 0 ) then
        color_bar_overcharge.a = math.abs( math.sin( CurTime() * math.pi * 2.0 ) * 255 )
        color_bar_outline = color_bar_overcharge
    end

    local x, y = ( ScrW() * 0.50 ), ( ScrH() * 0.65 )
    local w, h = 200, 20

    x = ( x - ( w * 0.5 ) )
    y = y - h

    surface.SetDrawColor( color_bar_back )
    surface.DrawRect( x, y, w, h )

    if ( charge_count > 0 ) then
        surface.SetDrawColor( color_bar_front )
        surface.DrawRect( x, y, w * charge_ratio, h )
    end

    surface.SetDrawColor( color_bar_max )
    surface.DrawRect( x, y, w * charge_max_ratio, h )

    surface.SetDrawColor( color_bar_outline )
    surface.DrawOutlinedRect( x, y, w, h )

    surface.SetFont( "TabLarge" )
    surface.SetTextColor( color_text )
    surface.SetTextPos( x + 3, y - 15 )
    surface.DrawText( "CHARGE" )

    surface.SetTextPos( x + 3, y + ( h * 2 ) - 15 )
    surface.DrawText( "(" .. charge_count .. "/" .. charge_max .. ")" )
end

-- TTT2
local function draw_hud_ttt2( self ) -- Example used: https://github.com/Metastruct/terrortown_modding/blob/e031541902dd6d48d3b14d0a3817805fe4140141/lua/weapons/weapon_ttt_brick.lua
    local charge_count = self:Clip1()
    local charge_max = self:GetMaxClip1()

    local charge_ratio = math.min( 
        1.0,
        1.0 - ( ( self:GetNextPrimaryFire() - CurTime() ) / self.Primary.Delay )
    )

    local charge_max_ratio = charge_count / charge_max

    local color_bar_outline = ( charge_max_ratio > 0 ) and color_bar_back or color_bar_depleted

    if ( self.Timer.Overcharge > 0 ) then
        color_bar_overcharge.a = math.abs( math.sin( CurTime() * math.pi * 2.0 ) * 255 )
        color_bar_outline = color_bar_overcharge
    end

    local scale = appearance.GetGlobalScale()
    local x, y  = ( ScrW() * 0.50 ), ( ScrH() * 0.65 )
    local w, h  = 200 * scale, 20 * scale

    x = ( x - ( w * 0.5 ) )
    y = ( y - h )

    draw.AdvancedText(
        "CHARGE",
        "PureSkinBar",
        x,
        y,
        color_text,
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_BOTTOM,
        true,
        scale
    )

    draw.Box( x, y, w, h, color_bar_back )
    draw.Box( x, y, w * charge_max_ratio, h, color_bar_max )
    if ( charge_count > 0 ) then  draw.Box( x, y, w * charge_ratio, h, color_bar_front ) end
    draw.OutlinedShadowedBox( x, y, w, h, scale, color_bar_outline )

    draw.AdvancedText(
        "(" .. charge_count .. "/" .. charge_max .. ")",
        "PureSkinBar",
        x,
        y + h * 2,
        color_text,
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_BOTTOM,
        true,
        scale
    )
end

return TTT2 and draw_hud_ttt2 or draw_hud_legacy