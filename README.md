# WindfuryComm++

Allows Shamans to see WF time of melee party members.

## Description

Addon for both Shamans and Melee, transmitting WF weapon enchant timer to party members, and for Shaman shows the WF timer for melee party members.

UI is only shown for Shamans, other users won't see any UI elements, it will only transmit the time of WF on their weapon. Use shift+drag to move it on screen.

## Features

🤺 **Melee** - without this, your Shaman won't be able to see your WF uptime.

- NEW!! v2 now tracks ALL important totems, see them in a HUD for the last fight or overall, now you'll know how good your Shaman is!
- Transmits WF time left and in combat status.
- No party chat spam!
- Tracks and prints WF uptime (visible only to you).
- Will add a UI that shows WF/Str/Agi uptime for last fight and average.

🧝🏻‍♂️ **Shamans** see neat UI with an icon per melee party member, and:

- Time on each melee WF.
- Visible indication when a party member is missing WF.
- Indication is RED when player is in combat, or dim yellow when isn't.
- Ignoring dead players.
- Move frame around by holding SHIFT and dragging frame around with mouse.

## Other features

- WFLib v4, sends much less addon messages.
- *Very light on resource use* - only 46k memory use and 0% CPU most times.
  - For comparison, a WeakAura with same functionality uses 25% CPU (7 ms!).

Commands

- `/wfc` - print commands help
- `/wfc warn <size>` - sets missing WF warning indication size, default 4.
- `/wfc print` - (shamans) print party members uptime after combat ends
- `/wfc lock` - toggle frame position lock
- `/wfcomm orientation <horizontal/vertical>` - sets frame layout, default horizontal.
- `/wfcomm size <integer>` - sets frame scale, default 24.
- `/wfcomm spacing <integer>` - sets spacing of frame members, default 4.
- `/wfcomm <hide/show>` - show or hide the UI frame.
- `/wfcomm ar` - toggles reporting of WF uptime after each fight, or only after boss encounters.

This is an improved version, based on the old [WindfuryComm](https://www.curseforge.com/wow/addons/windfurycomm) addon. When using this addon, you can safely remove other WfLib based addons, remove WeakAuras [WF Now!](https://wago.io/SwYL-B9lU), [Windfury Alert](https://wago.io/SwYL-B9lU) and the addon [Windfury HUD](https://www.curseforge.com/wow/addons/windfury-hud) to avoid redundant load.
