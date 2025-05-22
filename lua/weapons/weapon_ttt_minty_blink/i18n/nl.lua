AddCSLuaFile()
if SERVER then return end

local add = LANG.AddToLanguage

-- Generic
add( "nl", "ttt_minty_blink_name", "Blink" )
add( "nl", "ttt_minty_blink_description", "Woosh woosh.\n\nPrimair: Houd ingedrukt om te richten.\nSecundair: Richten annuleren." )
add( "nl", "ttt_minty_blink_help_primary", "Houd ingedrukt om te richten, loslaten om te teleporteren" )
add( "nl", "ttt_minty_blink_help_secondary", "Richten annuleren" )

-- Settings
add( "nl", "ttt_minty_blink_charge_count_help", "Totaal aantal teleportaties. Schakelt 'gelimiteerde' modus indien boven nul." )
add( "nl", "ttt_minty_blink_charge_count_name", "Aantal teleportaties" )
add( "nl", "ttt_minty_blink_charge_cost_help", "Kost per teleportatie (heeft geen invloed op 'gelimiteerde' modus)." )
add( "nl", "ttt_minty_blink_charge_cost_name", "Kost per teleportatie" )
add( "nl", "ttt_minty_blink_charge_max_help", "Maximale lading (heeft geen invloed op 'gelimiteerde' modus)." )
add( "nl", "ttt_minty_blink_charge_max_name", "Maximale lading" )
add( "nl", "ttt_minty_blink_charge_exhaust_scalar_help", "Relatieve maximale lading om af te nemen, indien teleportatie gebruikt word terwijl de lading beneden het maximum is." )
add( "nl", "ttt_minty_blink_charge_exhaust_scalar_name", "Relatieve afname lading" )
add( "nl", "ttt_minty_blink_charge_recharge_rate_help", "Oplaadsnelheid, in lading/sec (heeft geen invloed op 'gelimiteerde' modus)." )
add( "nl", "ttt_minty_blink_charge_recharge_rate_name", "Oplaadsnelheid" )
add( "nl", "ttt_minty_blink_range_help", "Maximale afstand teleportatie." )
add( "nl", "ttt_minty_blink_range_name", "Maximum afstand" )
add( "nl", "ttt_minty_blink_post_process_help", "Schakelt visuele nabewerking in/uit gedurende het richten." )
add( "nl", "ttt_minty_blink_post_process_name", "Visuele nabewerking inschakelen" )
