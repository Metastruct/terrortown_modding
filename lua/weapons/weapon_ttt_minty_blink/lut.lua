-- SPDX-License-Identifier: 0BSD

AddCSLuaFile()

local _m = {}

_m.collision_check_size = 12
_m.ledge_step_max       = 4
_m.ledge_step_size      = 8
_m.trace_hull_size      = 4
_m.trace_ledge_depth    = 2

_m.trace_hull           = Vector( trace_hull_size, trace_hull_size, trace_hull_size )

_m.trace_ledge_up       = {}

for i = 1, _m.ledge_step_max do
    _m.trace_ledge_up[ i ] = Vector( 0, 0, i * _m.ledge_step_size )
end

_m.lut_wall     = {
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

_m.lut_ledge    = {
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

_m.lut_floor    = {
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