#Requires AutoHotkey v2.0

F3::
{
    WinActivate "Dark and Darker"

    ; Press and hold left shift using SendInput
    SendInput "{LShift Down}"

    ; Click at specified coordinates
    MouseMove 1135, 214
    Click "Left", 1
    Sleep 100
    MouseMove 1175, 215
    Click "Left", 1
    Sleep 100
    MouseMove 1167, 410
    Click "Left", 1
    Sleep 100
    MouseMove 1158, 479
    Click "Left", 1
    Sleep 100
    MouseMove 1162, 552
    Click "Left", 1
    Sleep 100
    MouseMove 1161, 629
    Click "Left", 1
    Sleep 100
    MouseMove 1164, 705
    Click "Left", 1
    Sleep 100
    MouseMove 1160, 783
    Click "Left", 1
    Sleep 100
    MouseMove 1158, 855
    Click "Left", 1
    Sleep 100
    MouseMove 1162, 931
    Click "Left", 1
    Sleep 100

    ; Release left shift using SendInput
    SendInput "{LShift Up}"

    ; Click at specified coordinates
    MouseMove 780, 988
    Click "  ", 1
    Sleep 100

    ; Press and hold end key using SendInput
    SendInput "{End}"

    ; Press space key using SendInput
    SendInput "{Space}"

    ; Sleep for 500 milliseconds
    Sleep 500

    ; SendRaw the specified string using SendInput
    SendInput "300 | 400 | 450 | 450 | 450 | 500 POWER BOOKS"

    ; Press enter key using SendInput
    SendInput "{Enter}"
}
