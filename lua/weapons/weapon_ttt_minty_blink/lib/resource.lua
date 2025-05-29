-- SPDX-License-Identifier: BSD-3-Clause

AddCSLuaFile()

local _m = {}

-- Resources
resource.AddSingleFile( "materials/vgui/ttt/icon_minty_blink.vtf" )
resource.AddSingleFile( "materials/vgui/ttt/icon_minty_blink.vmt" )

resource.AddSingleFile( "sound/minty_blink/aim1.mp3" )
resource.AddSingleFile( "sound/minty_blink/aim2.mp3" )
resource.AddSingleFile( "sound/minty_blink/teleport1.mp3" )
resource.AddSingleFile( "sound/minty_blink/teleport2.mp3" )

--  Pre-cache
_m.sound        = {
    aim         = { Sound( "minty_blink/aim1.mp3" ), Sound( "minty_blink/aim2.mp3" ) },
    teleport    = { Sound( "minty_blink/teleport1.mp3" ), Sound( "minty_blink/teleport2.mp3" ) },
    overcharge  = { Sound( "ambient/energy/weld1.wav" ), Sound( "ambient/energy/weld2.wav" ) },
}

_m.icon         = "vgui/ttt/icon_minty_blink"

return _m