EFFECT.mat = Material("hl1/sprites/zerogxplode")

function EFFECT:Init(data)
	self.Pos = data:GetOrigin()
	self.Norm = data:GetNormal()
	self.Scale = data:GetScale()
	
	self.Time = 0
	self.Size = 6 * self.Scale

	local halfSize = self.Scale * 0.5
	
	self:SetRenderBoundsWS(data:GetOrigin(), self.Pos, Vector(halfSize, halfSize, halfSize))

	if !self.mat:IsError() then
		self.Animated = true
	end
end

function EFFECT:Think()
	self.Time = self.Time + FrameTime()
	//self.Size = 256 * self.Time

	return self.Time < 1
end

function EFFECT:Render()
	render.SetMaterial(self.mat)
	if self.Animated then
		self.mat:SetInt("$frame", math.Clamp(math.floor(self.Time * 15), 0, 14))
	end
	render.DrawSprite(self.Pos, self.Size, self.Size, color_white)
end