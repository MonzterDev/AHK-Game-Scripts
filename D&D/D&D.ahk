F3::
{
    WinActivate, Dark

    ; Wait for the window to become active, adjust the timeout as needed
    WinWaitActive, Dark,, 5

    if ErrorLevel ; Check if the window is active
    {
        MsgBox, Failed to activate the application window.
        return
    }

     ; Press and hold left shift using SendInput
    SendInput "{LShift Down}"

    ; Method 3 - Click at specified coordinates without moving the cursor
    CoordMode, Mouse, Screen ; Set coordinate mode to screen
    WinGetPos, vWinX, vWinY,,, A ; Get active window position

    ; Click at specified coordinates without moving the cursor
    ControlClick, % "x" -vWinX+1163 " y" -vWinY+252, A, , , D
    Sleep 100
    ControlClick, % "x" -vWinX+1161 " y" -vWinY+328, A, , , D
    Sleep 100
    ControlClick, % "x" -vWinX+1167 " y" -vWinY+410, A, , , D
    Sleep 100
    ControlClick, % "x" -vWinX+1158 " y" -vWinY+479, A, , , D
    Sleep 100
    ControlClick, % "x" -vWinX+1162 " y" -vWinY+552, A, , , D
    Sleep 100
    ControlClick, % "x" -vWinX+1161 " y" -vWinY+629, A, , , D
    Sleep 100
    ControlClick, % "x" -vWinX+1164 " y" -vWinY+705, A, , , D
    Sleep 100
    ControlClick, % "x" -vWinX+1160 " y" -vWinY+783, A, , , D
    Sleep 100
    ControlClick, % "x" -vWinX+1158 " y" -vWinY+855, A, , , D
    Sleep 100
    ControlClick, % "x" -vWinX+1162 " y" -vWinY+931, A, , , D
    Sleep 100

    ; Release left shift using SendInput
    SendInput "{LShift Up}"

    ; Click at specified coordinates without moving the cursor
    ControlClick, % "x" -vWinX+780 " y" -vWinY+988, A, , , D
    Sleep 100

    ; Press and hold end key using SendInput
    SendInput "{End}"

    ; Press space key using SendInput
    SendInput "{Space}"

    ; Sleep for 500 milliseconds
    Sleep 500

    ; SendRaw the specified string using SendInput
    SendInput "300 | 400 | 450 | 450 | 450 POWER BOOKS"

    ; Press enter key using SendInput
    SendInput "{Enter}"
}
