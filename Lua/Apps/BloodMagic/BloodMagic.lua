--Author: Duncan Levings
--Date: 3/13/2020

--TODO:

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

local statusLabel = bloodLayout:setPosition(1, 1, bloodLayout:addChild(GUI.label(1, 1, 140, 1, LIGHT_TEXT, "Current Task: -  Amount: 0   Que: 0")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER))
local toggleBlood = bloodLayout:setPosition(1, 2, bloodLayout:addChild(GUI.switchAndLabel(1, 1, 29, 8, FOREGROUND, DARK_TEXT, LIGHT_TEXT, LIGHT_TEXT, "Blood Production:", false)))
local bloodBar = bloodLayout:setPosition(1, 3, bloodLayout:addChild(GUI.progressBar(1, 1, 140, LIGHT_TEXT, FOREGROUND, LIGHT_TEXT, 0, false, true, "Blood: ", "%")))

local function craftContainer()
    local container = GUI.addBackgroundContainer(workspace, true, true, "Craft Slate")
    local amount = container.layout:addChild(GUI.input(1, 1, 29, 3, 0xEEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "64", "Enter Wanted Amount"))
    local submit = container.layout:addChild(GUI.button(1, 1, 9, 3, FOREGROUND, LIGHT_TEXT, FOREGROUND, LIGHT_TEXT_PRESSED, "Confirm"))
  
    return container, amount, submit
  end

---------------------------------------------------------------------------------
-- App variables
local fullCheckInterval = 5        -- full check
local craftingCheckInterval = 1     -- check ongoing crafting

--transposers
local storageTransposer     --storage controller
local altarTransposer       --blood magic altar
local redstone          --mob farm light control

--sides
local storageSide       --side of storage controller
local altarSide         --side of altar
local outputSide        --storage for completed slates
local inputSide         --storage for livingstone
local orbSide           --storage for orb

--slots
local slates = {}       --stores slate type and storage slot index
local slateResourceSlot --storage slot for resource needed to craft slate

--values
local bloodLevel = 0    --level of blood in altar (percentage out of 100)
local bloodMax = 0      --max level of blood allowed in altar
local que = {}          --stores all requested crafts
local bloodProducing = true
local override = true

local craftingHandler

local BLANK = "Blank Slate"
local REIN = "Reinforced Slate"
local IMBUED = "Imbued Slate"
local DEMON = "Demonic Slate"
local ETH = "Ethereal Slate"
local SLATE_RESOURCE = "Livingrock"

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
    toggleBlood.switch:setState(true)

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
                elseif name == "storagedrawers:customdrawers" then
                    inputSide = i
                elseif name == "minecraft:chest" then
                    outputSide = i
                elseif name == "minecraft:trapped_chest" then
                    orbSide = i
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
        GUI.alert("No input custom drawer found!")
        workspace:stop()
    end
    if outputSide == nil then
        GUI.alert("No ouput chest found!")
        workspace:stop()
    end
    if orbSide == nil then
        GUI.alert("No orb trapped chest found!")
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
        elseif value.label == SLATE_RESOURCE then
            slateResourceSlot = index
        end
    end
end

local function updateBloodLevel()
    bloodLevel = (altarTransposer.getTankLevel(altarSide, 1) / bloodMax) * 100
    bloodBar.value = math.floor(bloodLevel)
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

local function updateStatus()
    if #que > 0 then
        statusLabel.text = string.format('Current Task: %s  Amount: %d  Que: %d',
        que[1].type, que[1].amount, #que)
    else
        statusLabel.text = "Current Task: -  Amount: 0   Que: 0"
    end
    workspace:draw()
end

--moves orb in/out of altar
local function moveOrb(force)
    local item = altarTransposer.getStackInSlot(altarSide, 1)
    --only store orb in altar if force is true
    if force then
        if item == nil then
            altarTransposer.transferItem(orbSide, altarSide)
        end
    else
        --only remove from atlar if item is orb
        if item and string.find(item.label, "Orb") then
            altarTransposer.transferItem(altarSide, orbSide)
        end
    end
end

local function checkAltarCraft()
    local item = altarTransposer.getStackInSlot(altarSide, 1)
    if item ~= nil then
        if item.label == que[1].type then
            altarTransposer.transferItem(altarSide, outputSide)
            que[1].amount = que[1].amount - item.size
        end
    end
end

local function altarCrafting()
    if #que > 0 then
        --send current task resource amount to start crafting process
        if que[1].crafting == false then
            storageTransposer.transferItem(storageSide, inputSide, que[1].amount, slateResourceSlot)
            que[1].crafting = true
        end

        --check altar for slate type and to subtract amount left for current crafting process
        checkAltarCraft()

        --current craft is finished
        if que[1].amount <= 0 then
            table.remove(que, 1)
        end
    else
        --all crafting que cleared
        event.removeHandler(craftingHandler)
        moveOrb(true)
    end
end

--main crafting loop
local function startCrafting()
    moveOrb(false)
    craftingHandler = event.addHandler(function()
        altarCrafting()
        updateStatus()
    end, craftingCheckInterval)
end

local function craftRequest(type)
    local container, amount, submit = craftContainer()

    submit.onTouch = function()
        if #amount.text > 0 and tonumber(amount.text) ~= nil then
            --check if wanted amount of slate resource is available
            local available = storageTransposer.getSlotStackSize(storageSide, slateResourceSlot)
            local requested = tonumber(amount.text)

            --check if slate resource is available
            if requested > available then
                GUI.alert(string.format("Not enough %s available!", SLATE_RESOURCE))
            else
                local requestedCraft = {
                    type = type,
                    amount = requested,
                    crafting = false
                }
                table.insert(que, requestedCraft)
                
                --start crafting loop
                startCrafting()
            end

            container:remove() -- remove container
        else 
            GUI.alert("Missing/Invalid Input!")
        end
    end
end

--acts as a NOR latch to turn blood production on/off
local function checkBlood()
    --only check if blood production switch is on
    if override then
        if bloodProducing == false and bloodLevel < 25 then
            bloodProducing = true
            redstone.setOutput({0, 0, 0, 0, 0, 0})      --redstone off
        end
        if bloodProducing and bloodLevel > 95 then
            bloodProducing = false
            redstone.setOutput({15, 15, 15, 15, 15, 15}) --redstone on
        end
    else
        redstone.setOutput({15, 15, 15, 15, 15, 15}) --redstone on
        bloodProducing = false
    end
end

---------------------------------------------------------------------------------
-- event handles

update.onTouch = function()
    getTransposers()
    getSlateSlots()
    updateBloodLevel()
    updateSlateText()
end

toggleBlood.switch.onStateChanged = function()
    if toggleBlood.switch.state then
        override = true
    else
        override = false
    end
end

slateBtn1.onTouch = function()
    craftRequest(BLANK)
end

slateBtn2.onTouch = function()
    craftRequest(REIN)
end

slateBtn3.onTouch = function()
    craftRequest(IMBUED)
end

slateBtn4.onTouch = function()
    craftRequest(DEMON)
end

slateBtn5.onTouch = function()
    craftRequest(ETH)
end

---------------------------------------------------------------------------------
-- main

getTransposers()
getSlateSlots()
moveOrb(true)
updateBloodLevel()
updateSlateText()
checkBlood()

-- main loop
event.addHandler(function()
    updateSlateText()
    updateBloodLevel()
    checkBlood()
end, fullCheckInterval)

-- Draw changes on screen after customizing your window
workspace:draw()
workspace:start()