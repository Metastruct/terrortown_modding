local L = LANG.GetLanguageTableReference("fr")

-- GENERAL ROLE LANGUAGE STRINGS
L[ZOMBIE.name] = "Zombie"
L["info_popup_" .. ZOMBIE.name] = [[Maintenant, c'est à votre tour ! Infectez-les tous en les tuant.]]
L["body_found_" .. ZOMBIE.abbr] = "C'était un Zombie !"
L["search_role_" .. ZOMBIE.abbr] = "Cette personne était un Zombie !"
L["target_" .. ZOMBIE.name] = "Zombie"
L["ttt2_desc_" .. ZOMBIE.name] = [[Le Zombie doit infecter chaque joueur pour gagner. Il infecte les autres joueurs en les tuant.
Si un joueur est infecté, il devient un zombie et peut infecter d'autres joueurs. Cela permet aux infectés de constituer toute une armée.

S'il y a un Jester, n'hésitez pas à les infecter.]]
