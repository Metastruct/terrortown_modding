local L = LANG.GetLanguageTableReference("de")

-- GENERAL ROLE LANGUAGE STRINGS
L[ZOMBIE.name] = "Zombie"
L["info_popup_" .. ZOMBIE.name] = [[Jetzt bist du dran! Infiziere sie alle, indem du sie tötest.]]
L["body_found_" .. ZOMBIE.abbr] = "Es war ein Zombie!"
L["search_role_" .. ZOMBIE.abbr] = "Diese Person war ein Zombie!"
L["target_" .. ZOMBIE.name] = "Zombie"
L["ttt2_desc_" .. ZOMBIE.name] = [[Der Zombie muss jeden Spieler infizieren, um zu gewinnen. Sie infizieren andere Spieler, indem sie sie töten.
Wenn ein Spieler infiziert wird, wird er zu einem Zombie und kann andere Spieler infizieren. Dadurch können die Infizierten eine ganze Armee aufbauen.

Wenn es einen Spaßmacher gibt, zögere nicht, ihn zu infizieren.]]