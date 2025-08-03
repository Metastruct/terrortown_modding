-- Prop info for prop kills by Twist

local tag = "TTTPropKillBodyInfo"

if SERVER then
	resource.AddFile("materials/vgui/ttt/icon_props.vtf")

	hook.Add("DoPlayerDeath", tag, function(pl, attacker, dmgInfo)
		-- Define it as nil here - even if it has no data by the end, we still want to overwrite the field on the player
		local crushData

		if dmgInfo:IsDamageType(DMG_CRUSH) then
			local inflictor = dmgInfo:GetInflictor()

			if IsValid(inflictor) and not inflictor:IsWeapon() then
				crushData = {
					isPl = inflictor:IsPlayer() or nil,
					isRag = inflictor:IsRagdoll() and (CORPSE.IsValidBody(inflictor) or inflictor:GetModel():lower():StartsWith("models/player/")) or nil
				}

				if not (crushData.isPl or crushData.isRag) then
					local mdl = inflictor:GetModel():lower()

					-- Strip away "models/" and ".mdl" to save space for the NWString
					crushData.mdl = mdl:StartsWith("*") and mdl or mdl:sub(8, -5)
				end
			end
		end

		pl.crush_death_info = crushData
	end)

	hook.Add("TTTOnCorpseCreated", tag, function(rag, pl)
		if not IsValid(rag) then return end

		if istable(pl.crush_death_info) then
			rag:SetNWString("crush_death_info", util.TableToJSON(pl.crush_death_info))

			pl.crush_death_info = nil
		end
	end)
