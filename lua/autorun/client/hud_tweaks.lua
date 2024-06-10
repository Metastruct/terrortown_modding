require("hookextras")

util.OnInitialize(function()
	local HUDELEMENT = hudelements.GetTypeElement("tttvoice")

	if HUDELEMENT then
		-- Override the tttvoice HUD element's Draw function to allow disguising players using the Identity Disguiser
		function HUDELEMENT:Draw()
			local client = LocalPlayer()

			local pos = self:GetPos()
			local size = self:GetSize()
			local x, y = pos.x, pos.y
			local w, h = size.w, size.h

			local pls = player.GetAll()
			local plsSorted = {}

			for i = 1, #pls do
				local pl = pls[i]

				if not VOICE.IsSpeaking(pl) then
					continue
				end

				if pl == client then
					table.insert(plsSorted, 1, pl)

					continue
				end

				plsSorted[#plsSorted + 1] = pl
			end

			for i = 1, #plsSorted do
				local pl = plsSorted[i]

				if pl.GetDisguiserTarget and not VOICE.IsRoleChatting(pl) then
					local disguise = pl:GetDisguiserTarget()

					if IsValid(disguise) then
						pl = disguise
					end
				end

				self:DrawVoiceBar(pl, x, y, w, h)

				y = y + h + self.padding
			end
		end

		-- Add a convar to give the option of bringing back the simplified look of the voicehud
		local convarSimpleVoiceHud = CreateConVar("ttt2_hud_simple_voicehud", "0", FCVAR_ARCHIVE)

		HUDELEMENT.DrawVoiceBar_Original = HUDELEMENT.DrawVoiceBar_Original or HUDELEMENT.DrawVoiceBar

		local unlitColor = Color(25, 25, 25)
		function HUDELEMENT:DrawVoiceBar(pl, xPos, yPos, w, h)
			if not convarSimpleVoiceHud:GetBool() then
				HUDELEMENT:DrawVoiceBar_Original(pl, xPos, yPos, w, h)
				return
			end

			local color = VOICE.GetVoiceColor(pl)

			unlitColor.a = math.max(1 - (pl:VoiceVolume() * 1.25), 0) * 255

			draw.Box(xPos, yPos, w, h, color)
			draw.Box(xPos, yPos, w, h, unlitColor)

			local padding = 4 * self.scale
			local avSize = h - (padding * 2)

			local nickWidth = w - h - (padding * 2)

			draw.FilteredTexture(
				xPos + padding,
				yPos + padding,
				avSize,
				avSize,
				draw.GetAvatarMaterial(pl:SteamID64(), "medium"),
				255,
				COLOR_WHITE
			)

			draw.AdvancedText(
				pl:NickElliptic(nickWidth, "PureSkinPopupText", self.scale),
				"PureSkinPopupText",
				xPos + h + padding,
				yPos + h * 0.5 - 1,
				util.GetDefaultColor(unlitColor),
				TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER,
				false,
				self.scale
			)
		end
	end
end)