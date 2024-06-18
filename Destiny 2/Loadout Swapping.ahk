#Requires AutoHotkey v2.0+

; https://github.com/MonzterDev/AHK-Game-Scripts

; Swap between loadouts instantly
; Made by Monzter :D
; Use Ctrl + 1-0 to switch loadouts
; If not working, adjust line #29

LOADOUTS := [
    {x: 150, y: 350},
    {x: 250, y: 350},
    {x: 150, y: 450},
    {x: 250, y: 450},
    {x: 150, y: 550},
    {x: 250, y: 550},
    {x: 150, y: 650},
    {x: 250, y: 650},
    {x: 150, y: 750},
    {x: 250, y: 750},
]

SelectLoadout(n) {
    if (n < 1 || n > 10) {
        return
    }

    Send("{i Down}") ; Open inventory
    Sleep(10)
    Send("{i Up}")
    Sleep(1200) ; MAY NEED TO BE UPDATED BASED ON YOUR LOAD ANIMATION. ADJUST BY +100 OR -100

    Send("{Left Down}") ; Open loadouts
    Sleep(10)
    Send("{Left Up}")
    Sleep(900)

    loadoutCords := LOADOUTS[n]
    MouseClick("Left", loadoutCords.x, loadoutCords.y)
    Sleep(200)
    MouseClick("Left", loadoutCords.x, loadoutCords.y)
    Sleep(100)
    MouseClick("Left", loadoutCords.x, loadoutCords.y)
    Sleep(100)
    MouseClick("Left", loadoutCords.x, loadoutCords.y)
    Sleep(100)

    Send("{i Down}") ; Open inventory
    Sleep(10)
    Send("{i Up}")
}

; Call select loadout when Ctrl + 1-0 is pressed

^1::SelectLoadout(1)
^2::SelectLoadout(2)
^3::SelectLoadout(3)
^4::SelectLoadout(4)
^5::SelectLoadout(5)
^6::SelectLoadout(6)
^7::SelectLoadout(7)
^8::SelectLoadout(8)
^9::SelectLoadout(9)
^0::SelectLoadout(10)
