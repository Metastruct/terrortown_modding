-- Add workshop addons here to fix custom content they use not showing up properly for players
-- THIS DOESN'T INSTALL ADDONS ONTO THE SERVER, it only adds them to the client download list
-- Not every addon needs adding to this list - if an addon uses custom content that is missing (eg. UI icons are black/purple), add it here

local addons = {
	"1357204556",	-- TTT2
	"105875340",	-- Jihad Bomb
	"254177214",	-- Jihad Bomb fix?
	"654570222",	-- Banana Bomb
	"481692085",	-- Super Discobombulator
	"959443907",	-- Detective Taser
	"1473581448",	-- Death Faker
	"1599710095",	-- Kamehameha
	"2669390710",	-- Defector Role
	"2133752484",	-- Executioner Role
	"1361602585",	-- Vampire Role
	"2480382394", 	-- Impostor Role
	"2620700649", 	-- Sacrifice Role
	"1959850321", 	-- Occultist Role
	"2086831737", 	-- Medigun (for the Medic role)
	"3048226332", 	-- Green Demon
	"2846938449", 	-- Kiss
	"1641605106", 	-- Beartrap
	"1615324913", 	-- Demonic Possession
	"2807269633", 	-- Laser Phaser
	"2893718679",	-- Cozy Coupe simfphys car
	"3003509443",	-- Detective Toy Car (Cozy Coupe)
	"3166539189",	-- Spring Mine
	"3274577332",	-- Janitor Role
	"3021464449",	-- Glue Trap
	"1128856824",	-- Chainsaw
}

for _, id in ipairs(addons) do
	resource.AddWorkshop(id)
end