local ROUND = {}
ROUND.Name = "My cool round!"
ROUND.Description = "It does something..."

-- [SHARED] called when this particular round is selected by the chaos round logic
function ROUND:OnSelected()
end

-- [SHARED] called when preparation starts before the round starts
function ROUND:OnPrepare()
end

-- [SHARED] called when the round starts
function ROUND:Start()
end

-- [SHARED] called when the round ends
function ROUND:Finish()
end

if CLIENT then
	-- [CLIENT] this is called after the selection UI has been shown and removed
	function ROUND:OnPostSelection()
	end

	-- [CLIENT] this is called when this particular round is selected in the selection UI
	function ROUND:DrawSelection(w, h) -- width (number), height (number)
	end
end

-- don't forget to add this line, otherwise your chaos round wont be added to the pool
-- return RegisterChaosRound(ROUND)