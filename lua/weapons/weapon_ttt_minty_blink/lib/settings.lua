AddCSLuaFile()

return function( self, parent )
    local form = vgui.CreateTTT2Form( parent, "header_equipment_additional" )

    -- ttt_minty_blink_charge_count
    form:MakeHelp({
        label = "ttt_minty_blink_charge_count_help"
    })

    form:MakeSlider({
        serverConvar = "ttt_minty_blink_charge_count",
        label = "ttt_minty_blink_charge_count_name",
        min = 0,
        max = 100,
        decimal = 0
    })

    -- ttt_minty_blink_charge_time
    form:MakeHelp({
        label = "ttt_minty_blink_charge_time_help"
    })

    form:MakeSlider({
        serverConvar = "ttt_minty_blink_charge_time",
        label = "ttt_minty_blink_charge_time_name",
        min = 0,
        max = 30,
        decimal = 2
    })

    -- ttt_minty_blink_overcharge_damage
    form:MakeHelp({
        label = "ttt_minty_blink_overcharge_damage_help"
    })

    form:MakeSlider({
        serverConvar = "ttt_minty_blink_overcharge_damage",
        label = "ttt_minty_blink_overcharge_damage_name",
        min = 0,
        max = 100,
        decimal = 0
    })

    -- ttt_minty_blink_range
    form:MakeHelp({
        label = "ttt_minty_blink_range_help"
    })

    form:MakeSlider({
        serverConvar = "ttt_minty_blink_range",
        label = "ttt_minty_blink_range_name",
        min = 0,
        max = 8192,
        decimal = 0
    })

    -- ttt_minty_blink_post_process
    form:MakeHelp({
        label = "ttt_minty_blink_post_process_help"
    })

    form:MakeCheckBox({
        serverConvar = "ttt_minty_blink_post_process",
        label = "ttt_minty_blink_post_process_name"
    })
end