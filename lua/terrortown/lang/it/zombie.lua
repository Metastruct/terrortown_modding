local L = LANG.GetLanguageTableReference("it")

-- GENERAL ROLE LANGUAGE STRINGS
L[ZOMBIE.name] = "Zombie"
L["info_popup_" .. ZOMBIE.name] = [[Ora è il tuo turno! Infetta tutti uccidendoli.]]
L["body_found_" .. ZOMBIE.abbr] = "Era un Zombie!"
L["search_role_" .. ZOMBIE.abbr] = "Questa persona era un Zombie!"
L["target_" .. ZOMBIE.name] = "Zombie"
L["ttt2_desc_" .. ZOMBIE.name] = [[Lo Zombie deve infettare ogni giocatore per vincere. Infetta gli altri giocatori uccidendoli.
Se un giocatore viene infettato, diventa uno zombie e può infettare altri giocatori. Questo consente agli infetti di creare un intero esercito.

Se c'è un Giullare, sentiti libero di infettarlo.]]