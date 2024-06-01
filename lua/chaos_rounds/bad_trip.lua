local ROUND = {}
ROUND.Name = "Bad Trip"
ROUND.Description = "You've had sniffed some questionnable powder, as the round continues, side effects will get worse..."

local CVAR_HASTE = GetConVar("ttt_haste")
local CVAR_HASTE_TIME = GetConVar("ttt_haste_starting_minutes")
local CVAR_ROUND_TIME = GetConVar("ttt_roundtime_minutes")
function ROUND:GetTotalRoundTime()
	local time = CVAR_ROUND_TIME and CVAR_ROUND_TIME:GetInt() or 10
	if CVAR_HASTE and CVAR_HASTE:GetBool() then
		time = CVAR_HASTE_TIME and CVAR_HASTE_TIME:GetInt() or time
	end

	return time * 60
end

local MAX_TEXTURE_SCROLL_SPEED = 2
local MAX_DRUNK_FACTOR = 200

if CLIENT then
	function ROUND:Start()
		local map_materials = game.GetWorld():GetMaterials()
		local previous_transforms = {}
		local mat_data = {}

		for _, mat_name in ipairs(map_materials) do
			local mat = Material(mat_name)
			local transform = mat:GetMatrix("$basetexturetransform")

			if transform then
				previous_transforms[mat_name] = transform
			end

			table.insert(mat_data, {
				Material = mat,
				Name = mat_name,
				VerticalTransform = math.random() > 0.5,
			})
		end

		self.MatData = mat_data
		self.PreviousTransforms = previous_transforms

		-- Speed and direction variables
		local speed = 0.1
		local offset = 0
		local coef = MAX_TEXTURE_SCROLL_SPEED / self:GetTotalRoundTime()
		local function UpdateMaterialTexture()
			-- Increment the offset based on the speed and frame time
			offset = offset + speed * FrameTime()

			local vertical_transform_matrix = Matrix()
			local horizontal_transform_matrix = Matrix()

			-- Translate the texture coordinates
			vertical_transform_matrix:Translate(Vector(offset, 0, 0))
			horizontal_transform_matrix:Translate(Vector(0, offset, 0))

			-- Apply the transformation to the materials
			for _, data in ipairs(mat_data) do
				data.Material:SetMatrix("$basetexturetransform", data.VerticalTransform and vertical_transform_matrix or horizontal_transform_matrix)
			end

			-- Reset the offset if it gets too large (to prevent overflow)
			if offset >= 1 then
				offset = offset - 1
			end
		end

		hook.Add("Think", "ChaosRoundBadTrip", UpdateMaterialTexture)
		timer.Create("ChaosRoundBadTrip", 1, 0, function()
			speed = speed + coef
		end)
	end

	function ROUND:Finish()
		hook.Remove("Think", "ChaosRoundBadTrip")

		for _, data in ipairs(self.MatData) do
			local previous_transform = self.PreviousTransforms[data.Name]
			if previous_transform then
				data.Material:SetMatrix("$basetexturetransform", previous_transform)
			else
				data.Material:SetMatrix("$basetexturetransform", nil)
			end
		end

		self.MatData = {}
		self.PreviousTransforms = {}
	end
end

if SERVER then
	function ROUND:Start()
		local factor = 1
		local coef = MAX_DRUNK_FACTOR / self:GetTotalRoundTime()
		timer.Create("ChaosRoundBadTrip", 1, 0, function()
			for _, ply in ipairs(player.GetAll()) do
				if not ply:IsTerror() then continue end

				ply:SetDrunkFactor(factor)
				factor = factor + coef
			end
		end)
	end

	function ROUND:Finish()
		timer.Remove("ChaosRoundBadTrip")
		for _, ply in ipairs(player.GetAll()) do
			ply:SetDrunkFactor(0)
		end
	end
end

return RegisterChaosRound(ROUND)