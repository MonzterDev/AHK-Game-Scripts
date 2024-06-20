#Warn All, OutputDebug
#SingleInstance force
#Requires AutoHotkey v2.0+
#include ..\Libs\OCR.ahk ; https://github.com/Descolada/OCR
#include .\Helper.ahk

; https://github.com/MonzterDev/AHK-Game-Scripts
; VERSION: 1.0.1

OCR_SCALE := 3

CORDINATES := {
    1920x1080: {
        ViewMarket: {x: 850, y: 115},
        ResetFilters: {x: 1785, y: 200},

        StashRectangle: {x: 1333, y: 140, width: 577, height: 890},
        SearchResultRectangle: {x: 0, y: 265, width: 1920, height: 270},
    },
    2560x1440: {
        ViewMarket: {x: 1130, y: 155},
        ResetFilters: {x: 2380, y: 270},


        StashRectangle: {x: 1777, y: 187, width: 769, height: 1187},
        SearchResultRectangle: {x: 0, y: 357, width: 2560, height: 204},
    }
}

screenResolution := A_ScreenWidth "x" A_ScreenHeight
OutputDebug("Resolution: " screenResolution '`n')
resolution := ""
if (screenResolution = "1920x1080") {
    resolution := CORDINATES.1920x1080
} else if (screenResolution = "2560x1440") {
    resolution := CORDINATES.2560x1440
}


F3::
{
    ; Get resolution of the screen
    screenResolution := A_ScreenWidth "x" A_ScreenHeight
    OutputDebug("Resolution: " screenResolution '`n')

    stashRectangle := resolution.StashRectangle
    ocrResult := OCR.FromRect(stashRectangle.x, stashRectangle.y, stashRectangle.width, stashRectangle.height, , OCR_SCALE).Text  ; Scans Stash area in auction window for item

    rarity := GetItemRarity(ocrResult)
    itemName := GetItemName(ocrResult)
    enchantments := GetItemEnchantments(ocrResult)

    if (itemName = "") {
        ToolTip("Item not found, try again.")
        SetTimer RemoveToolTip, -2000 ; Set timer to remove tooltip after 2 seconds
        return
    }

    ; Now we swap to view market tab
    ; MouseClick("Left", 850, 115, ,) ; View Market button
    ; FindAndClickString("View Market")

    ocrResult := OCR.FromDesktop(, OCR_SCALE)
    ocrResult.Click(ocrResult.FindString("View Market"))
    Sleep(500)

    ocrResult := OCR.FromDesktop(, OCR_SCALE)
    ocrResult.Click(ocrResult.FindString("Reset Filters"))
    ; MouseClick("Left", 1785, 200, ,) ; Reset Filters button
    Sleep(400)

    ocrResult := OCR.FromDesktop(, OCR_SCALE)
    ; MouseClick("Left", 400, 200, , ) ; Click rarity selection
    ocrResult.Click(ocrResult.FindString("Rarity"))
    Sleep(100)
    ocrResult := OCR.FromDesktop(, OCR_SCALE)
    ocrResult.Click(ocrResult.FindString("Enter text"))
    ; MouseClick("Left", 150, 250, , ) ; Click item name search box
    Send(rarity) ; Type item name
    Sleep(100)

    searchResultRectangle := resolution.SearchResultRectangle
    FindAndClickString(rarity, searchResultRectangle.x, searchResultRectangle.y, searchResultRectangle.width, searchResultRectangle.height) ; Find and click item name
    ; ClickItemRarity(rarity)
    Sleep(100)

    ocrResult.Click(ocrResult.FindString("Item Name"))
    ; MouseClick("Left", 150, 200, , ) ; Click item name selection
    Sleep(100)
    ocrResult := OCR.FromDesktop(, OCR_SCALE)
    ocrResult.Click(ocrResult.FindString("Enter text"))
    ; MouseClick("Left", 150, 250, , ) ; Click item name search box
    Send(itemName) ; Type item name
    Sleep(100)

    FindAndClickString(itemName, searchResultRectangle.x, searchResultRectangle.y, searchResultRectangle.width, searchResultRectangle.height) ; Find and click item name

    ocrResult.Click(ocrResult.FindString("Random Attribute"))
    ; MouseClick("Left", 1500, 200, , ) ; Click random attributes
    Sleep(100)

    ; Loop through enchantments and send each one
    enchantmentYValue := 278

    for enchantment in enchantments {
        ocrResult := OCR.FromDesktop(, OCR_SCALE)
        ocrResult.Click(ocrResult.FindString("Enter text"))
        Sleep(100)

        OutputDebug("Enchantment: " enchantment '`n')
        Send(enchantment)
        Sleep(100)
        FindAndClickString(enchantment, searchResultRectangle.x, searchResultRectangle.y, searchResultRectangle.width, searchResultRectangle.height) ; Find and click enchantment
        ; MouseClick("Left", 1500, enchantmentYValue) ; Click enchantment name
        Sleep(100)
        ; MouseClick("Left", 1500, 241) ; Click enchantment name search box
        Sleep(100)
        ; Send("^a{BS}") ; Clear textbox
        enchantmentYValue += 26
    }

    Sleep(100)
    ocrResult := OCR.FromDesktop(, OCR_SCALE)
    ocrResult.Click(ocrResult.FindString("Search"))
    ; MouseClick("Left", 1800, 276, , ) ; Click search
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
        MouseClick("Left", 400, 325, , ) ; Click rarity
    } else if (rarity = "Common") {
        MouseClick("Left", 400, 299, , ) ; Click rarity
    } else if (rarity = "Rare") {
        MouseClick("Left", 400, 350, , ) ; Click rarity
    } else if (rarity = "Epic") {
        MouseClick("Left", 400, 375, , ) ; Click rarity
    } else if (rarity = "Legend") {
        MouseClick("Left", 400, 400, , ) ; Click rarity
    } else if (rarity = "Unique") {
        MouseClick("Left", 400, 425, , ) ; Click rarity
    }
}

GetItemName(ocrResult) {
    itemName := ""
    ; TODO
    ; I tried using a while loop here because sometimes the OCR cannot detect the text.
    ; This didnt actually solve the issue. For now, just use hotkey again.
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

        OutputDebug("Enchantment OCR result: " ocrResult '`n')

        for enchantmentI in ENCHANTMENTS {
            ; Make the search case-sensitive
            if InStr(ocrResult, enchantmentI, true) {
                enchantmentsFound.Push(enchantmentI)
            }
        }
    }


    return enchantmentsFound
}

FindAndClickString(string, x:="", y:="", width:="", height:="") {
    ocrResult := OCR.FromDesktop(, OCR_SCALE)
    if (height != "") {
        ocrResult := OCR.FromRect(x, y, width, height, , OCR_SCALE)
    }

    text := ocrResult.Text

    OutputDebug("Item nameeeeeeeeeee: " string '`n`n')

    for line in ocrResult.Lines {
        OutputDebug("Line: " line.Text '`n')

        ; Normalize spaces by removing extra spaces and then checking if the name is in the line
        normalizedLine := StrReplace(line.Text, " ", "")
        normalizedItemName := StrReplace(string, " ", "")

        if (InStr(normalizedLine, normalizedItemName) && StrLen(normalizedLine) = StrLen(normalizedItemName)) {
            OutputDebug("Exact match found: " line.Text '`n')
            ; ocrResult.Highlight(line)
            ocrResult.Click(line)
            break
        }
    }
}
