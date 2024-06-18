#SingleInstance force
#Requires AutoHotkey v2.0+
#include ..\Libs\OCR.ahk ; https://github.com/Descolada/OCR

CHAR_PANTHER := { x: -1000, y: 0 }
CHAR_BEAR := { x: 1000, y: 0 }
CHAR_CHICKEN := { x: -250, y: 1000 }
CHAR_HUMAN := { x: 0, y: -1000 }
CHAR_RAT := { x: 250, y: 1000 }

F1::
{
    SwitchCharacter("Bear")
}
F2::
{
    SwitchCharacter("Bear")
}

F3::
{
    ; Auction Helper
    OCRText := OCR.FromRect(1333, 140, 577, 890, , scale:=1).Text  ; Scans Stash area in auction window for item

    ToolTip(OCRText)

    rarity := ""
    if InStr(OCRText, "Uncommon") {
        rarity := "Uncommon"
    } else if InStr(OCRText, "Rare") {
        rarity := "Rare"
    } else if InStr(OCRText, "Epic") {
        rarity := "Epic"
    } else if InStr(OCRText, "Legend") {
        rarity := "Legend"
    } else if InStr(OCRText, "Unique") {
        rarity := "Unique"
    }

    item := ""

    ; We can use the items table to check if any text in OCRText matches an item
    ; If an item isn't found the first time, lets wait a few milliseconds and try again for a total of 3 times

    while (item = "" && A_Index <= 3) {
        for i, itemI in items {
            if InStr(OCRText, itemI) {
                item := itemI
                break
            }
        }

        if (item = "") {
            Sleep(100)
        }
    }

    ; ToolTip(rarity . " " . item)

    ; We want to get the enchantment(s) of the item
    ; We can find this by using the enchantments table and checking if any text in OCRText matches an enchantment
    ; Enchantments begin with a +. So the string will be something like +10 Strength or +1 Agility

    enchantmentsFound := []
    enchantmentt := ""

    for enchantmentI in enchantments {
        enchantmentRegex := "\+(\d+(?:\.\d+)?%?) " . enchantmentI
        if (matchPos := RegExMatch(OCRText, enchantmentRegex, &matchObject)) {
            enchantmentValue := matchObject[1]
            enchantmentText := enchantmentValue . " " . enchantmentI
            enchantmentsFound.Push(enchantmentI)
        }
    }

    if (enchantmentsFound.Length > 0) {
        enchantmentsText := ""
        for index, enchantment in enchantmentsFound {
            enchantmentsText .= enchantment
            enchantmentt := enchantment
            if (index < enchantmentsFound.Length) {
                enchantmentsText .= ", "
            }
        }
        ToolTip(item . " " . rarity . " (" . enchantmentsText . ")")
    } else {
        ToolTip(item . " " . rarity)
    }

    ; Now we swap to view market tab
    MouseClick("Left", 850, 115, ,) ; View Market button
    Sleep(500)

    MouseClick("Left", 1785, 200, ,) ; Reset Filters button
    Sleep(400)

    MouseClick("Left", 400, 200, , ) ; Click rarity selection
    Sleep(100)
    if (rarity = "Uncommon") {
        MouseClick("Left", 400, 325, , ) ; Click rarity
    } else if (rarity = "Rare") {
        MouseClick("Left", 400, 350, , ) ; Click rarity
    } else if (rarity = "Epic") {
        MouseClick("Left", 400, 375, , ) ; Click rarity
    } else if (rarity = "Legend") {
        MouseClick("Left", 400, 400, , ) ; Click rarity
    } else if (rarity = "Unique") {
        MouseClick("Left", 400, 425, , ) ; Click rarity
    }
    Sleep(100)

    MouseClick("Left", 150, 200, , ) ; Click item name selection
    Sleep(100)
    MouseClick("Left", 150, 250, , ) ; Click item name search box
    Sleep(200)
    Send(item) ; Type item name
    Sleep(100)
    MouseClick("Left", 150, 275, , ) ; Click item name
    Sleep(100)


    MouseClick("Left", 1500, 200, , ) ; Click random attributes
    Sleep(100)
    MouseClick("Left", 1500, 250, , ) ; Click enchantment name search box
    Sleep(250)
    Send("^a{BS}") ; Clear textbox
    Sleep(100)
    Send(enchantmentt) ; Type enchantment name
    Sleep(100)
    MouseClick("Left", 1500, 275, , ) ; Click enchantment name
    Sleep(100)
    MouseClick("Left", 1800, 275, , ) ; Click search
}

