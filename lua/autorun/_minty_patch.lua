-- SPDX-License-Identifier: MIT
-- (c) ppr_minty 2025

-- Library to facilitate 'safely' patching and unpatching functions in-place.
-- Source: https://github.com/minty-boo/minty-gmod-hydrogen/blob/main/lua/hydrogen/patch.lua

-- Note: In patched function environment, _f( ... ) will call the original function.

local mod = {}

-- Variables
mod.__meta = {
    ANGLE       = FindMetaTable( "Angle" ),
    ENTITY      = FindMetaTable( "Entity" ),
    PLAYER      = FindMetaTable( "Player" ),
    VECTOR      = FindMetaTable( "Vector" ),
}

local meta = {
    null = {},
    patch = {},
}

-- Utility
local function get_key_name( name, k )
    if name then return name .. '.' .. k end
    return k
end

-- Meta: null
local null = setmetatable( { __null = true }, meta.null )

function meta.null.__index( self, _ ) return null end
function meta.null.__newindex( self, _, _ ) end

-- Meta: patch
function meta.patch.__index( self, k )
    -- Trying to get patched function?
    if ( k == "__func" ) then k = 3 end

    -- Exists as child?
    if self.__patch[ k ] then return self.__patch[ k ] end
    
    -- Exists as meta-function?
    if meta.patch[ k ] then return meta.patch[ k ] end

    local name = ( self.__name and ( self.__name .. '.' .. k ) or k )
    local target = ( self.__table and self.__table[ k ] or ( _G[ k ] or mod.__meta[ k ] ) )
    local Tt = type( target )

    -- Ensure target table exists
    if ( Tt ~= "table" ) then
        ErrorNoHaltWithStack( "Invalid target table '" .. name .. "', got type '" .. Tt .. "'" )
        return null
    end
    
    -- Create child patch
    local child = meta.patch.New( name, self, target )
    rawset( self.__patch, k, child )

    return child
end

function meta.patch.__newindex( self, k, v )
    local name      = ( self.__name and ( self.__name .. '.' .. k ) or k )
    local table     = ( self.__table or _G )
    local target    = table[ k ]

    -- Ensure target exists
    if not target then
        ErrorNoHaltWithStack( "Invalid target: " .. k )
        return
    end

    -- Ensure type match
    local Tt = type( target )
    local Tv = type( v )

    if ( Tt ~= Tv ) then
        ErrorNoHaltWithStack( "Type mismatch for target '" .. name .. "', expected '", Tt, "' got '", Tv, "'" )
        return
    end

    -- Register patch
    if ( Tv == "function" ) then
        v = setfenv( v, setmetatable( { [ "_f" ] = target }, { __index = _G } ) )
    end

    self.__patch[ k ] = { table, target, v, name }
end

function meta.patch.Patch( self )
    if self.__active then self:Unpatch() end

    for k, v in pairs( self.__patch ) do
        if v.__patch then
            v:Patch()
        else
            v[ 1 ][ k ] = v[ 3 ]
        end
    end

    self.__active = true
end

function meta.patch.Unpatch( self )
    if not self.__active then return end

    for k, v in pairs( self.__patch ) do
        if v.__patch then
            v:Unpatch()
        else
            v[ 1 ][ k ] = v[ 2 ]
        end
    end

    self.__active = false
end

function meta.patch.New( name, super, table )
    local new = {
        __name = name,
        __super = super,
        __table = table,

        __active = false,
        __patch = {},
    }

    return setmetatable( new, meta.patch )
end

-- Functions
function mod.New() return meta.patch.New( false, false, false ) end

-- Export
minty = minty or {}
minty.patch = mod