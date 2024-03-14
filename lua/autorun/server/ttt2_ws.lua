local list = {
	"1357204556",	-- TTT2
	"2586573261",	-- Huh
	"105875340",	-- Jihad Bomb
	"254177214",	-- Jihad Bomb fix?
	"654570222",	-- Banana Bomb
	"2730454615",	-- Kobold Hoarder
	"481692085",	-- Super Discobombulator
	"959443907",	-- Detective Taser
	"1473581448",	-- Death Faker
	"1599710095",	-- Kamehameha
	"1777819207",	-- Marker Role
	"2133752484",	-- Executioner Role
	"2480382394", 	-- impostor role
	"2756749225", 	-- astronaut role
	"2620700649", 	-- sacrefice role
	"2594893673", 	-- nova role
	"3048226332", 	-- green demon
	"2846938449", 	-- kiss weapon
	"1641605106", 	-- beartrap addon
	"1615324913", 	-- demonic possession
}

for _, id in ipairs(list) do 
	resource.AddWorkshop(id)
end