F6::
{
    ; Rat Human swap
    SwitchCharacter("Rat")
    Sleep(700)
    SwitchCharacter("Human")
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

enchantments := [
    "Strength",
    "Agility",
    "Dexterity",
    "Will",
    "Knowledge",
    "Vigor",
    "Resourcefulness",
    "Armor Penetration",
    "Additional Physical Damage",
    "True Physical Damage",
    "Physical Damage Bonus",
    "Physical Weapon Damage Add",
    "Physical Power",
    "Magic Penetration",
    "Additional Magical Damage",
    "True Magical Damage",
    "Magical Damage Bonus",
    "Magical Power",
    "Armor Rating Add",
    "Magic Resistance Add",
    "Physical Damage Reduction",
    "Magical Damage Reduction",
    "Projectile Reduction Mod",
    "Action Speed",
    "Move Speed Add",
    "Move Speed Bonus",
    "Regular Interaction Speed",
    "Magical Interaction Speed",
    "Spell Casting Speed",
    "Max Health Add",
    "Max Health Bonus",
    "Physical Healing",
    "Magical Healing",
    "Buff Duration Bonus",
    "Debuff Duration Bonus",
    "Memory Capacity Add",
    "Memory Capacity Bonus",
    "Luck",
    "Additional Weapon Damage"
]

items := [
    "Arming Sword",
    "Crystal Sword",
    "Falchion",
    "Longsword",
    "Rapier",
    "Short Sword",
    "Viking Sword",

    "Blade of Righteousness",
    "Demon's Glee",
    "Divine Blade",
    "Divine Short Sword",
    "Falchion of Honor",
    "Golden Viking Sword",
    "Short Sword of Righteousness",
    "Sterling Blade",

    "Boneshaper",
    "Divine Rod",
    "Divine Staff",
    "Light Bringer",
    "Rod of Righteousness",
    "Staff of Righteousness",
    "Sterling Rod",
    "Sterling Staff",

    "Castillon Dagger",
    "Kris Dagger",
    "Rondel Dagger",
    "Stiletto Dagger",

    'Dagger of Righteousness',
    'Divine Dagger',
    'Sterling Dagger',
    'Throwing Knife',

    "Bardiche",
    "Halberd",
    "Spear",

    "Spear of Rot",

    'Battle Axe',
    'Double Axe',
    'Felling Axe',
    'Hatchet',
    "Horseman's Axe",

    "Axe of Righteousness",
    "Divine Axe",
    "Francisca Axe",
    "Golden Felling Axe",
    "Sterling Axe",

    "Longbow",
    "Recurve Bow",
    "Survival Bow",

    "Crossbow",
    "Hand Crossbow",
    "Windlas Crossbow",

    "Ceremonial Staff",
    "Crystal Ball",
    "Crystal Sword",
    "Magic Staff",
    "Spellbook",

    "Buckler",
    "Heater Shield",
    "Pavise",
    "Round Shield",

    "Armet",
    "Barbuta Helm",
    "Chapel De Fer",
    "Chaperon",
    "Cobalt Chapel De Fer",
    "Cobalt Hat",
    "Cobalt Hood",
    "Cobalt Viking Helm",
    "Copperlight Kettle Hat",
    "Copperlight Shadow Hood",
    "Copperlight Straw Hat",
    "Cowl of Darkness",
    "Crusader Helm",
    "Darkgrove Hood",
    "Dread Hood",
    "Elkwood Crown",
    "Feathered Hat",
    "Forest Hood",
    "Gjermundbu",
    "Golden Armet",
    "Golden Gjermundbu",
    "Golden Hounskull",
    "Golden Leaf Hood",
    "Golden Scarf",
    "Great Helm",
    "Hounskull",
    "Kettle Hat",
    "Leather Bonnet",
    "Leather Cap",
    "Norman Nasal Helm",
    "Occultist Hood",
    "Open Sallet",
    "Ranger Hood",
    "Rogue Cowl",
    "Rubysilver Barbuta Helm",
    "Rubysilver Cap",
    "Rubysilver Hood",
    "Sallet",
    "Shadow Hood",
    "Shadow Mask",
    "Spangenhelm",
    "Straw Hat",
    "Topfhelm",
    "Viking Helm",
    "Visored Barbuta Helm",
    "Visored Sallet",
    "Wizard Hat",
    "Adventurer Tunic",
    "Champion Armor",
    "Cobalt Frock",
    "Cobalt Regal Gambeson",
    "Cobalt Templar Armor",
    "Copperlight Attire",
    "Copperlight Outfit",
    "Copperlight Sanctum Plate Armor",
    "Copperlight Tunic",
    "Crusader Armor",
    "Dark Cuirass",
    "Dark Plate Armor",
    "Darkgrove Robe",
    "Doublet",
    "Fine Cuirass",
    "Frock",
    "Golden Padded Tunic",
    "Golden Plate",
    "Golden Robe",
    "Grand Brigandine",
    "Heavy Gambeson",
    "Light Aketon",
    "Marauder Outfit",
    "Mystic Vestments",
    "Northern Full Tunic",
    "Occultist Robe",
    "Occultist Tunic",
    "Oracle Robe",
    "Ornate Jazerant",
    "Padded Tunic",
    "Pourpoint",
    "Regal Gambeson",
    "Ritual Robe",
    "Robe of Darkness",
    "Rubysilver Cuirass",
    "Rubysilver Doublet",
    "Rubysilver Vestments",
    "Studded Leather",
    "Templar Armor",
    "Tri-Pelt Doublet",
    "Tri-Pelt Northern Full Tunic",
    "Troubadour Outfit",
    "Wanderer Attire",
    "Warden Outfit",
    "Bardic Pants",
    "Brave Hunter's Pants",
    "Cloth Pants",
    "Cobalt Plate Pants",
    "Cobalt Trousers",
    "Copperlight Leggings",
    "Copperlight Pants",
    "Copperlight Plate Pants",
    "Dark Leather Leggings",
    "Demonclad Leggings",
    "Golden Chausses",
    "Golden Leggings",
    "Golden Plate Pants",
    "Heavy Leather Leggings",
    "Leather Chausses",
    "Leather Leggings",
    "Loose Trousers",
    "Occultist Pants",
    "Padded Leggings",
    "Plate Pants",
    "Rubysilver Leggings",
    "Rubysilver Plate Pants",
    "Wolf Hunter Leggings",
    "Cobalt Heavy Gauntlet",
    "Cobalt Leather Gloves",
    "Copperlight Gauntlets",
    "Copperlight Riveted Gloves",
    "Demon Grip Gloves",
    "Elkwood Gloves",
    "Gloves of Utility",
    "Golden Gauntlets",
    "Golden Gloves",
    "Gravewolf Gloves",
    "Heavy Gauntlets",
    "Leather Gloves",
    "Light Gauntlets",
    "Mystic Gloves",
    "Rawhide Gloves",
    "Reinforced Gloves",
    "Riveted Gloves",
    "Rubysilver Gauntlets",
    "Rubysilver Rawhide Gloves",
    "Runestone Gloves",
    "Adventurer Boots",
    "Buckled Boots",
    "Cobalt Lightfoot Boots",
    "Cobalt Plate Boots",
    "Copperlight Lightfoot Boots",
    "Copperlight Plate Boots",
    "Darkleaf Boots",
    "Dashing Boots",
    "Forest Boots",
    "Foul Boots",
    "Golden Boots",
    "Golden Plate Boots",
    "Heavy Boots",
    "Laced Turnshoe",
    "Lightfoot Boots",
    "Low Boots",
    "Occultist Boots",
    "Old Shoes",
    "Plate Boots",
    "Rubysilver Adventurer Boots",
    "Rubysilver Plate Boots",
    "Rugged Boots",
    "Shoes of Darkness",
    "Stitched Turnshoe",
    "Turnshoe",
    "Wizard Shoes",
    "Adventurer Cloak",
    "Cloak of Darkness",
    "Golden Cloak",
    "Mercurial Cloak",
    "Radiant Cloak",
    "Splendid Cloak",
    "Tattered Cloak",
    "Vigilant Cloak",
    "Watchman Cloak"
    ]
