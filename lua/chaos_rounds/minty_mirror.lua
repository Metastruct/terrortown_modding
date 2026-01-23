-- Module --
local ROUND     = {
    Author      = "Minty",
    Name        = "Mirror",
    Description = "Mirror mirror on the wall, I believe my optician I must call.",

    Enabled         = false,
    Framebuffer     = { RenderTarget = false, Material = false },
    Patch           = minty.patch.New(),
    ViewModelFlip   = {},
}

ROUND.Hook          = minty.hook.New( "ChaosRound_Mirror", ROUND )

-- Cache --
local debug_setmetatable                = debug.setmetatable
local math_Clamp                        = math.Clamp
local render_CopyRenderTargetToTexture  = CLIENT and render.CopyRenderTargetToTexture or nil
local render_DrawScreenQuad             = CLIENT and render.DrawScreenQuad or nil
local render_SetMaterial                = CLIENT and render.SetMaterial or nil

-- Constants --
local MOUSE_DELTA_SCALAR    = ( 1.0 / 45.0 )
local MOUSE_PITCH_MIN_MAX   = 89

-- Variables --
local ANGLE         = minty.patch.__meta.ANGLE
local ANGLE_PATCHED = table.Copy( ANGLE )

local matrix_flip = Matrix( {
    { -1, 0, 0, 0 },
    { 0, 1, 0, 0 },
    { 0, 0, 1, 0 },
    { 0, 0, 0, 1 },
} )

-- Utility --
local function weapon_flip_viewmodels( weapon )
    weapon.ViewModelFlip = not weapon.ViewModelFlip
    weapon.ViewModelFlip1 = not weapon.ViewModelFlip1
    weapon.ViewModelFlip2 = not weapon.ViewModelFlip2
end

function ROUND:CreateFramebuffer()
    if SERVER or ( self.Framebuffer.RenderTarget and self.Framebuffer.Material ) then return end

    local tag = "ChaosRound_Mirror_Framebuffer"

    -- Create render-target
    local render_target = GetRenderTargetEx(
        tag,
        4096,
        4096,
        RT_SIZE_FULL_FRAME_BUFFER_ROUNDED_UP,
        MATERIAL_RT_DEPTH_SHARED,
        40960,
        0,
        IMAGE_FORMAT_BGRA8888
    )

    -- Create material
    local material = CreateMaterial(
        tag,
        "UnlitGeneric",
        {
            [ "$basetexture" ]  = render_target:GetName(),
            [ "$ignorez" ]      = "1",
        }
    )

    material:SetMatrix( "$basetexturetransform", matrix_flip )

    -- Store framebuffer
    self.Framebuffer.RenderTarget   = render_target
    self.Framebuffer.Material       = material
end

function ROUND:UnflipViewModels()
    for weapon, _ in pairs( self.ViewModelFlip ) do
        weapon_flip_viewmodels( weapon )
    end

    self.ViewModelFlip = {}
end

-- Hooks --
if CLIENT then
    -- Hook: GM.CreateMove
    -- Purpose: Flip horizontal player movement
    function ROUND.Hook.CreateMove( cmd )
        cmd:SetSideMove( -cmd:GetSideMove() )
    end

    -- Hook: GM.InputMouseApply
    -- Purpose: Flip horizontal mouse movement
    function ROUND.Hook.InputMouseApply( cmd, x, y, angles )
        cmd:SetMouseX( -x )

        angles.yaw      = angles.yaw + ( x * MOUSE_DELTA_SCALAR )
        angles.pitch    = math_Clamp( 
            angles.pitch + ( y * MOUSE_DELTA_SCALAR ),
            -MOUSE_PITCH_MIN_MAX,
            MOUSE_PITCH_MIN_MAX
        )

        cmd:SetViewAngles( angles )

        return true
    end

    -- Hook: GM.PreDrawHUD
    -- Purpose: Draw flipped view
    function ROUND.Hook.PreDrawHUD()
        render_CopyRenderTargetToTexture( self.Framebuffer.RenderTarget )
        render_SetMaterial( self.Framebuffer.Material )
        render_DrawScreenQuad()
    end

    -- Hook: GM.PreDrawViewModel
    -- Purpose: Invert SWEP.ViewModelFlip
    function ROUND.Hook.PreDrawViewModel( _, _, weapon )
        if not self.ViewModelFlip[ weapon ] then
            self.ViewModelFlip[ weapon ] = true
            weapon_flip_viewmodels( weapon )
        end
    end
end

-- Patches --
-- Patch: ANGLE_PATCHED.Right
function ANGLE_PATCHED.Right( self )
    return -ANGLE.Right( self )
end

-- Patch: ENTITY.EyeAngles
-- Purpose: Flip right direction (used in weapon_tttbasegrenade)
function ROUND.Patch.ENTITY.EyeAngles( self )
    local angles = _f( self )
    debug_setmetatable( angles, ANGLE_PATCHED )

    return angles
end

-- Patch: ENTITY.GetBoneMatrix
-- Purpose: Flip across Z-axis (used in custom PostDrawViewModel)
function ROUND.Patch.ENTITY.GetBoneMatrix( self, id )
    local matrix = _f( self, id )
    if ( self:GetClass() ~= "viewmodel" ) then return matrix end

    -- Incorrect, but will do for now
    matrix:SetUp( -matrix:GetUp() )
    return matrix
end

-- Patch: ENTITY.GetRight
-- Purpose: Flip player right direction
function ROUND.Patch.ENTITY.GetRight( self )
    if self:IsPlayer() then
        return -_f( self )
    else
        return _f( self )
    end
end

if CLIENT then
    -- Patch: VECTOR.ToScreen
    -- Purpose: Flip horizontally (used in TBHUD, for drawing traitor buttons)
    function ROUND.Patch.VECTOR.ToScreen( self )
        local data = _f( self )
        data.x = ScrW() - data.x

        return data
    end
end

-- Callbacks --
function ROUND:OnPrepare() end
function ROUND:OnSelected() end

function ROUND:Start()
    if self.Enabled then self:Finish() end

    self:CreateFramebuffer()

    self.Patch:Patch()
    self.Hook:Register()

    self.Enabled = true
end

function ROUND:Finish()
    if not self.Enabled then return end

    self.Hook:Unregister()
    self.Patch:Unpatch()

    self:UnflipViewModels()

    self.Enabled = false
end

-- Export --
return RegisterChaosRound( ROUND )