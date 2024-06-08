-- A tweak to the tttvoice HUD element to also disguise players using the Identity Disguiser in voice chat

require("hookextras")

util.OnInitialize(function()
	local HUDELEMENT = hudelements.GetTypeElement("tttvoice")

	if HUDELEMENT then
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
	end
end)