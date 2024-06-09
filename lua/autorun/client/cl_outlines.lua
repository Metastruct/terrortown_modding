OUTLINE_MODE_BOTH = 0
OUTLINE_MODE_NOTVISIBLE = 1
OUTLINE_MODE_VISIBLE = 2

local istable = istable
local render = render
local LocalPlayer = LocalPlayer
local Material = Material
local CreateMaterial = CreateMaterial
local hook = hook
local cam = cam
local ScrW = ScrW
local ScrH = ScrH
local IsValid = IsValid
local surface = surface

module("outline", package.seeall)

local List = {}
local RenderEnt = NULL

local OutlineMatSettings = {
	["$ignorez"] = 1,
	["$alphatest"] = 1
}
local CopyMat = Material("pp/copy")
local OutlineMat = CreateMaterial("OutlineMat", "UnlitGeneric", OutlineMatSettings)

local StoreTexture = render.GetScreenEffectTexture(0)
local DrawTexture = render.GetScreenEffectTexture(1)

local ENTS = 1
local COLOR = 2
local MODE = 3
local SIZE = 4

function Add(ents, color, mode, size)
	if #List >= 255 then return end --Maximum 255 reference values
	if not istable(ents) then ents = { ents } end --Support for passing Entity as first argument
	if ents[1] == nil then return end --Do not pass empty tables

	List[#List + 1] = {
		[ENTS] = ents,
		[COLOR] = color,
		[MODE] = mode or OUTLINE_MODE_BOTH,
		[SIZE] = size or 1
	}
end

function RenderedEntity()
	return RenderEnt
end

local OUTLINE_CVAR = CreateClientConVar("mta_outlines", "1", true, false, "Enable outlines")
local function Render()
	if not OUTLINE_CVAR:GetBool() then return end

	local ply = LocalPlayer()
	local IsLineOfSightClear = ply.IsLineOfSightClear

	local scene = render.GetRenderTarget()

	render.CopyRenderTargetToTexture(StoreTexture)

	local w = ScrW()
	local h = ScrH()

	render.Clear(0, 0, 0, 0, true, true)

	render.SetStencilEnable(true)
	cam.IgnoreZ(true)
	render.SuppressEngineLighting(true)

	render.SetStencilWriteMask(0xFF)
	render.SetStencilTestMask(0xFF)

	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_REPLACE)
	render.SetStencilPassOperation(STENCIL_REPLACE)

	cam.Start3D()
	for i, v in ipairs(List) do
		local mode = v[MODE]
		local ents = v[ENTS]
		render.SetStencilReferenceValue(i)

		for _, ent in ipairs(ents) do
			if not IsValid(ent) then continue end

			if not ((mode == OUTLINE_MODE_NOTVISIBLE and IsLineOfSightClear(ply, ent)) or (mode == OUTLINE_MODE_VISIBLE and not IsLineOfSightClear(ply, ent))) then
				RenderEnt = ent
				ent:DrawModel()
			end
		end
	end

	RenderEnt = NULL
	cam.End3D()

	render.SetStencilCompareFunction(STENCIL_EQUAL)

	cam.Start2D()
	for i, v in ipairs(List) do
		render.SetStencilReferenceValue(i)
		surface.SetDrawColor(v[COLOR]:Unpack())
		surface.DrawRect(0, 0, w, h)
	end
	cam.End2D()

	render.SuppressEngineLighting(false)
	cam.IgnoreZ(false)
	render.SetStencilEnable(false)

	render.CopyRenderTargetToTexture(DrawTexture)

	render.SetRenderTarget(scene)
	CopyMat:SetTexture("$basetexture", StoreTexture)
	render.SetMaterial(CopyMat)
	render.DrawScreenQuad()

	render.SetStencilEnable(true)
	render.SetStencilReferenceValue(0)
	render.SetStencilCompareFunction(STENCIL_EQUAL)

	OutlineMat:SetTexture("$basetexture", DrawTexture)
	render.SetMaterial(OutlineMat)

	for i = 1, #List do
		local size = List[i][SIZE]
		for x = -size, size, 1 do
			for y = -size, size, 1 do
				render.DrawScreenQuadEx(x, y, w, h)
			end
		end
	end
	render.SetStencilEnable(false)
end

hook.Add("PostDrawEffects", "RenderOutlines", function()
	hook.Run("PreDrawOutlines")
	if #List == 0 then return end

	Render()
	List = {}
end)