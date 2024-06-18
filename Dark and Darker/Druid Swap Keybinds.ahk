#SingleInstance force
#Requires AutoHotkey v2.0+
#include ..\Libs\OCR.ahk ; https://github.com/Descolada/OCR

; https://github.com/MonzterDev/AHK-Game-Scripts

CHAR_PANTHER := { x: -1000, y: 0 }
CHAR_BEAR := { x: 1000, y: 0 }
CHAR_CHICKEN := { x: -250, y: 1000 }
CHAR_HUMAN := { x: 0, y: -1000 }
CHAR_RAT := { x: 250, y: 1000 }

F1::
{
    SwitchCharacter("Human")
}
F2::
{
    SwitchCharacter("Rat")
}
F3::
{
    SwitchCharacter("Chicken")
}
F4::
{
    SwitchCharacter("Bear")
}
F5::
{
    SwitchCharacter("Panther")
}

F6::
{
    ; TODO
    ; Rat Human swap
    ; I had an idea to make a macro that would make going through door windows easier.
    SwitchCharacter("Rat")
    Sleep(700)
    SwitchCharacter("Human")
}
F7::
{
    ; TODO
    ; Panther Chicken Human swap
    ; Another idea I've considered is perfecting the Panther jump + dash + chicken + jump + jump + human combo.
}

SwitchCharacter(character := "Panther") {
    Send("{q Down}")
    Sleep(1)

    pos := ""
    switch character {
        case "Panther":
            pos := CHAR_PANTHER
        case "Bear":
            pos := CHAR_BEAR
        case "Chicken":
            pos := CHAR_CHICKEN
        case "Human":
            pos := CHAR_HUMAN
        case "Rat":
            pos := CHAR_RAT
    }

    MouseMove pos.x, pos.y, 1, "R"
    Sleep(1)

    Send("{q Up}")
}
