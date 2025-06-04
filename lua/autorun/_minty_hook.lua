-- SPDX-License-Identifier: MIT
-- (c) ppr_minty 2025

-- Library to facilitate easily registering and unregistering temporary hooks (with optional context).
-- Source: https://github.com/minty-boo/minty-gmod-hydrogen/blob/main/lua/hydrogen/hook.lua

-- Note: If 'context' is passed, it can be accessed inside a hook's callback with 'self'.

local mod = {}

-- Variables
local meta = {}

-- Meta: hook
function meta.__index( self, k )
    -- Exists as meta-function?
    if meta[ k ] then return meta[ k ] end

    -- Exists in hooks table?
    if self.__hook[ k ] then return self.__hook[ k ] end
end

function meta.__newindex( self, k, v )
    local id = ( k .. '.' .. self.__id .. '@' .. self.__name )
    self.__id = self.__id + 1

    self.__hook[ id ] = { k, setfenv( v, setmetatable( { [ "self" ] = self.__context }, { __index = _G } ) ) }
end

function meta.Register( self )
    if self.__active then self:Unregister() end

    for k, v in pairs( self.__hook ) do
        hook.Add( v[ 1 ], k, v[ 2 ] )
    end

    self.__active = true
end

function meta.Unregister( self )
    if not self.__active then return end

    for k, v in pairs( self.__hook ) do
        hook.Remove( v[ 1 ], k )
    end

    self.__active = true
end

-- Functions
function mod.New( name, context )
    local new = {
        __name      = name,
        __context   = context,
        __id        = 1,

        __active    = false,
        __hook      = {},
    }

    return setmetatable( new, meta )
end

-- Export
minty = minty or {}
minty.hook = mod