else
	local propTexts = {}
	local propTextCache = {}

	local function addPropText(match, name)
		propTexts[#propTexts + 1] = { match = match, name = name }
	end

	local function getPropText(modelPath)
		if modelPath:StartsWith("*") then
			return "the map"
		end

		local text = propTextCache[modelPath]
		if text then
			return text
		end

		for i = 1, #propTexts do
			local data = propTexts[i]
			local match = data.match

			if istable(match) then
				for x = 1, #match do
					if modelPath:match(match[x]) then
						propTextCache[modelPath] = data.name
						return data.name
					end
				end
			else
				if modelPath:match(match) then
					propTextCache[modelPath] = data.name
					return data.name
				end
			end
		end

		text = string.format("something called a \"%s\"", modelPath:GetFileFromFilename())

		propTextCache[modelPath] = text
		return text
	end

	---- I am sorry it has to be done like this :murderousintent:

	-- Common litter/construction/misc props
	addPropText("gascan", "a gas can")
	addPropText({ "/canister0", "canister_?propane", "propane_?canister", "propane_?tank", "butane_can" }, "a gas canister")
	addPropText("bluebarrel00", "a water barrel")
	addPropText("oil_?drum", "a barrel")
	addPropText({ "wood_?barrel", "wine_barrel" }, "a wooden barrel")
	addPropText({ "wood_?crate", "crate_extrasmallmill", "item_item_crate", "item_beacon_crate" }, "a wooden crate")
	addPropText({ "cardboard_box0", "/file_box", "takeoutcarton", "/box01[ab]$" }, "a cardboard box")
	addPropText({ "wood_?pallet", "/pallet0", "stack_?pallet" }, "a wooden pallet")
	addPropText({ "cinderblock", "cynderblock" }, "a cinder block")
	addPropText({ "metal_?bucket", "plastic_?bucket" }, "a bucket")
	addPropText({ "paint_?bucket", "paint_?can" }, "a paint bucket")
	addPropText("/ibeam", "a metal beam")
	addPropText({ "sign_?pole", "metal_?pole" }, "a metal pole")
	addPropText({ "track_?sign", "street_?sign", "sign_?letter", "ravenholmsign" }, "a sign")
	addPropText({ "traffic_?cone", "orange_?cone" }, "a cone")
	addPropText("vending_?machine", "a vending machine")
	addPropText("props_c17/metalpot001", "a cooking pot")
	addPropText({ "props_c17/metalpot002", "props_interiors/pot02a$" }, "a pan")
	addPropText("props_interiors/pot01a$", "a kettle")
	addPropText("sawblade", "a saw blade")
	addPropText("/harpoon", "a harpoon")
	addPropText("/meathook", "a meat hook")
	addPropText({ "trash_?bin", "trash_?can", "garbage_?can" }, "a trash bin")
	addPropText({ "trashdumster01a", "trashdumster02$" }, "a dumpster")
	addPropText("trashdumster02b$", "a dumpster cover")
	addPropText({ "/tire0", "carparts_tire" }, "a tire")
	addPropText("carparts_wheel", "a wheel")
	addPropText("wheel?barrow", "a wheelbarrow")
	addPropText({ "pushcart", "laundry_cart" }, "a push cart")
	addPropText("cashregister", "a cash register")
	addPropText("shovel", "a shovel")
	addPropText("bicycle", "a bicycle")
	addPropText({ "/briefcase", "/suitcase" }, "a suitcase")
	addPropText("/plasticcrate", "a plastic crate")
	addPropText("garbage_?bag", "a bag of something")
	addPropText({ "metalcan0", "beancan" }, "a tin can")
	addPropText({ "glass_?bottle", "glassjug", "cs_militia/bottle0" }, "a glass bottle")
	addPropText({ "plastic_?bottle", "water_?bottle" }, "a plastic bottle")
	addPropText("soap_?dispenser", "a bottle of soap")
	addPropText("milk_?carton", "a carton of milk")
	addPropText("coffee_?mug", "a coffee mug")
	addPropText("airboat$", "an airboat")
	addPropText("boat%d*[ab]?$", "a boat")
	addPropText("boat%d*[ab]?_chunk", "a piece of a boat")
	addPropText("^buggy$", "a jeep")
	addPropText({ "/car0", "/van0", "/truck0", "/vehicle_" }, "a vehicle")
	addPropText("/wagon0", "a wagon")
	addPropText({ "carparts_axel", "carparts_muffler" }, "a car part")
	addPropText({ "carparts_door", "/vehicle_vandoor" }, "a car door")
	addPropText("/tools_", "a tool")
	addPropText("camera", "a camera")
	addPropText({ "/door0", "/locker_?door", "metal_?door", "props_doors/" }, "a door")
	addPropText({ "/door_fence0", "props_wasteland/interior_fence001g$", "props_wasteland/exterior_fence003b$" }, "a wirefence gate")
	addPropText("barricade0", "a barricade")
	addPropText("cargo_container", "a cargo container")
	addPropText({ "/dockplank", "/wood_board" }, "a plank of wood")
	addPropText("props_lab/binder", "a book")
	addPropText("/jar0", "a jar")
	addPropText("/basketball", "a basketball")
	addPropText("cs_militia/axe", "an axe")
	addPropText("cs_militia/caseofbeer", "beer")
	addPropText("/circularsaw", "a saw")
	addPropText("/microwave", "a microwave")
	addPropText("/toaster", "a toaster")
	addPropText("dvd_?player", "a DVD player")
	addPropText("/vcr%d*$", "a VCR")
	addPropText("fire_extinguisher", "a fire extinguisher")
	addPropText("/ashtray", "an ashtray")
	addPropText("/paper_towels", "paper towels")
	addPropText("toilet_?paper", "toilet paper")
	addPropText({ "props_c17/frame0", "cs_office/offcertificate", "cs_office/offinsp", "cs_office/offpainting", "de_inferno/picture", "/picture_?frame" }, "a picture frame")
	addPropText("/concrete.*_chunk", "a piece of concrete")
	addPropText("/metal_panel", "a metal sheet")
	addPropText("/machete", "a machete")
	addPropText("/pokerchips", "some poker chips")
	addPropText("/wineglass", "a wine glass")
	addPropText("casino/dishlid", "a serving dish")
	addPropText("/goldbar", "a gold bar")

	-- Furniture
	addPropText("furniture_?mattress", "a mattress")
	addPropText({ "furniture_?bed", "prison_bedframe" }, "a bed frame")
	addPropText({ "furniture_?table", "cafeteria_?table", "/table_", "wood_?table", "de_inferno/table", "booth_?table", "tablecafe", "coffee_?table" }, "a table")
	addPropText({ "furniture_?desk", "furniture_?vanity", "controlroom_desk", "/desk%d*$" }, "a desk")
	addPropText({ "furniture_?chair", "/chair%d+%l?$", "controlroom_chair", "patio_?chair", "stacking_?chair", "chair_?cafeteria", "hotel_?chair", "chair_?thonet", "chair_?lobby", "plastic_?chair", "luxurychair" }, "a chair")
	addPropText({ "chair_?office", "breenchair" }, "an office chair")
	addPropText({ "chair_?stool", "barstool" }, "a stool")
	addPropText({ "furniture_?couch", "/couch%d*$", "/sofa%d*$", "sofa_chair" }, "a couch")
	addPropText({ "wood_?bench", "bench0" }, "a bench")
	addPropText("furniture_?drawer", "a drawer")
	addPropText("furniture_?dresser", "a dresser")
	addPropText({ "furniture_?shelf", "shelfunit01a$" }, "a bookshelf")
	addPropText({ "furniture_?lamp", "desklamp0", "/lamp%d*$" }, "a lamp")
	addPropText({ "furniture_?fridge", "refrigerator", "mini_?fridge", "fridge_?mini" }, "a fridge")
	addPropText("chandelier", "a chandelier")
	addPropText("radiator", "a radiator")
	addPropText("bathtub", "a bathtub")
	addPropText("washingmachine", "a washing machine")
	addPropText("file_?cabinet", "a filing cabinet")
	addPropText("controlroom_storagecloset", "a storage closet")
	addPropText({ "kitchen_shelf", "prison_shelf" }, "shelving")
	addPropText("keyboard", "a keyboard")
	addPropText("/computer_mouse", "a mouse")
	addPropText({ "/monitor0", "/computer_monitor" }, "a computer monitor")
	addPropText({ "/harddrive0", "/computer_case" }, "a computer")
	addPropText("/printer", "a printer")
	addPropText({ "consolebox0", "/reciever0" }, "a console box")
	addPropText({ "/pottery", "egyptian/pot%d" }, "pottery")
	addPropText("ironing_?board", "an ironing board")
	addPropText("pooltable", "a pool table")
	addPropText({ "/teddy_?bear", "props_fairgrounds/elephant", "props_fairgrounds/giraffe", "props_fairgrounds/alligator" }, "a plush toy")

	-- Nature
	addPropText({ "/fishriver", "/goldfish" }, "a fish")
	addPropText("/pumpkin", "a pumpkin")
	addPropText("/watermelon", "a watermelon")
	addPropText("cs_italy/bananna", "bananas")
	addPropText("cs_italy/orange", "an orange")
	addPropText("terracotta01", "a plant pot")
	addPropText({ "/potted_?plant", "cs_office/plant01", "flower_?barrel" }, "a potted plant")
	addPropText("/cactus", "a cactus")
	addPropText({ "props_junk/rock0", "/rockgranite0", "/rock_caves", "/rock_forest" }, "a rock")

	-- Specific funnies
	addPropText("/cozycoupe", "a funny toy car")
	addPropText("newspaper0", "the news")
	addPropText({ "/radio$", "/citizenradio" }, "the radio")
	addPropText("/gnome$", "that fucking gnome")
	addPropText("/shoe0", "a cool shoe")
	addPropText({ "popcan01", "garbage_sodacan" }, "a refreshing can of soda")
	addPropText("/breenbust$", "a hideous marble bust")
	addPropText("/doll01$", "a baby")
	addPropText("de_tides/vending_turtle$", "a funny little turtle")
	addPropText({ "lifepreserver", "/life_ring" }, "a life preserver, ironically")
	addPropText("gibs/hgibs", "a s-s-skull")
	addPropText({ "/tv_monitor", "/tv_plasma", "props_phx/.*_screen", "/tv%d*$" }, "TV")
	addPropText("/soccerball", "soccer")
	addPropText("/hr_model_xbox$", "XBOX LIVE")
	addPropText("/pizza_box$", "PIZZA")

	hook.Add("TTTBodySearchPopulate", tag, function(searchAdd, raw, scoreboard)
		local rag = raw.rag
		if not IsValid(rag) then return end

		local crushData = rag:GetNWString("crush_death_info")

		crushData = crushData and crushData != "" and util.JSONToTable(crushData) or nil

		if crushData then
			local text
			if crushData.isPl then
				text = "under someone's weight. They've evidently been stomped on"
			elseif crushData.isRag then
				text = "by a flying corpse"
			else
				text = "by " .. getPropText(crushData.mdl)
			end

			searchAdd.crush_death_info = {
				p = 0,
				order = 2,
				img = "vgui/ttt/icon_props",
				title = "Deadly object",
				text = string.format("Looks like they were killed %s.", text)
			}
		end
	end)
end