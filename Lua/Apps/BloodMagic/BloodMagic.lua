--Author: Duncan Levings
--Date: 3/13/2020

--TODO:
--clicking craft will open modal for amount wanted
--then send stone to inventory
--and set current crafting slate to wanted one
--if aditional are clicked, add to table que
--keep checking for x slate till x is in storage then 
--more to next que if there are any
--update status crafting text

--2 loops, one to check inventory amounts
--(only active while crafting?) to check item in altar to extract
--2nd loop will need to update very often for fast slate crafting

-- Import libraries
local GUI = require("GUI")
local system = require("System")
local component = require("component")
local event = require("Event")

---------------------------------------------------------------------------------
-- GUI
local BACKGROUND = 0x0F0F0F
local FOREGROUND = 0x2D2D2D
local LIGHT_TEXT = 0xCC0000
local LIGHT_TEXT_PRESSED = 0xFF0000
local DARK_TEXT = 0x0

-- Add a new window workspace
local workspace = GUI.workspace()
workspace:addChild(GUI.panel(1, 1, workspace.width, workspace.height, BACKGROUND))

-- Add menu object to workspace
local menu = workspace:addChild(GUI.menu(1, 1, workspace.width, FOREGROUND, LIGHT_TEXT, LIGHT_TEXT_PRESSED, FOREGROUND))
local update = menu:addItem("Force Update")

local windowHeight = workspace.height - menu.height
local yMenuOffset = menu.height + 1

-- MAIN ---------------------------------------------------------

-- 2 col - 5 row
local slateLayout = workspace:addChild(GUI.layout(1, yMenuOffset, workspace.width, windowHeight - 14, 2, 5))
-- slateLayout.showGrid = true -- for debugging

slateLayout:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_RIGHT, GUI.ALIGNMENT_VERTICAL_CENTER)
slateLayout:setAlignment(2, 1, GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_CENTER)

-- set all row properties
for i = 1, 5 do
    slateLayout:setAlignment(1, i, GUI.ALIGNMENT_HORIZONTAL_RIGHT, GUI.ALIGNMENT_VERTICAL_CENTER)
    slateLayout:setAlignment(2, i, GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_CENTER)
    slateLayout:setMargin(2, i, 5, 0) -- col - row
end

-- slate labels
local slateLbl1 = slateLayout:setPosition(1, 1, slateLayout:addChild(GUI.label(1, 3, 29, 3, LIGHT_TEXT, "Stored:")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER))
local slateLbl2 = slateLayout:setPosition(1, 2, slateLayout:addChild(GUI.label(1, 3, 29, 3, LIGHT_TEXT, "Stored:")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER))
local slateLbl3 = slateLayout:setPosition(1, 3, slateLayout:addChild(GUI.label(1, 3, 29, 3, LIGHT_TEXT, "Stored:")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER))
local slateLbl4 = slateLayout:setPosition(1, 4, slateLayout:addChild(GUI.label(1, 3, 29, 3, LIGHT_TEXT, "Stored:")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER))
local slateLbl5 = slateLayout:setPosition(1, 5, slateLayout:addChild(GUI.label(1, 3, 29, 3, LIGHT_TEXT, "Stored:")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER))

-- slate buttons
local slateBtn1 = slateLayout:setPosition(2, 1, slateLayout:addChild(GUI.button(1, 1, 29, 3, FOREGROUND, LIGHT_TEXT, FOREGROUND, LIGHT_TEXT_PRESSED, "Craft Blank Slate")))
local slateBtn2 = slateLayout:setPosition(2, 2, slateLayout:addChild(GUI.button(1, 1, 29, 3, FOREGROUND, LIGHT_TEXT, FOREGROUND, LIGHT_TEXT_PRESSED, "Craft Reinforced Slate")))
local slateBtn3 = slateLayout:setPosition(2, 3, slateLayout:addChild(GUI.button(1, 1, 29, 3, FOREGROUND, LIGHT_TEXT, FOREGROUND, LIGHT_TEXT_PRESSED, "Craft Imbued Slate")))
local slateBtn4 = slateLayout:setPosition(2, 4, slateLayout:addChild(GUI.button(1, 1, 29, 3, FOREGROUND, LIGHT_TEXT, FOREGROUND, LIGHT_TEXT_PRESSED, "Craft Demonic Slate")))
local slateBtn5 = slateLayout:setPosition(2, 5, slateLayout:addChild(GUI.button(1, 1, 29, 3, FOREGROUND, LIGHT_TEXT, FOREGROUND, LIGHT_TEXT_PRESSED, "Craft Ethreal Slate")))

-- 1 col - 3 row
local bloodLayout = workspace:addChild(GUI.layout(1, yMenuOffset + slateLayout.height, workspace.width, windowHeight - slateLayout.height, 1, 3))
-- bloodLayout.showGrid = true -- for debugging

-- blood level display
bloodLayout:setRowHeight(1, GUI.SIZE_POLICY_ABSOLUTE, 3)
bloodLayout:setRowHeight(2, GUI.SIZE_POLICY_ABSOLUTE, 3)
bloodLayout:setRowHeight(3, GUI.SIZE_POLICY_ABSOLUTE, 8)

