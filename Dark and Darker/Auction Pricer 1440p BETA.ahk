#SingleInstance force
#Requires AutoHotkey v2.0+
#include ..\Libs\OCR.ahk ; https://github.com/Descolada/OCR
#include .\Helper.ahk

; https://github.com/MonzterDev/AHK-Game-Scripts

F3::
{
    ocrResult := OCR.FromRect(1777, 187, 769, 1187, , scale:=1).Text  ; Scans Stash area in auction window for item

    rarity := GetItemRarity(ocrResult)
    itemName := GetItemName(ocrResult)
    enchantments := GetItemEnchantments(ocrResult)

    coordinates := [
        {x: 97, y: 357, width: 251, height: 30},
        {x: 97, y: 393, width: 251, height: 30},
        {x: 97, y: 426, width: 251, height: 30},
        {x: 97, y: 460, width: 251, height: 30},
        {x: 97, y: 496, width: 251, height: 30},
        {x: 97, y: 531, width: 251, height: 30}
    ]

    if (itemName = "") {
        ToolTip("Item not found, try again.")
        SetTimer RemoveToolTip, -2000 ; Set timer to remove tooltip after 2 seconds
        return
    }



    ; Now we swap to view market tab
    MouseClick("Left", 1133, 153, ,) ; View Market button
    Sleep(500)

    MouseClick("Left", 2380, 267, ,) ; Reset Filters button
    Sleep(400)

    MouseClick("Left", 533, 267, , ) ; Click rarity selection
    Sleep(100)

    ClickItemRarity(rarity)
    Sleep(100)

    MouseClick("Left", 200, 267, , ) ; Click item name selection
    Sleep(100)
    MouseClick("Left", 200, 333, , ) ; Click item name search box
    Send(itemName) ; Type item name
    Sleep(100)
    for each, rect in coordinates {
        ; Perform OCR on the current rectangle
        ocrResult := OCR.FromRect(rect.x, rect.y, rect.width, rect.height, , scale:=1).Text

        ;Print the text found within the rectangle (for debug)
        ;MsgBox("Text found in rectangle at Y=" rect.y ": " ocrResult)

        ; Check if the text matches the itemName
        if (ocrResult = itemName) {
            ;MsgBox("Exact match found: " ocrResult) ;this is for debug also

            ; Perform a left-click 15 pixels below the exact match found
            MouseClick("Left", rect.x + (rect.width // 2), rect.y + 15 + (rect.height // 2))

            break
        }
    }

    MouseClick("Left", 2000, 267, , ) ; Click random attributes
    Sleep(100)
    MouseClick("Left", 2000, 322) ; Click enchantment name search box
    Sleep(250)
    Send("^a{BS}") ; Clear textbox
    Sleep(100)

    ; Loop through enchantments and send each one
    enchantmentYValue := 370

    for enchantment in enchantments {
        Send(enchantment)
        Sleep(100)
        MouseClick("Left", 2000, enchantmentYValue) ; Click enchantment name
        Sleep(100)
        MouseClick("Left", 2000, 322) ; Click enchantment name search box
        Sleep(100)
        Send("^a{BS}") ; Clear textbox
        enchantmentYValue += 35
    }






    Sleep(100)
    MouseClick("Left", 2400, 367, , ) ; Click search
}

RemoveToolTip() {
    ToolTip  ; Remove the tooltip
}

GetItemRarity(ocrResult) {
    rarity := ""
    if InStr(ocrResult, "Uncommon") {
        rarity := "Uncommon"
    } else if InStr(ocrResult, "Common") {
        rarity := "Common"
    } else if InStr(ocrResult, "Rare") {
        rarity := "Rare"
    } else if InStr(ocrResult, "Epic") {
        rarity := "Epic"
    } else if InStr(ocrResult, "Legend") {
        rarity := "Legend"
    } else if InStr(ocrResult, "Unique") {
        rarity := "Unique"
    }

    return rarity
}

ClickItemRarity(rarity) {
    if (rarity = "Uncommon") {
        MouseClick("Left", 533, 433, , ) ; Click rarity
    } else if (rarity = "Common") {
        MouseClick("Left", 533, 399, , ) ; Click rarity
    } else if (rarity = "Rare") {
        MouseClick("Left", 533, 467, , ) ; Click rarity
    } else if (rarity = "Epic") {
        MouseClick("Left", 533, 500, , ) ; Click rarity
    } else if (rarity = "Legend") {
        MouseClick("Left", 533, 533, , ) ; Click rarity
    } else if (rarity = "Unique") {
        MouseClick("Left", 533, 567, , ) ; Click rarity
    }
}

GetItemName(ocrResult) {
    itemName := ""
    ; TODO
    ; I tried using a while loop here because sometimes the OCR cannot detect the text.
    ; This didn't actually solve the issue. For now, just use hotkey again.
    while (itemName = "" && A_Index <= 3) {
        for i, item in ITEMS {
            if InStr(ocrResult, item) {
                itemName := item
                break
            }
        }

        if (itemName = "") {
            Sleep(100)
        }
    }

    return itemName
}

GetItemEnchantments(ocrResult) {
    enchantmentsFound := []

    ; Locate the first "+" symbol in the OCR result
    plusPos := InStr(ocrResult, "+")

    ; If "+" is found, start looking for enchantments after this position
    if (plusPos > 0) {
        ocrResult := SubStr(ocrResult, plusPos + 1)

        for enchantmentI in ENCHANTMENTS {
            ; Make the search case-sensitive
            if InStr(ocrResult, enchantmentI, true) {
                enchantmentsFound.Push(enchantmentI)
            }
        }
    }

    return enchantmentsFound
}

F4::
{
    ocrResult := OCR.FromRect(1777, 187, 769, 1187, , scale:=1).Text  ; Scans Stash area in auction window for item

    rarity := GetItemRarity(ocrResult)
    itemName := GetItemName(ocrResult)

    coordinates := [
        {x: 97, y: 357, width: 251, height: 30},
        {x: 97, y: 393, width: 251, height: 30},
        {x: 97, y: 426, width: 251, height: 30},
        {x: 97, y: 460, width: 251, height: 30},
        {x: 97, y: 496, width: 251, height: 30},
        {x: 97, y: 531, width: 251, height: 30}
    ]

    if (itemName = "") {
        ToolTip("Item not found, try again.")
        SetTimer RemoveToolTip, -2000 ; Set timer to remove tooltip after 2 seconds
        return
    }

    ; Now we swap to view market tab
    MouseClick("Left", 1133, 153, ,) ; View Market button
    Sleep(500)

    MouseClick("Left", 2380, 267, ,) ; Reset Filters button
    Sleep(400)

    MouseClick("Left", 533, 267, , ) ; Click rarity selection
    Sleep(100)

    ClickItemRarity(rarity)
    Sleep(100)

    MouseClick("Left", 200, 267, , ) ; Click item name selection
    Sleep(100)
    MouseClick("Left", 200, 333, , ) ; Click item name search box
    Send(itemName) ; Type item name
    Sleep(100)
    for each, rect in coordinates {
        ; Perform OCR on the current rectangle
        ocrResult := OCR.FromRect(rect.x, rect.y, rect.width, rect.height, , scale:=1).Text

        ; Print the text found within the rectangle (for debug)
        ; MsgBox("Text found in rectangle at Y=" rect.y ": " ocrResult)

        ; Check if the text matches the itemName
        if (ocrResult = itemName) {
            ; MsgBox("Exact match found: " ocrResult) ; this is for debug also

            ; Perform a left-click 15 pixels below the exact match found
            MouseClick("Left", rect.x + (rect.width // 2), rect.y + 15 + (rect.height // 2))

            break
        }
    }

    MouseClick("Left", 2000, 267, , ) ; Click random attributes
    Sleep(100)
    MouseClick("Left", 2000, 322) ; Click enchantment name search box
    Sleep(250)
    Send("^a{BS}") ; Clear textbox
    Sleep(100)

    Sleep(100)
    MouseClick("Left", 2400, 367, , ) ; Click search
}
