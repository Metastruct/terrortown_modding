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

    -- ttt_minty_blink_charge_cost
    form:MakeHelp({
        label = "ttt_minty_blink_charge_cost_help"
    })

    form:MakeSlider({
        serverConvar = "ttt_minty_blink_charge_cost",
        label = "ttt_minty_blink_charge_cost_name",
        min = 0,
        max = 100,
        decimal = 0
    })

    -- ttt_minty_blink_charge_max
    form:MakeHelp({
        label = "ttt_minty_blink_charge_max_help"
    })

    form:MakeSlider({
        serverConvar = "ttt_minty_blink_charge_max",
        label = "ttt_minty_blink_charge_cost_name",
        min = 0,
        max = 100,
        decimal = 0
    })

    -- ttt_minty_blink_charge_exhaust_scalar
    form:MakeHelp({
        label = "ttt_minty_blink_charge_exhaust_scalar_help"
    })

    form:MakeSlider({
        serverConvar = "ttt_minty_blink_charge_exhaust_scalar",
        label = "ttt_minty_blink_charge_exhaust_scalar_name",
        min = 0,
        max = 1,
        decimal = 2
    })

    -- ttt_minty_blink_charge_recharge_rate
    form:MakeHelp({
        label = "ttt_minty_blink_charge_recharge_rate_help"
    })

    form:MakeSlider({
        serverConvar = "ttt_minty_blink_charge_recharge_rate",
        label = "ttt_minty_blink_charge_recharge_rate_name",
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
        max = 65535,
        decimal = 0
    })

    -- ttt_minty_blink_charge_count
    form:MakeHelp({
        label = "ttt_minty_blink_post_process_help"
    })

    form:MakeCheckBox({
        serverConvar = "ttt_minty_blink_post_process",
        label = "ttt_minty_blink_post_process_name"
    })
end