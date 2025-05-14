AddCSLuaFile()
if SERVER then return end

local IS_TTT2 = GAMEMODE.TTT2CheckFindCredits and true or false

-- Variables
local color_bar_front       = Color( 0, 75, 255, 155 )
local color_bar_back        = Color( 24, 24, 24, 100 )
local color_bar_max         = Color( 0, 0, 255, 64 )
local color_bar_depleted    = Color( 255, 0, 0, 155 )
local color_text            = Color( 255, 255, 255, 180 )

-- Legacy
local function draw_hud_legacy( self, charge_count, charge_max )
    charge_max = ( charge_count > 0 ) and charge_count or charge_max

    local charge_ratio = self.Charge.Current / charge_max
    local charge_max_ratio = self.Charge.Maximum / charge_max

    local x, y = ( ScrW() * 0.50 ), ( ScrH() * 0.65 )
    local w, h = 200, 20

    x = ( x - ( w * 0.5 ) )

    surface.SetDrawColor( color_bar_back )
    surface.DrawRect( x, y - h, w, h )

    surface.SetDrawColor( color_bar_max )
    surface.DrawRect( x, y - h, w * charge_max_ratio, h )

    surface.SetDrawColor( ( charge_max_ratio > 0 ) and color_bar_back or color_bar_depleted )
    surface.DrawOutlinedRect( x, y - h, w, h )

    surface.SetDrawColor( color_bar_front )
    surface.DrawRect( x, y - h, w * charge_ratio, h )

    surface.SetFont( "TabLarge" )
    surface.SetTextColor( color_text )
    surface.SetTextPos( x + 3, y - h - 15 )
    surface.DrawText( "CHARGE" )

    if ( charge_count > 0 ) then
        surface.SetTextPos( x + 3, y + h - 15 )
        surface.DrawText( "(" .. self.Charge.Current .. "/" .. charge_count .. ")" )
    end
end

-- TTT2
local function draw_hud_ttt2( self, charge_count, charge_max ) -- Example used: https://github.com/Metastruct/terrortown_modding/blob/e031541902dd6d48d3b14d0a3817805fe4140141/lua/weapons/weapon_ttt_brick.lua
    charge_max = ( charge_count > 0 ) and charge_count or charge_max
    
    local charge_ratio = self.Charge.Current / charge_max
    local charge_max_ratio = self.Charge.Maximum / charge_max

    local color_bar_outline = ( charge_max_ratio > 0 ) and color_bar_back or color_bar_depleted

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
    draw.OutlinedShadowedBox( x, y, w, h, scale, color_bar_outline )
    draw.Box( x, y, w * charge_ratio, h, color_bar_front )

    if ( charge_count > 0 ) then
        draw.AdvancedText(
            "(" .. self.Charge.Current .. "/" .. charge_count .. ")",
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
end

return IS_TTT2 and draw_hud_ttt2 or draw_hud_legacy