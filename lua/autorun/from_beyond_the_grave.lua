if SERVER then
	util.AddNetworkString("fbg_ghostly_message")
	util.AddNetworkString("fbg_send_template_message")
end

local FBG = _G.FBG or {}
_G.FBG = FBG

FBG.MessageTemplates = {
	-- Classic Dark Souls patterns
	"{action} {object}",
	"{action} {object} {descriptor}",
	"{descriptor} {object} ahead",
	"{object} ahead",
	"Try {action}",
	"Try {action} {object}",
	"{descriptor} {enemy} ahead",
	"{enemy} ahead",
	"Beware of {object}",
	"Beware of {descriptor} {object}",
	"{object} required ahead",
	"Need {object}",
	"{action} required ahead",
	"Time for {action}",
	"If only I had a {object}",
	"Didn't expect {object}",
	"Could this be a {object}?",
	"Is this a {object}?",
	"{object}, O {object}",
	"Praise the {object}!",
	"Amazing {object} ahead",
	"Gorgeous view ahead",
	"Try {action} but hole",
	"Fort, night",
	"Liar ahead",
	"Trap ahead",
	"Ambush ahead",
	"Sniper ahead",
	"Enemy ahead",
	"Tough enemy ahead",
	"Weak foe ahead",
	"Group enemy ahead",
	"Boss ahead",
	"Victory achieved",
	"Defeat",
	"You did it!",
	"Well done",
	"Good luck",
	"Don't give up",
	"Keep going",
	"Turn back",
	"Dead end ahead",
	"Shortcut ahead",
	"Hidden path ahead",
	"Secret ahead",
	"Treasure ahead",
	"Item ahead",
	"Weapon ahead",
	"Armor ahead",
	"Ring ahead",
	"Key ahead",
	"Lever ahead",
	"Switch ahead",
	"Door ahead",
	"Ladder ahead",
	"Elevator ahead",
	"Bridge ahead",
	"Hole ahead",
	"Cliff ahead",
	"Poison ahead",
	"Fire ahead",
	"Lightning ahead",
	"Magic ahead",
	"Dark ahead",
	"Light ahead",
	"Illusion ahead",
	"Mirage ahead",
	"Be wary of {object}",
	"Listen carefully",
	"Look carefully",
	"Examine carefully",
	"Use {object}",
	"Hold with both hands",
	"Two-hand it",
	"Use both hands",
	"Ranged battle required",
	"Close-range battle",
	"Magic effective",
	"No magic",
	"Sorcery effective", 
	"Pyromancy effective",
	"Miracle effective",
	"Fire effective",
	"Lightning effective",
	"Magic ineffective",
	"Physical attack effective",
	"Thrust attack effective",
	"Strike attack effective",
	"Slash attack effective",
	"Bleeding effective",
	"Poison effective",
	"Toxic effective",
	"Curse effective",
	"Divine weapon required",
	"Occult weapon required"
}

