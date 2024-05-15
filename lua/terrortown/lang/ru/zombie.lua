local L = LANG.GetLanguageTableReference("ru")

-- GENERAL ROLE LANGUAGE STRINGS
L[ZOMBIE.name] = "Зомби"
L["info_popup_" .. ZOMBIE.name] = [[Теперь ваш ход! Инфицируйте их всех, убивая их.]]
L["body_found_" .. ZOMBIE.abbr] = "Они были зомби!"
L["search_role_" .. ZOMBIE.abbr] = "Этот человек был зомби!"
L["target_" .. ZOMBIE.name] = "Зомби"
L["ttt2_desc_" .. ZOMBIE.name] = [[Зомби должен заразить каждого игрока, чтобы победить. Они заражают других игроков, убивая их.
Если игрок заражается, он становится зомби и может заразить других игроков. Это позволяет зараженным накопить целую армию.

Если есть Шут, не стесняйтесь заражать его.]]
