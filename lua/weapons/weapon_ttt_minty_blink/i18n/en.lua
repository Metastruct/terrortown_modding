AddCSLuaFile()
if SERVER then return end

local add = LANG.AddToLanguage

-- Generic
add( "en", "ttt_minty_blink_name", "Blink" )
add( "en", "ttt_minty_blink_description", "Woosh woosh.\n\nPrimary: Hold to target.\nSecondary: Cancel targeting." )
add( "en", "ttt_minty_blink_help_primary", "Hold to target, release to blink" )
add( "en", "ttt_minty_blink_help_secondary", "Cancel targeting" )

-- Settings
add( "en", "ttt_minty_blink_charge_count_help", "Blink charge count." )
add( "en", "ttt_minty_blink_charge_count_name", "Amount of charges" )
add( "en", "ttt_minty_blink_charge_time_help", "Minimum amount of time between blinks, in seconds." )
add( "en", "ttt_minty_blink_charge_time_name", "Charging time" )
add( "en", "ttt_minty_blink_overcharge_damage_help", "Allows blinking when not fully charged, at the cost of player health. Set to '0' to disable." )
add( "en", "ttt_minty_blink_overcharge_damage_name", "Overcharge damage" )
add( "en", "ttt_minty_blink_range_help", "Maximum blink distance." )
add( "en", "ttt_minty_blink_range_name", "Maximum distance" )
add( "en", "ttt_minty_blink_post_process_help", "Enables/disables post-processing effects while targeting." )
add( "en", "ttt_minty_blink_post_process_name", "Enable post-processing" )