FBG.WordPools = {
	action = {
		-- GMod/Physics actions
		"spawning", "welding", "constraining", "duplicating", "freezing", "unfreezing", "nocolliding",
		"physgunning", "toolgunning", "prop-surfing", "ragdolling", "posing", "building", "destroying",
		
		-- Half-Life 2 actions
		"crowbarring", "shooting", "reloading", "running", "crouching", "jumping", "climbing",
		"swimming", "driving", "flying", "teleporting", "gravity-gunning", "manhacking",
		
		-- TTT actions
		"traitor-ing", "detecting", "investigating", "rdming", "camping", "sniping", "planting",
		"defusing", "identifying", "DNA-scanning", "karma-farming", "mic-spamming",
		
		-- General GMod actions
		"admin-abusing", "prop-killing", "griefing", "trolling", "minging", "role-playing",
		"scripting", "lua-coding", "server-crashing", "exploiting", "glitching", "bug-using"
	},
	
	object = {
		-- GMod Props/Tools
		"prop", "ragdoll", "physgun", "toolgun", "welder", "rope", "thruster", "wheel",
		"balloon", "dynamite", "button", "lever", "wire", "gate", "turret", "camera",
		"chair", "table", "bathtub", "toilet", "barrel", "crate", "door", "window",
		
		-- Half-Life 2 items
		"crowbar", "gravity gun", "headcrab", "barnacle", "antlion", "strider", "hunter",
		"combine soldier", "civil protection", "gordon freeman", "alyx vance", "dog",
		"lambda", "hev suit", "health kit", "battery", "ammo", "scanner", "manhack",
		
		-- TTT items
		"DNA scanner", "health station", "ammo station", "traitor tester", "teleporter",
		"radar", "disguiser", "radio", "c4", "knife", "pistol", "rifle", "shotgun",
		"detective", "traitor", "innocent", "spectator", "karma", "credits",
		
		-- GMod specific
		"addon", "workshop", "server", "map", "gamemode", "admin", "moderator", "player",
		"script", "lua", "console", "chat", "voice chat", "lag", "fps", "ping"
	},
	
	descriptor = {
		-- GMod/Server descriptors
		"laggy", "broken", "overpowered", "nerfed", "modded", "vanilla", "custom", "downloaded",
		"workshop", "subscribed", "banned", "kicked", "muted", "gagged", "admin-only",
		
		-- Technical descriptors
		"glitched", "bugged", "exploited", "scripted", "coded", "wired", "constrained",
		"nocollided", "frozen", "unfrozen", "duplicated", "spawned", "deleted",
		
		-- Quality descriptors
		"epic", "legendary", "rare", "common", "trash", "op", "balanced", "fair",
		"unfair", "cheap", "expensive", "free", "premium", "vip", "donator",
		
		-- Gameplay descriptors
		"suspicious", "innocent", "guilty", "proven", "unproven", "tested", "untested",
		"camping", "rushing", "sneaky", "obvious", "hidden", "visible", "dark", "bright"
	},
	
	enemy = {
		-- Half-Life 2 enemies
		"headcrab", "zombie", "fast zombie", "poison zombie", "antlion", "barnacle",
		"combine soldier", "civil protection", "strider", "hunter", "manhack", "scanner",
		"turret", "rollermines", "advisor", "vortigaunt",
		
		-- TTT roles
		"traitor", "detective", "innocent", "rdmer", "griefer", "minge", "troll",
		"camper", "sniper", "rusher", "admin", "moderator", "hacker", "cheater",
		
		-- GMod players/entities
		"prop killer", "mic spammer", "lag switcher", "exploiter", "script kiddie",
		"server crasher", "rule breaker", "mingebag", "failrper", "powergamer",
		
		-- NPCs/Entities
		"nextbot", "npc", "bot", "kleiner", "barney", "breen", "gman", "freeman",
		"citizen", "rebel", "metrocop", "overwatch", "stalker"
	}
}

