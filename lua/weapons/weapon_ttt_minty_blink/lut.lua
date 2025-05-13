-- SPDX-License-Identifier: 0BSD

AddCSLuaFile()

local _m = {}

_m.__size   = 12

_m.wall     = {
    Vector( 1, 0, 0 ),
    Vector( 1, 0, 1 ),
    Vector( 1, -1, 0 ),
    Vector( 1, 1, 0 ),

    Vector( 2, 0, 0 ),
    Vector( 2, 0, 1 ),
    Vector( 2, -1, 0 ),
    Vector( 2, 1, 0 ),
    Vector( 2, -2, 0 ),
    Vector( 2, 2, 0 ),
}

_m.ledge    = {
    Vector( 0, 0, 0 ),
    Vector( 0, 0, 1 ),
    Vector( 0, -1, 0 ),
    Vector( 0, 1, 0 ),
    Vector( 0, -2, 0 ),
    Vector( 0, 2, 0 ),

    Vector( 1, 0, 0 ),
    Vector( 1, 0, 1 ),
    Vector( 1, -1, 0 ),
    Vector( 1, 1, 0 ),
}

_m.floor    = {
    Vector( 0, 0, 0 ),
    Vector( 1, 0, 0 ),
    Vector( 0, -1, 0 ),
    Vector( 0, 1, 0 ),
    Vector( 0, 0, -1 ),
    Vector( 0, 0, 1 ),
    Vector( 0, -1, -1 ),
    Vector( 0, 1, 1 ),
    Vector( 0, -1, 1 ),
    Vector( 0, 1, -1 ),
    Vector( 0, -2, 0 ),
    Vector( 0, 2, 0 ),
    Vector( 0, 0, -2 ),
    Vector( 0, 0, 2 ),
}

return _m