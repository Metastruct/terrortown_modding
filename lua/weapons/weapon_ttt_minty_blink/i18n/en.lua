AddCSLuaFile()
if SERVER then return end

local add = LANG.AddToLanguage

-- Generic
add( "en", "ttt_minty_blink_name", "Blink" )
add( "en", "ttt_minty_blink_description", "Woosh woosh.\n\nPrimary: Hold to target.\nSecondary: Cancel targeting." )
add( "en", "ttt_minty_blink_help_primary", "Hold to target, release to blink" )
add( "en", "ttt_minty_blink_help_secondary", "Cancel targeting" )

-- Settings
add( "en", "ttt_minty_blink_charge_count_help", "Blink charge count. Enables 'limited' mode if non-negative and non-zero." )
add( "en", "ttt_minty_blink_charge_count_name", "Amount of charges" )
add( "en", "ttt_minty_blink_charge_cost_help", "Cost per blink charge (does not affect 'limited' mode)." )
add( "en", "ttt_minty_blink_charge_cost_name", "Charge cost" )
add( "en", "ttt_minty_blink_charge_max_help", "Maximum charge (does not affect 'limited' mode)." )
add( "en", "ttt_minty_blink_charge_max_name", "Maximum charge" )
add( "en", "ttt_minty_blink_charge_exhaust_scalar_help", "Relative amount of capped maximum charge to deplete, if blink is used when not fully recharged." )
add( "en", "ttt_minty_blink_charge_exhaust_scalar_name", "Charge exhaust scalar" )
add( "en", "ttt_minty_blink_charge_recharge_rate_help", "Recharge rate, in charge/sec (does not affect 'limited' mode)." )
add( "en", "ttt_minty_blink_charge_recharge_rate_name", "Recharge rate" )
add( "en", "ttt_minty_blink_range_help", "Maximum blink distance." )
add( "en", "ttt_minty_blink_range_name", "Maximum distance" )
add( "en", "ttt_minty_blink_post_process_help", "Enables/disables post-processing effects while targeting." )
add( "en", "ttt_minty_blink_post_process_name", "Enable post-processing" )
