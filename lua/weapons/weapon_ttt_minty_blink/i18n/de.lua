AddCSLuaFile()
if SERVER then return end

local add = LANG.AddToLanguage

-- Generic
add( "de", "ttt_minty_blink_name", "Blink" )
add( "de", "ttt_minty_blink_description", "Woosh woosh.\n\nPrimär: Zum Zielen drücken und halten.\nSekundär: Aufhebung des Zielens")
add( "de", "ttt_minty_blink_help_primary", "Zum Zielen drücken und halten, loslassen zu teleportieren" )
add( "de", "ttt_minty_blink_help_secondary", "Aufhebung des Zielens" )

-- Settings
add( "de", "ttt_minty_blink_charge_count_help", "Gesamtzahl der Teleportationen." )
add( "de", "ttt_minty_blink_charge_count_name", "Anzahl der Teleportationen" )
add( "de", "ttt_minty_blink_charge_time_help", "Mindestzeit zwischen Teleportationen, in Sekunden." )
add( "de", "ttt_minty_blink_charge_time_name", "Ladezeit" )
add( "de", "ttt_minty_blink_overcharge_damage_help", "Ermöglicht Teleportation, wenn sie nicht vollständig aufgeladen ist, auf Kosten der Gesundheit des Spielers. Zum Deaktivieren auf '0' setzen." )
add( "de", "ttt_minty_blink_overcharge_damage_name", "Überladungsschäden" )
add( "de", "ttt_minty_blink_range_help", "Maximale Teleportationsdistanz." )
add( "de", "ttt_minty_blink_range_name", "Maximale Distanz" )
add( "de", "ttt_minty_blink_post_process_help", "Schaltet visuelle Effekte während der Zielerfassung ein/aus." )
add( "de", "ttt_minty_blink_post_process_name", "Visuelle Effekte einschalten" )
