local L = LANG.GetLanguageTableReference("es")

-- GENERAL ROLE LANGUAGE STRINGS
L[ZOMBIE.name] = "Zombi"
L["info_popup_" .. ZOMBIE.name] = [[¡Ahora es tu turno! Infecta a todos matándolos.]]
L["body_found_" .. ZOMBIE.abbr] = "¡Era un Zombi!"
L["search_role_" .. ZOMBIE.abbr] = "Esta persona era un Zombi."
L["target_" .. ZOMBIE.name] = "Zombi"
L["ttt2_desc_" .. ZOMBIE.name] = [[El Zombi necesita infectar a todos los jugadores para ganar. Infecta a otros jugadores matándolos.
Si un jugador es infectado, se convierte en un zombi y puede infectar a otros jugadores. Esto permite que los infectados formen todo un ejército.

Si hay un Bufón, siéntete libre de infectarlo.]]