#SingleInstance force
#Requires AutoHotkey v2.0+
#include ..\Libs\OCR.ahk ; https://github.com/Descolada/OCR
#include .\Helper.ahk

; https://github.com/MonzterDev/AHK-Game-Scripts

F3::HandleAuctionSearch()
F4::HandleAuctionSearchSimple()

HandleAuctionSearch() {
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
        ShowTemporaryToolTip("Item not found, try again.", 2000)
        return
    }

    ; Now we swap to view market tab
    MouseClick("Left", 1133, 153) ; View Market button
    Sleep(500)

    MouseClick("Left", 2380, 267) ; Reset Filters button
    Sleep(400)

    MouseClick("Left", 533, 267) ; Click rarity selection
    Sleep(100)

    ClickItemRarity(rarity)
    Sleep(100)

    MouseClick("Left", 200, 267) ; Click item name selection
    Sleep(100)
    MouseClick("Left", 200, 333) ; Click item name search box
    Send(itemName) ; Type item name
    Sleep(100)

    for each, rect in coordinates {
        ; Perform OCR on the current rectangle
        ocrResult := OCR.FromRect(rect.x, rect.y, rect.width, rect.height, , scale:=1).Text

        ; Check if the text matches the itemName
        if (ocrResult = itemName) {
            ; Perform a left-click 15 pixels below the exact match found
            MouseClick("Left", rect.x + (rect.width // 2), rect.y + 15 + (rect.height // 2))
            break
        }
    }

    MouseClick("Left", 2000, 267) ; Click random attributes
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
    MouseClick("Left", 2400, 367) ; Click search
}

ShowTemporaryToolTip(text, duration) {
    ToolTip(text)
    SetTimer RemoveToolTip, -duration
}

RemoveToolTip() {
    ToolTip  ; Remove the tooltip
}

GetItemRarity(ocrResult) {
    rarities := ["Uncommon", "Common", "Rare", "Epic", "Legend", "Unique"]
    for each, rarity in rarities {
        if InStr(ocrResult, rarity) {
            return rarity
        }
    }
    return ""
}

ClickItemRarity(rarity) {
    positions := Map()
    positions["Uncommon"] := 433
    positions["Common"] := 399
    positions["Rare"] := 467
    positions["Epic"] := 500
    positions["Legend"] := 533
    positions["Unique"] := 567
    MouseClick("Left", 533, positions[rarity])
}

GetItemName(ocrResult) {
    global ITEMS
    for each, item in ITEMS {
        if InStr(" " ocrResult " ", " " item " ") {
            return item
        }
    }
    return ""
}

GetItemEnchantments(ocrResult) {
    global ENCHANTMENTS
    enchantmentsFound := []

    ; Add spaces around the OCR result to ensure word boundaries
    ocrResult := " " ocrResult " "

    ; Locate the first "+" symbol in the OCR result
    plusPos := InStr(ocrResult, "+")
    
    ; If "+" is found, start looking for enchantments after this position
    if (plusPos > 0) {
        ocrResult := SubStr(ocrResult, plusPos + 1)

        ; Check for specific enchantments first and ignore "Max Health" if "Max Health Bonus" is present
        specificEnchantments := ["Max Health Bonus"]
        for each, specific in specificEnchantments {
            if InStr(ocrResult, " " specific " ") {
                enchantmentsFound.Push(specific)
                ; Remove specific enchantments from the OCR result to avoid double matching
                ocrResult := StrReplace(ocrResult, " " specific " ", " ")
            }
        }

        ; Check for other enchantments
        for each, enchantment in ENCHANTMENTS {
            ; Ensure exact match by using a regular expression with word boundaries
            if RegExMatch(ocrResult, "\b" . RegExReplace(enchantment, " ", "\s") . "\b") {
                enchantmentsFound.Push(enchantment)
            }
        }
    }

    return enchantmentsFound
}

HandleAuctionSearchSimple() {
    ; Simplified version of HandleAuctionSearch for F4
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
        ShowTemporaryToolTip("Item not found, try again.", 2000)
        return
    }

    ; Now we swap to view market tab
    MouseClick("Left", 1133, 153) ; View Market button
    Sleep(500)

    MouseClick("Left", 2380, 267) ; Reset Filters button
    Sleep(400)

    MouseClick("Left", 533, 267) ; Click rarity selection
    Sleep(100)

    ClickItemRarity(rarity)
    Sleep(100)

    MouseClick("Left", 200, 267) ; Click item name selection
    Sleep(100)
    MouseClick("Left", 200, 333) ; Click item name search box
    Send(itemName) ; Type item name
    Sleep(100)

    for each, rect in coordinates {
        ; Perform OCR on the current rectangle
        ocrResult := OCR.FromRect(rect.x, rect.y, rect.width, rect.height, , scale:=1).Text

        ; Check if the text matches the itemName
        if (ocrResult = itemName) {
            ; Perform a left-click 15 pixels below the exact match found
            MouseClick("Left", rect.x + (rect.width // 2), rect.y + 15 + (rect.height // 2))
            break
        }
    }

    MouseClick("Left", 2000, 267) ; Click random attributes
    Sleep(100)
    MouseClick("Left", 2000, 322) ; Click enchantment name search box
    Sleep(250)
    Send("^a{BS}") ; Clear textbox
    Sleep(100)

    Sleep(100)
    MouseClick("Left", 2400, 367) ; Click search
}
