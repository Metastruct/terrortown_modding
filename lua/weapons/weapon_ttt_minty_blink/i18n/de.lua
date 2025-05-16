AddCSLuaFile()
if SERVER then return end

local add = LANG.AddToLanguage

-- Generic
add( "de", "ttt_minty_blink_name", "Blink" )
add( "de", "ttt_minty_blink_description", "Woosh woosh.\n\nPrimär: Zum Zielen drücken und halten.\nSekundär: Aufhebung des Zielens")
add( "de", "ttt_minty_blink_help_primary", "Zum Zielen drücken und halten, loslassen zu teleportieren" )
add( "de", "ttt_minty_blink_help_secondary", "Aufhebung des Zielens" )

-- Settings
add( "de", "ttt_minty_blink_charge_count_help", "Gesamtzahl der Teleportationen. Schachelt den Modus 'Begrenzt' ein, wenn über Null." )
add( "de", "ttt_minty_blink_charge_count_name", "Anzahl der Teleportationen" )
add( "de", "ttt_minty_blink_charge_cost_help", "Kosten pro Teleportation (Hat keinen Einfluss auf den Modus 'Begrenzt')." )
add( "de", "ttt_minty_blink_charge_cost_name", "Kosten pro Teleportation" )
add( "de", "ttt_minty_blink_charge_max_help", "Maximalladung (Hat keinen Einfluss auf den Modus 'Begrenzt')." )
add( "de", "ttt_minty_blink_charge_max_name", "Maximalladung" )
add( "de", "ttt_minty_blink_charge_exhaust_scalar_help", "Relative maximale Ladung bis zum Wegnehmen, wenn die Teleportation verwendet wird, während die Ladung unter dem Maximum liegt." )
add( "de", "ttt_minty_blink_charge_exhaust_scalar_name", "Relativer Rückgang der Ladung" )
add( "de", "ttt_minty_blink_charge_recharge_rate_help", "Ladegeschwindigkeit, in Ladung/sek (Hat keinen Einfluss auf den Modus 'Begrenzt')." )
add( "de", "ttt_minty_blink_charge_recharge_rate_name", "Ladegeschwindigkeit" )
add( "de", "ttt_minty_blink_range_help", "Maximale Teleportationsdistanz." )
add( "de", "ttt_minty_blink_range_name", "Maximale Distanz" )
add( "de", "ttt_minty_blink_post_process_help", "Schaltet visuelle Effekte während der Zielerfassung ein/aus." )
add( "de", "ttt_minty_blink_post_process_name", "Visuelle Effekte einschalten" )