if CLIENT then
	local ghostlyMessages = {}
	local ghostlyFont = "DermaLarge"
	
	-- TTT2 Integration Variables
	local fbg_key = CreateConVar("fbg_key", "G", FCVAR_ARCHIVE, "Key to open ghostly message composer")
	local showSpectatorHUD = false
	local lastSpectatedPlayer = nil
	
	surface.CreateFont("GhostlyFont", {
		font = "Times New Roman",
		size = 26,
		weight = 500,
		italic = true,
		shadow = true,
		outline = false
	})
	
	surface.CreateFont("GhostlyFontSmall", {
		font = "Times New Roman", 
		size = 16,
		weight = 400,
		italic = true,
		shadow = true,
		outline = false
	})
	
	surface.CreateFont("TombstoneTitle", {
		font = "Times New Roman",
		size = 20,
		weight = 700,
		italic = false,
		shadow = true,
		outline = false
	})
	
	surface.CreateFont("TombstoneText", {
		font = "Times New Roman",
		size = 14,
		weight = 400,
		italic = false,
		shadow = false,
		outline = false
	})
	
	local GhostlyMessage = {}
	GhostlyMessage.__index = GhostlyMessage
	
	function GhostlyMessage:New(text, sender)
		local msg = {}
		setmetatable(msg, GhostlyMessage)
		
		msg.text = text
		msg.sender = sender
		msg.spawnTime = CurTime()
		msg.duration = math.random(8, 15)
		
		local scrW, scrH = ScrW(), ScrH()
		msg.x = math.random(50, scrW - 300)
		msg.y = math.random(100, scrH - 200)
		
		msg.alpha = 0
		msg.maxAlpha = 200
		msg.fadeInTime = 2
		msg.fadeOutTime = 3
		msg.flickerIntensity = 30
		msg.lastFlicker = 0
		msg.flickerDelay = math.random(0.1, 0.5)
		
		msg.baseY = msg.y
		msg.floatSpeed = math.random(10, 20)
		msg.floatRange = math.random(10, 25)
		
		return msg
	end
	
	function GhostlyMessage:Update()
		local currentTime = CurTime()
		local elapsedTime = currentTime - self.spawnTime
		
		if elapsedTime < self.fadeInTime then
			self.alpha = (elapsedTime / self.fadeInTime) * self.maxAlpha
		elseif elapsedTime > (self.duration - self.fadeOutTime) then
			local fadeOutProgress = (elapsedTime - (self.duration - self.fadeOutTime)) / self.fadeOutTime
			self.alpha = self.maxAlpha * (1 - fadeOutProgress)
		else
			self.alpha = self.maxAlpha
		end
		
		if currentTime - self.lastFlicker > self.flickerDelay then
			self.alpha = math.max(0, self.alpha - math.random(0, self.flickerIntensity))
			self.lastFlicker = currentTime
			self.flickerDelay = math.random(0.1, 0.8)
		end
		
		self.y = self.baseY + math.sin(currentTime * self.floatSpeed * 0.1) * self.floatRange
		
		return elapsedTime < self.duration
	end
	
	function GhostlyMessage:Draw()
		if self.alpha <= 0 then return end
		
		local ghostColor = Color(200, 210, 230, self.alpha)
		local shadowColor = Color(60, 65, 75, self.alpha * 0.8)
		local senderColor = Color(160, 170, 180, self.alpha * 0.9)
		
		draw.SimpleText(self.text, "GhostlyFont", self.x + 3, self.y + 3, Color(40, 45, 50, self.alpha * 0.6), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(self.text, "GhostlyFont", self.x + 1, self.y + 1, shadowColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(self.text, "GhostlyFont", self.x, self.y, ghostColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		
		local senderText = "~ " .. self.sender .. " ~"
		draw.SimpleText(senderText, "GhostlyFontSmall", self.x + 15, self.y - 28, Color(50, 55, 60, self.alpha * 0.7), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(senderText, "GhostlyFontSmall", self.x + 14, self.y - 27, senderColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		
		if math.random() < 0.05 then
			local particleX = self.x + math.random(-10, 250)
			local particleY = self.y + math.random(-5, 30)
			local particleAlpha = math.random(15, 60)
			draw.SimpleText("•", "GhostlyFontSmall", particleX, particleY, Color(180, 190, 210, particleAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
	
	local function AddGhostlyMessage(text, sender)
		table.insert(ghostlyMessages, GhostlyMessage:New(text, sender))
		
		surface.PlaySound("ambient/wind/wind_snippet1.wav")
		
		if #ghostlyMessages > 5 then
			table.remove(ghostlyMessages, 1)
		end
	end
	
	net.Receive("fbg_ghostly_message", function()
		local message = net.ReadString()
		local senderName = net.ReadString()
		
		AddGhostlyMessage(message, senderName)
	end)
	
		-- TTT2 Helper Functions
	local function IsPlayerDead()
		local ply = LocalPlayer()
		if not IsValid(ply) then return false end
		
		-- TTT2 dead state check
		if ply.IsSpec and ply:IsSpec() then return true end
		if ply:Team() == TEAM_SPEC then return true end
		if not ply:Alive() then return true end
		
		return false
	end
	
	local function GetSpectatedPlayer()
		local ply = LocalPlayer()
		if not IsValid(ply) or not IsPlayerDead() then return nil end
		
		-- TTT2 spectator target
		local target = ply:GetObserverTarget()
		if IsValid(target) and target:IsPlayer() and target:Alive() then
			return target
		end
		
		return nil
	end
	
	local function DrawSpectatorHUD()
		if not IsPlayerDead() then 
			showSpectatorHUD = false
			return 
		end
		
		local spectatedPlayer = GetSpectatedPlayer()
		local scrW, scrH = ScrW(), ScrH()
		
		if spectatedPlayer then
			showSpectatorHUD = true
			lastSpectatedPlayer = spectatedPlayer
			
			-- Draw HUD panel for spectated player
			local panelW, panelH = 300, 60
			local panelX = scrW - panelW - 20
			local panelY = scrH - panelH - 100
			
			-- Tombstone-style background
			surface.SetDrawColor(40, 45, 50, 200)
			surface.DrawRect(panelX, panelY, panelW, panelH)
			
			surface.SetDrawColor(25, 30, 35, 255)
			surface.DrawOutlinedRect(panelX, panelY, panelW, panelH)
			
			surface.SetDrawColor(65, 70, 75, 120)
			surface.DrawOutlinedRect(panelX + 1, panelY + 1, panelW - 2, panelH - 2)
			
			-- Text content
			local keyText = string.upper(fbg_key:GetString())
			local titleText = "From Beyond the Grave"
			local instructionText = "Press [" .. keyText .. "] to send ghostly message to " .. spectatedPlayer:Nick()
			
			draw.SimpleText(titleText, "TombstoneTitle", panelX + panelW/2, panelY + 12, Color(180, 190, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText(instructionText, "TombstoneText", panelX + panelW/2, panelY + 35, Color(160, 170, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			
		elseif showSpectatorHUD then
			-- Show message when not spectating anyone
			local panelW, panelH = 350, 45
			local panelX = scrW - panelW - 20
			local panelY = scrH - panelH - 100
			
			surface.SetDrawColor(40, 45, 50, 180)
			surface.DrawRect(panelX, panelY, panelW, panelH)
			
			surface.SetDrawColor(25, 30, 35, 200)
			surface.DrawOutlinedRect(panelX, panelY, panelW, panelH)
			
			local titleText = "From Beyond the Grave"
			local instructionText = "Spectate a living player to send them messages"
			
			draw.SimpleText(titleText, "TombstoneTitle", panelX + panelW/2, panelY + 8, Color(160, 170, 180, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText(instructionText, "TombstoneText", panelX + panelW/2, panelY + 28, Color(140, 150, 160, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
	end
	
	hook.Add("HUDPaint", "DrawGhostlyMessages", function()
		-- Draw ghostly messages
		for i = #ghostlyMessages, 1, -1 do
			local msg = ghostlyMessages[i]
			
			if not msg:Update() then
				table.remove(ghostlyMessages, i)
			else
				msg:Draw()
			end
		end
		
		-- Draw spectator HUD for dead players
		DrawSpectatorHUD()
	end)

	local function PaintTombstonePanel(self, w, h)
		surface.SetDrawColor(45, 50, 55, 220)
		surface.DrawRect(0, 0, w, h)
		
		surface.SetDrawColor(30, 35, 40, 150)
		surface.DrawRect(2, 2, w-4, h-4)
		
		surface.SetDrawColor(70, 75, 80, 100)
		surface.DrawOutlinedRect(0, 0, w, h)
		
		surface.SetDrawColor(120, 130, 150, 30)
		surface.DrawOutlinedRect(1, 1, w-2, h-2)
	end
	
	local function PaintTombstoneButton(self, w, h)
		local isHovered = self:IsHovered()
		local baseColor = isHovered and Color(60, 65, 70, 200) or Color(50, 55, 60, 180)
		local glowColor = isHovered and Color(140, 150, 170, 80) or Color(100, 110, 130, 40)
		
		surface.SetDrawColor(baseColor.r, baseColor.g, baseColor.b, baseColor.a)
		surface.DrawRect(0, 0, w, h)
		
		surface.SetDrawColor(35, 40, 45, 200)
		surface.DrawOutlinedRect(0, 0, w, h)

		if isHovered then
			surface.SetDrawColor(glowColor.r, glowColor.g, glowColor.b, glowColor.a)
			surface.DrawRect(1, 1, w-2, h-2)
		end
	end
	
	local function PaintTombstoneFrame(self, w, h)
		surface.SetDrawColor(40, 45, 50, 240)
		surface.DrawRect(0, 0, w, h)
		
		surface.SetDrawColor(25, 30, 35, 255)
		surface.DrawOutlinedRect(0, 0, w, h)
		
		surface.SetDrawColor(65, 70, 75, 150)
		surface.DrawOutlinedRect(1, 1, w-2, h-2)
		
		surface.SetDrawColor(90, 95, 100, 80)
		surface.DrawOutlinedRect(2, 2, w-4, h-4)
		
		surface.SetDrawColor(110, 120, 140, 20)
		surface.DrawRect(3, 3, w-6, h-6)
	end
	
	local function CreateMessageComposer(targetPlayerName)
		local frame = vgui.Create("DFrame")
		local titleText = "Spectral Message - Target: " .. targetPlayerName
		frame:SetTitle(titleText)
		frame:SetSize(600, 500)
		frame:Center()
		frame:SetVisible(true)
		frame:SetDraggable(true)
		frame:ShowCloseButton(true)
		frame:MakePopup()

		frame.Paint = PaintTombstoneFrame
		
		frame.lblTitle:SetFont("TombstoneTitle")
		frame.lblTitle:SetTall(30)
		frame.lblTitle:SetTextColor(Color(180, 190, 210))

		local previewLabel = vgui.Create("DLabel", frame)
		previewLabel:SetPos(20, 40)
		previewLabel:SetSize(560, 30)
		previewLabel:SetText("Preview: [Select template and words]")
		previewLabel:SetFont("TombstoneTitle")
		previewLabel:SetTextColor(Color(180, 190, 210))
		previewLabel.Paint = PaintTombstonePanel
		
		local templateLabel = vgui.Create("DLabel", frame)
		templateLabel:SetPos(20, 80)
		templateLabel:SetSize(200, 20)
		templateLabel:SetText("Choose Message Template:")
		templateLabel:SetFont("TombstoneText")
		templateLabel:SetTextColor(Color(160, 170, 180))
		templateLabel.Paint = PaintTombstonePanel

		local templateCombo = vgui.Create("DComboBox", frame)
		templateCombo:SetPos(20, 100)
		templateCombo:SetSize(560, 25)
		templateCombo.Paint = PaintTombstoneButton
		templateCombo:SetTextColor(Color(180, 190, 210))
		templateCombo:SetFont("TombstoneText")
		
		for i, template in ipairs(FBG.MessageTemplates) do
			templateCombo:AddChoice(template)
		end
		
		local wordPanels = {}
		local selectedWords = {}
		
		local function UpdatePreview()
			local selectedTemplate = templateCombo:GetSelected()
			if not selectedTemplate then return end
			
			local preview = selectedTemplate
			for wordType, word in pairs(selectedWords) do
				preview = string.gsub(preview, "{" .. wordType .. "}", word or "[" .. wordType .. "]")
			end
			previewLabel:SetText("Preview: " .. preview)
		end
		
		local function CreateWordPanel(wordType, yPos)
			local panel = vgui.Create("DPanel", frame)
			panel:SetPos(20, yPos)
			panel:SetSize(560, 160)
			panel:SetBackgroundColor(Color(50, 50, 50, 100))
			panel.Paint = PaintTombstonePanel
			
			local label = vgui.Create("DLabel", panel)
			label:SetPos(10, 5)
			label:SetSize(200, 20)
			label:SetText("Choose " .. wordType .. ":")
			label:SetFont("TombstoneText")
			label:SetTextColor(Color(160, 170, 180))
			label.Paint = PaintTombstonePanel

			local wordList = vgui.Create("DScrollPanel", panel)
			wordList:SetPos(10, 25)
			wordList:SetSize(540, 130)
			wordList.Paint = PaintTombstonePanel

			local layout = vgui.Create("DIconLayout", wordList)
			layout:SetSize(540, 50)
			layout:SetSpaceY(2)
			layout:SetSpaceX(2)
			layout.Paint = PaintTombstonePanel

			for _, word in ipairs(FBG.WordPools[wordType] or {}) do
				local btn = vgui.Create("DButton")
				btn:SetText(word)
				btn:SetSize(80, 20)
				btn:SetTextColor(Color(160, 170, 180))
				btn:SetFont("TombstoneText")
				btn.Paint = PaintTombstoneButton
				btn.DoClick = function()
					selectedWords[wordType] = word
					UpdatePreview()
					
					for _, child in pairs(layout:GetChildren()) do
						child:SetTextColor(Color(160, 170, 180))
					end
					btn:SetTextColor(Color(200, 210, 230))
				end
				
				layout:Add(btn)
			end
			
			return panel
		end
		
		templateCombo.OnSelect = function(self, index, value)
			for _, panel in pairs(wordPanels) do
				panel:Remove()
			end
			wordPanels = {}
			selectedWords = {}
			
			local requiredTypes = {}
			for wordType in string.gmatch(value, "{(%w+)}") do
				if not requiredTypes[wordType] then
					requiredTypes[wordType] = true
				end
			end
			
			local yOffset = 140
			for wordType in pairs(requiredTypes) do
				wordPanels[wordType] = CreateWordPanel(wordType, yOffset)
				yOffset = yOffset + 160
			end
			
			UpdatePreview()
		end
		
		local sendBtn = vgui.Create("DButton", frame)
		sendBtn:SetPos(450, 460)
		sendBtn:SetSize(100, 30)
		sendBtn:SetText("Send Message")
		sendBtn:SetFont("TombstoneText")
		sendBtn:SetTextColor(Color(180, 190, 210))
		sendBtn.Paint = PaintTombstoneButton
		
		sendBtn.DoClick = function()
			local selectedTemplate = templateCombo:GetSelected()
			if not selectedTemplate then
				chat.AddText(Color(255, 100, 100), "Please select a message template!")
				return
			end
			
			local finalMessage = selectedTemplate
			local missingWords = false
			
			for wordType in string.gmatch(selectedTemplate, "{(%w+)}") do
				if selectedWords[wordType] then
					finalMessage = string.gsub(finalMessage, "{" .. wordType .. "}", selectedWords[wordType])
				else
					missingWords = true
					break
				end
			end
			
			if missingWords then
				chat.AddText(Color(255, 100, 100), "Please select all required words!")
				return
			end
			
			local targetPlayer = nil
			for _, ply in pairs(player.GetAll()) do
				if ply:Nick() == targetPlayerName then
					targetPlayer = ply
					break
				end
			end
			
			if not targetPlayer then
				chat.AddText(Color(255, 100, 100), "Target player not found!")
				return
			end
			
			net.Start("fbg_send_template_message")
			net.WriteEntity(targetPlayer)
			net.WriteString(selectedTemplate)
			net.WriteTable(selectedWords)
			net.SendToServer()
			frame:Close()
		end
		
		local cancelBtn = vgui.Create("DButton", frame)
		cancelBtn:SetPos(340, 460)
		cancelBtn:SetSize(100, 30)
		cancelBtn:SetText("Cancel")
		cancelBtn:SetFont("TombstoneText")
		cancelBtn:SetTextColor(Color(160, 170, 180))
		cancelBtn.Paint = PaintTombstoneButton
		cancelBtn.DoClick = function()
			frame:Close()
		end
	end
	
	-- TTT2 Spectator Message System
	local function OpenSpectatorComposer()
		if not IsPlayerDead() then
			chat.AddText(Color(255, 100, 100), "You must be dead to send ghostly messages!")
			return
		end
		
		local spectatedPlayer = GetSpectatedPlayer()
		if spectatedPlayer then
			CreateMessageComposer(spectatedPlayer:Nick())
		else
			chat.AddText(Color(180, 190, 210), "From Beyond the Grave: ", Color(160, 170, 180), "Spectate a living player to send them messages from beyond the grave.")
		end
	end
	
	-- Key binding system
	hook.Add("PlayerButtonDown", "FBG_KeyPress", function(ply, button)
		if ply != LocalPlayer() then return end
		
		local keyCode = input.GetKeyCode(fbg_key:GetString())
		if button == keyCode then
			OpenSpectatorComposer()
		end
	end)
	
	-- Console command for spectator access only
	concommand.Add("fbg_compose", function()
		OpenSpectatorComposer()
	end)
	
	-- TTT2 Round state integration
	hook.Add("TTTBeginRound", "FBG_RoundStart", function()
		showSpectatorHUD = false
		lastSpectatedPlayer = nil
	end)
end

if SERVER then
	local playerMessageTimes = {}
	local MESSAGE_COOLDOWN = 5 -- 5 seconds between messages
	local MAX_MESSAGE_LENGTH = 100
	
	local function GenerateGhostlyName(playerName)
		local ghostlyNames = {
			-- Classic Gothic Names
			"Mordecai the Wailing", "Evangeline the Pale", "Bartholomew the Hollow", "Seraphina the Lost",
			"Cornelius the Drifting", "Ophelia the Weeping", "Thaddeus the Forgotten", "Cordelia the Mournful",
			"Ambrose the Spectral", "Millicent the Ethereal", "Percival the Restless", "Genevieve the Shadowed",
			"Algernon the Cursed", "Prudence the Banished", "Mortimer the Lamenting", "Beatrice the Vanished",
			
			-- Mysterious Titles
			"The Hooded Figure", "The Weeping Maiden", "The Wandering Scholar", "The Forgotten Knight",
			"The Silent Monk", "The Grieving Mother", "The Lost Traveler", "The Nameless Bard",
			"The Hollow King", "The Veiled Bride", "The Accursed Poet", "The Withered Scribe",
			"The Mourning Child", "The Faceless Priest", "The Shattered Soul", "The Whispering Sage",
			
			-- Ancient Entities
			"Keeper of Sorrows", "Herald of Mists", "Warden of Echoes", "Guardian of Shadows", 
			"Voice from the Void", "Spirit of the Depths", "Phantom of Ages", "Wraith of Time",
			"Echo of Eternity", "Shade of Memories", "Whisper of the Past", "Ghost of Tomorrow",
			"Remnant of Dreams", "Fragment of Souls", "Vestige of Hope", "Specter of Fear",
			
			-- Cryptic Descriptions
			"The One Who Walks Backwards", "She Who Remembers Nothing", "He Who Speaks in Riddles",
			"The Figure in the Mist", "The Voice Behind You", "The Shadow at Noon", 
			"The Smile Without a Face", "The Footsteps in Empty Halls", "The Candle That Burns Cold",
			"The Door That Opens Inward", "The Bell That Rings Silence", "The Mirror That Shows Truth",
			
			-- Soulsborne-Inspired
			"The Tarnished One", "Hollow of the Abyss", "Bearer of the Curse", "The Unkindled Soul",
			"Ashen One's Echo", "The Fading Light", "Chosen of None", "The Undying Flame",
			"Herald of Darkness", "The Linking Fire", "Soul of Cinder", "The First Flame's Echo",
			
			-- Poetic/Literary
			"The Raven's Whisper", "Autumn's Last Breath", "Winter's Forgotten Child", "Summer's Lost Dream",
			"The Thirteenth Hour", "Midnight's Companion", "Dawn's Regret", "Twilight's Promise",
			"The Unwritten Word", "The Silent Symphony", "The Broken Melody", "The Last Verse",
			
			-- Mysterious Locations
			"Dweller of Fog", "Inhabitant of Ruins", "Resident of Nowhere", "Citizen of the Between",
			"Wanderer of Crossroads", "Guardian of Thresholds", "Keeper of Gates", "Walker of Borders",
			"The Library Ghost", "The Tower Phantom", "The Bridge Specter", "The Garden Wraith",
			
			-- Abstract Concepts
			"Living Memory", "Walking Regret", "Breathing Sorrow", "Thinking Shadow", 
			"Dreaming Stone", "Sleeping Thunder", "Waking Nightmare", "Dancing Despair",
			"Singing Silence", "Laughing Tears", "Crying Joy", "Screaming Peace",
			
			-- Time-Based
			"Yesterday's Ghost", "Tomorrow's Phantom", "The Hour That Never Was", "The Day That Forgot",
			"Next Week's Worry", "Last Year's Hope", "The Minute Hand's Curse", "The Clock's Lament",
			"Eternal Tuesday", "The Missing Wednesday", "Forever's End", "Never's Beginning"
		}
		
		return ghostlyNames[math.random(#ghostlyNames)]
	end
	
	local function ValidateMessage(message)
		if not message or message == "" then return false end
		if string.len(message) > MAX_MESSAGE_LENGTH then return false end
		
		return true, message
	end
	
	-- TTT2 Server Helper Functions
	local function IsPlayerDeadTTT2(ply)
		if not IsValid(ply) then return false end
		
		-- TTT2 dead state checks
		if ply.IsSpec and ply:IsSpec() then return true end
		if ply:Team() == TEAM_SPEC then return true end
		if not ply:Alive() then return true end
		
		return false
	end

	function FBG.SendGhostlyMessage(sender, targetPlayer, message)
		local steamID = sender:SteamID()
		local currentTime = CurTime()
		
		-- TTT2: Only dead players can send ghostly messages
		if not IsPlayerDeadTTT2(sender) then
			sender:ChatPrint("You must be dead to send messages from beyond the grave!")
			return
		end
		
		-- Target must be alive
		if IsPlayerDeadTTT2(targetPlayer) then
			sender:ChatPrint("You cannot send ghostly messages to the dead!")
			return
		end
		
		if playerMessageTimes[steamID] and (currentTime - playerMessageTimes[steamID]) < MESSAGE_COOLDOWN then
			local remainingTime = MESSAGE_COOLDOWN - (currentTime - playerMessageTimes[steamID])
			sender:ChatPrint("You must wait " .. math.ceil(remainingTime) .. " seconds before sending another ghostly message.")
			return
		end
		
		local isValid, validatedMessage = ValidateMessage(message)
		if not isValid then
			sender:ChatPrint("Invalid message: " .. (validatedMessage or "Unknown error"))
			return
		end
		
		playerMessageTimes[steamID] = currentTime
		
		local ghostlyName = GenerateGhostlyName(sender:Nick())
		net.Start("fbg_ghostly_message")
		net.WriteString(validatedMessage)
		net.WriteString(ghostlyName)
		net.Send(targetPlayer)
		
		sender:ChatPrint("Ghostly message sent to " .. targetPlayer:Nick() .. ": \"" .. validatedMessage .. "\"")
	end
	
	function FBG.ValidateTemplateMessage(template, words)
		local templateValid = false
		for _, validTemplate in ipairs(FBG.MessageTemplates) do
			if template == validTemplate then
				templateValid = true
				break
			end
		end
		
		if not templateValid then
			return false, "Invalid template"
		end
		
		for wordType in string.gmatch(template, "{(%w+)}") do
			local word = words[wordType]
			if not word then
				return false, "Missing word for " .. wordType
			end
			
			local wordValid = false
			if FBG.WordPools[wordType] then
				for _, validWord in ipairs(FBG.WordPools[wordType]) do
					if word == validWord then
						wordValid = true
						break
					end
				end
			end
			
			if not wordValid then
				return false, "Invalid " .. wordType .. ": " .. word
			end
		end
		
		return true
	end
	
	net.Receive("fbg_send_template_message", function(len, ply)
		if not IsValid(ply) then return end
		if ply:Alive() then return end
		
		local targetPlayer = net.ReadEntity()
		local template = net.ReadString()
		local words = net.ReadTable()
		
		if not IsValid(targetPlayer) or not targetPlayer:IsPlayer() then
			ply:ChatPrint("Invalid target player.")
			return
		end
		
		if targetPlayer == ply then
			ply:ChatPrint("You cannot send ghostly messages to yourself!")
			return
		end
		
		local isValid, errorMsg = FBG.ValidateTemplateMessage(template, words)
		if not isValid then
			ply:ChatPrint("Invalid message: " .. errorMsg)
			return
		end
		
		local finalMessage = template
		for wordType, word in pairs(words) do
			finalMessage = string.gsub(finalMessage, "{" .. wordType .. "}", word)
		end
		
		FBG.SendGhostlyMessage(ply, targetPlayer, finalMessage)
	end)
end
