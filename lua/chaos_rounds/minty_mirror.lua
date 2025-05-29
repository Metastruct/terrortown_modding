local ROUND = {}
ROUND.Name = "Mirror"
ROUND.Description = "Mirror mirror on the wall, I believe my optician I must call."

-- Metatable
local ANGLE         = FindMetaTable( "Angle" )
local ANGLE_PATCHED = table.Copy( ANGLE )

-- Variables
local mirror_enabled = false

local hooks     = {}

local patches   = {
    entity      = { __meta = "Entity" },
    vector      = { __meta = "Vector" },
}

local render_target = {}

-- Utility
local function CreateFrameBufferMaterial( name, flip, ignore_z, alpha )
    if SERVER then return nil, nil end

    -- Create render-target
    local render_target = GetRenderTargetEx(
        "Mirror_RT_" .. name,
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
        "Mirror_Material_" .. name,
        "UnlitGeneric",
        {
            [ "$basetexture" ] = render_target:GetName(),
        }
    )

    material:SetString( "$ignorez", ignore_z and "1" or "0" )
    material:SetString( "$alphatest", alpha and "1" or "0" )

    if flip then
        local matrix_flip = Matrix()
        matrix_flip:Scale( Vector( -1, 1, 1 ) )

        material:SetMatrix( "$basetexturetransform", matrix_flip )
    end

    return render_target, material
end

local function RegisterHooks()
    for k, v in pairs( hooks ) do
        hook.Add( k, "Mirror_Hook_" .. k, v )
    end
end

local function UnregisterHooks()
    for k, _ in pairs( hooks ) do
        hook.Remove( k, "Mirror_Hook_" .. k )
    end
end

local function RegisterPatches()
    for table_name, sub_patches in pairs( patches ) do
        if ( type( sub_patches.__meta ) == "string" ) then
            sub_patches.__meta = FindMetaTable( sub_patches.__meta )
        end

        local source_table = sub_patches.__meta or _G[ table_name ] or {}
        local unpatched_functions = {}

        for function_name, patched_function in pairs( sub_patches ) do
            if ( type( patched_function ) == "function" ) then
                print( "Patching '" .. table_name .. "." .. function_name .. "'!" )
                unpatched_functions[ function_name ] = sub_patches[ "_" .. function_name ] or source_table[ function_name ]
                source_table[ function_name ] = patched_function
            end
        end

        for function_name, unpatched_function in pairs( unpatched_functions ) do
            sub_patches[ "_" .. function_name ] = unpatched_function
        end
    end
end

local function UnregisterPatches()
    for table_name, sub_patches in pairs( patches ) do
        if ( type( sub_patches.__meta ) == "string" ) then
            sub_patches.__meta = FindMetaTable( sub_patches.__meta )
        end

        local source_table = sub_patches.__meta or _G[ table_name ] or {}
        local unpatched_functions = {}

        for function_name, patched_function in pairs( sub_patches ) do
            if ( type( patched_function ) == "function" ) then
                source_table[ function_name ] = sub_patches[ "_" .. function_name ] or source_table[ function_name ]
                unpatched_functions[ function_name ] = true
            end
        end

        for function_name, unpatched_function in pairs( unpatched_functions ) do
            sub_patches[ "_" .. function_name ] = nil
        end
    end
end

local function UnflipWeapons()
    for _, v in ipairs( ents.GetAll() ) do
        if IsValid( v ) and v:IsWeapon() and ( v._ViewModelFlip ~= nil ) then
            v.ViewModelFlip = v._ViewModelFlip
            v._ViewModelFlip = nil
        end
    end
end

local function IsRenderTargetActive( render_target )
    local current = render.GetRenderTarget()
    if not current then return false end

    return ( current:GetName() == render_target:GetName() )
end

-- Patches
function ANGLE_PATCHED:Right()
    return -ANGLE.Right( self )
end

function patches.entity.EyeAngles( self )
    local angles = patches.entity._EyeAngles( self )
    debug.setmetatable( angles, ANGLE_PATCHED )

    return angles
end

function patches.entity.GetBoneMatrix( self, id )
    local matrix = patches.entity._GetBoneMatrix( self, id )
    if ( self:GetClass() ~= "viewmodel" ) then return matrix end

    -- Incorrect, but will do for now
    matrix:SetUp( -matrix:GetUp() )
    return matrix
end

function patches.entity.GetRight( self )
    return patches.entity._GetRight( self ) * ( self:IsPlayer() and -1 or 1 )
end

function patches.vector.ToScreen( self )
    local data = patches.vector._ToScreen( self )
    data.x = ScrW() - data.x

    return data
end

-- Hooks
function hooks.CreateMove( cmd )
    cmd:SetSideMove( -cmd:GetSideMove() )
end

function hooks.PreDrawViewModel( _, _, weapon )
    if mirror_enabled and ( weapon._ViewModelFlip == nil ) then
        weapon._ViewModelFlip = weapon.ViewModelFlip
        weapon.ViewModelFlip = not weapon._ViewModelFlip
    end
end

function hooks.PreDrawHUD()
    if not render_target.world then
        render_target.world = { CreateFrameBufferMaterial( "World", true, true, false ) }
    end
    
    render.CopyRenderTargetToTexture( render_target.world[ 1 ] )
    render.SetMaterial( render_target.world[ 2 ] )
    render.DrawScreenQuad()
end

function hooks.InputMouseApply( cmd, x, y, angles )
    cmd:SetMouseX( -x )

    angles.yaw = angles.yaw + ( x / 45 )
    angles.pitch = math.Clamp( angles.pitch + ( y / 45 ), -89, 89 )

    cmd:SetViewAngles( angles )

    return true
end

-- Debugging
function Mirror_Test( enable )
    if enable then ROUND:Start() else ROUND:Finish() end
end

-- Round hooks
-- [SHARED] called when this particular round is selected by the chaos round logic
function ROUND:OnSelected()
end

-- [SHARED] called when preparation starts before the round starts
function ROUND:OnPrepare()
end

-- [SHARED] called when the round starts
function ROUND:Start()
     mirror_enabled = true
    
    if CLIENT then
        UnregisterHooks()
        RegisterHooks()
    end

    UnregisterPatches()
    RegisterPatches()
end

-- [SHARED] called when the round ends
function ROUND:Finish()
    mirror_enabled = false
    
    if CLIENT then
        UnregisterHooks()
        UnflipWeapons()
    end

    UnregisterPatches()
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
return RegisterChaosRound(ROUND)