local statusLabel = bloodLayout:setPosition(1, 1, bloodLayout:addChild(GUI.label(1, 1, 29, 1, LIGHT_TEXT, "Current Task: -  Amount: 0")))
local toggleBlood = bloodLayout:setPosition(1, 2, bloodLayout:addChild(GUI.switchAndLabel(1, 1, 29, 8, FOREGROUND, DARK_TEXT, LIGHT_TEXT, LIGHT_TEXT, "Blood Production:", false)))
local bloodBar = bloodLayout:setPosition(1, 3, bloodLayout:addChild(GUI.progressBar(1, 1, 140, LIGHT_TEXT, FOREGROUND, LIGHT_TEXT, 0, false, true, "Blood: ", "%")))

---------------------------------------------------------------------------------
-- App variables
local fullCheckInterval = 5        -- full check
local craftingCheckInterval = 1     -- check ongoing crafting
local storageTransposer     --storage controller
local altarTransposer       --blood magic altar
local redstone          --mob farm light control
local storageSide       --side of storage controller
local altarSide         --side of altar
local outputSide        --storage for completed slates
local inputSide         --storage for livingstone
local bloodLevel = 0
local bloodMax = 0
local slates = {}
local currentCrafting = {}   --stores current crafting type as array table
local BLANK = "Blank Slate"
local REIN = "Reinforced Slate"
local IMBUED = "Imbued Slate"
local DEMON = "Demonic Slate"
local ETH = "Ethereal Slate"

---------------------------------------------------------------------------------
-- App functions

--loops all connected transposers and connects them with correct object
local function getTransposers()
    if not component.isAvailable("transposer") then
        GUI.alert("No transposer found!")
        workspace:stop()
    end
    if not component.isAvailable("redstone") then
        GUI.alert("No redstone found!")
        workspace:stop()
    end

    redstone = component.get("redstone")
    --getting initial value of redstone
    for index, value in ipairs(redstone.getInput()) do
        if value > 0 then
            toggleBlood.switch:setState(true)
        end
    end

    --setting values of sides for each transposer
    for address, transposer in component.list("transposer") do 
        local t = component.proxy(address)
        for i = 0, 5 do
            local name = t.getInventoryName(i)
            if name ~= nil then
                if name == "bloodmagic:altar" then
                    altarTransposer = t
                    altarSide = i
                    bloodMax = altarTransposer.getFluidInTank(altarSide, 1).capacity
                elseif name == "storagedrawers:controller" then
                    storageTransposer = t
                    storageSide = i
                elseif name == "storagedrawers:basicdrawers" then
                    inputSide = i
                elseif name == "minecraft:chest" then
                    outputSide = i
                end
            end
        end
    end

    if storageTransposer == nil then
        GUI.alert("No storage controller found!")
        workspace:stop()
    end
    if altarTransposer == nil then
        GUI.alert("No altar found!")
        workspace:stop()
    end
    if inputSide == nil then
        GUI.alert("No input drawer found!")
        workspace:stop()
    end
    if outputSide == nil then
        GUI.alert("No ouput chest found!")
        workspace:stop()
    end
end

--updates slotTable sides to correct slot from storage transposer
local function getSlateSlots()
    local slotTable = storageTransposer.getAllStacks(storageSide).getAll()
    for index, value in ipairs(slotTable) do
        if value.label == BLANK then
            slates[BLANK] = index
        elseif value.label == REIN then
            slates[REIN] = index
        elseif value.label == IMBUED then
            slates[IMBUED] = index
        elseif value.label == DEMON then
            slates[DEMON] = index
        elseif value.label == ETH then
            slates[ETH] = index
        end
    end
end

local function updateBloodLevel()
    local amount = (altarTransposer.getTankLevel(altarSide, 1) / bloodMax) * 100
    bloodBar.value = math.floor(amount)
end

local function storedText(side, slot)
    return string.format("Stored: %d", storageTransposer.getSlotStackSize(side, slot))
end

local function updateSlateText()
    for name, slot in pairs(slates) do
        if name == BLANK then
            slateLbl1.text = storedText(storageSide, slot)
        elseif name == REIN then
            slateLbl2.text = storedText(storageSide, slot)
        elseif name == IMBUED then
            slateLbl3.text = storedText(storageSide, slot)
        elseif name == DEMON then
            slateLbl4.text = storedText(storageSide, slot)
        elseif name == ETH then
            slateLbl5.text = storedText(storageSide, slot)
        end
    end
    workspace:draw()
end

---------------------------------------------------------------------------------
-- event handles

update.onTouch = function()
    getTransposers()
    getSlateSlots()
    workspace:draw()
end

toggleBlood.switch.onStateChanged = function()
    if toggleBlood.switch.state then
        redstone.setOutput({15, 15, 15, 15, 15, 15}) --redstone on
    else
        redstone.setOutput({0, 0, 0, 0, 0, 0})      --redstone off
    end
end



---------------------------------------------------------------------------------
-- main

getTransposers()
getSlateSlots()
updateBloodLevel()
updateSlateText()

-- main loop
-- event.addHandler(function()
--     updateSlateText()
--     updateBloodLevel()
-- end, fullCheckInterval)

-- Draw changes on screen after customizing your window
workspace:draw()
workspace:start()
