-- SPDX-License-Identifier: BSD-3-Clause

AddCSLuaFile()

local _m            = {}
local cvar_flags    = FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_SERVER_CAN_EXECUTE

_m.charge_count = CreateConVar(
    "ttt_minty_blink_charge_count",
    "4",
    cvar_flags,
    "Blink charge count."
)

_m.charge_time = CreateConVar(
    "ttt_minty_blink_charge_time",
    "2.5",
    cvar_flags,
    "Blink recharge time in seconds."
)

_m.overcharge_damage = CreateConVar(
    "ttt_minty_blink_overcharge_damage",
    "0",
    cvar_flags,
    "Allows blinking when not fully charged, at the cost of player health. Set to '0' to disable."
)

_m.range = CreateConVar( 
    "ttt_minty_blink_range",
    "2048",
    cvar_flags,
    "Maximum distance."
)

_m.post_process = CreateConVar(
    "ttt_minty_blink_post_process",
    "0",
    cvar_flags,
    "Enables/disables post-processing effects."
)

return _m