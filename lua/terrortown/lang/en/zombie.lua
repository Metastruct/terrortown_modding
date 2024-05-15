local L = LANG.GetLanguageTableReference("en")

-- GENERAL ROLE LANGUAGE STRINGS
L[ZOMBIE.name] = "Zombie"
L["info_popup_" .. ZOMBIE.name] = [[Now it's your turn! Infect them all by killing them.]]
L["body_found_" .. ZOMBIE.abbr] = "They were a Zombie!"
L["search_role_" .. ZOMBIE.abbr] = "This person was a Zombie!"
L["target_" .. ZOMBIE.name] = "Zombie"
L["ttt2_desc_" .. ZOMBIE.name] = [[The Zombie needs to infect every player to win. They infect other players by killing them.
If a player gets infected, they become a zombie and are able to infect other players. This allows the infected to build up a whole army.

If there is a Jester, feel free to infect them.]]