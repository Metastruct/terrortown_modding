-- SPDX-License-Identifier: BSD-3-Clause

AddCSLuaFile()

local _m            = {}
local cvar_flags    = FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_SERVER_CAN_EXECUTE

_m.charge_count = CreateConVar(
    "ttt_minty_blink_charge_count",
    "0",
    cvar_flags,
    "Blink charge count. Enables 'limited' mode if non-negative and non-zero."
)

_m.charge_cost = CreateConVar(
    "ttt_minty_blink_charge_cost",
    "50",
    cvar_flags,
    "Cost per blink charge (does not affect 'limited' mode)."
)

_m.charge_max = CreateConVar(
    "ttt_minty_blink_charge_max",
    "100",
    cvar_flags,
    "Maximum charge (does not affect 'limited' mode)."
)

_m.charge_exhaust_scalar = CreateConVar(
    "ttt_minty_blink_charge_exhaust_scalar",
    "0.75",
    cvar_flags,
    "Relative amount of capped maximum charge to deplete, if blink is used when not fully recharged."
)

_m.charge_recharge_rate = CreateConVar(
    "ttt_minty_blink_charge_recharge_rate",
    "15",
    cvar_flags,
    "Recharge rate, in charge/sec (does not affect 'limited' mode)."
)

_m.range = CreateConVar( 
    "ttt_minty_blink_range",
    "3072",
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