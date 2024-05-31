#Requires AutoHotkey v2.0+
#include ..\Libs\OCR.ahk ; https://github.com/Descolada/OCR

CHAR_1_POS := {x:1200, y:450}
CHAR_2_POS := {x:1200, y:550}
CHAR_2_POS := {x:1200, y:650}
; These are most obselete because we'll use OCR, but this can be helpful for hardcoded values

SELECTED_CHAR := CHAR_1_POS

F3::
{
    ; Send("{m Down}")
    ; Sleep(10)
    ; Send("{m Up}") ; Open map
    ; Sleep(1200)

    ; MouseClick("Left", 1430, 280, , , "Down") ; Click Eternity
    ; Sleep(200)
    ; MouseClick("Left", 1430, 280, , , "Up")
    ; Sleep(1200)

    ; MouseClick("Left", 550, 600, , , "Down") ; Click GoA
    ; Sleep(100)
    ; MouseClick("Left", 550, 600, , , "Up")
    ; Sleep(1200)

    ; MouseClick("Left", 1555, 820, , , "Down") ; Change mode
    ; Sleep(100)
    ; MouseClick("Left", 1555, 820, , , "Up")
    ; Sleep(1000)

    ; MouseClick("Left", 350, 350, , , "Down") ; Select Master
    ; Sleep(100)
    ; MouseClick("Left", 350, 350, , , "Up")
    ; Sleep(1000)

    ; MouseClick("Left", 1550, 888, , , "Down") ; Launch
    ; Sleep(100)
    ; MouseClick("Left", 1550, 888, , , "Up")
    ; Sleep(1000)

    ; while (true)
    ; {
    ;     OCRText := OCR.FromRect(1240, 980, 205, 35, "", scale:=1).Text  ; Specify language as needed, replace "" if different

    ;     if (InStr(OCRText, "PLAYER"))
    ;     {
    ;         ToolTip("FOUND PLAYER")
    ;         break  ; Exit loop when the condition is met
    ;     }

    ;     if (InStr(OCRText, "JOINED"))
    ;     {
    ;         ToolTip("FOUND JOINED")
    ;         break  ; Exit loop when the condition is met
    ;     }

    ;     Sleep(250)
    ; }

    ; ; We know a player has joined, so we can now proceed with the rest of the script

    ;; Change characters

    ; Send("{Esc Down}")
    ; Sleep(10)
    ; Send("{Esc Up}") ; Open escape menu
    ; Sleep(1200)

    ; MouseClick("Left", 800, 600, , , "Down") ; Change character
    ; Sleep(100)
    ; MouseClick("Left", 800, 600, , , "Up")
    ; Sleep(1000)
    ; Send("{Enter Down}")
    ; Sleep(10)
    ; Send("{Enter Up}")
    ; Sleep(5000)

    ; MouseClick("Left", SELECTED_CHAR.x, SELECTED_CHAR.y, , , "Down") ; Select character
    ; Sleep(100)
    ; MouseClick("Left", SELECTED_CHAR.x, SELECTED_CHAR.y, , , "Up")
    ; Sleep(1000)


    ;; Rejoin player

    ; FriendFound := OCR.FromWindow("Destiny 2", , scale:=1)
    ; try found := FriendFound.FindString("Hunter")
    ; FriendFound.Click(FriendFound.FindString("Hunter"))
    ; ToolTip(FriendFound)

    SelectPlanet("EDZ")
}
return

SelectCharacter(character := "Hunter") {
    ; Define a list of valid classes
    validClasses := ["Hunter", "Warlock", "Titan"]

    ; Check if the specified character is one of the valid classes
    if (!IsInArray(validClasses, character)) {
        MsgBox("Class must be Hunter, Warlock, or Titan")
        return  ; Exit the function if the character is not valid
    }

    ; Perform OCR to find the character in the game window
    result := OCR.FromWindow("Destiny 2", , scale:=1)  ; Ensure parameter placeholders are correct

    ; Attempt to find the character string in the OCR results
    try {
        char := result.FindString(character)
        if (char) {
            result.Click(char)
        } else {
            MsgBox("Character '" . character . "' not found.")
        }
    } catch as err {
        MsgBox("An error occurred: " . err.message)
    }
}

SelectPlanet(planet := "ROME") {
    ; Define a list of valid classes
    ; Cosmodrone isn't easily read, so ROME is easiest
    validPlanets := ["NEPTUNE", "EUROPA", "THRONE", "EDZ", "TOWER", "ROME", "MOON", "NESSUS", "DREAMING", "ETERNITY", "H.E.L.M", "INTO"]

    ; Check if the specified character is one of the valid classes
    if (!IsInArray(validPlanets, planet)) {
        MsgBox("Invalid planet")
        return  ; Exit the function if the character is not valid
    }

    result := OCR.FromWindow("Destiny 2", , scale:=1)  ; Ensure parameter placeholders are correct

    textLocation := ""
    for line in result.Lines {
        if (InStr(line.Text, planet)) {
            textLocation := [line.x - 30, line.y]
            break
        }
    }

    MouseClick("Left", textLocation[1], textLocation[2], , , "Down")  ; Click on the planet MouseClick(" MouseClick("
    return  ; Exit the function if the planet is not valid
}

; Helper function to check if an item is in an array
IsInArray(arr, item) {
    for index, value in arr {
        if (value == item)
            return true
    }
    return false
}
