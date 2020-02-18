--Author: Duncan Levings
--Date: 2/17/2020
--Used https://github.com/KaseiFR/ae2-manager as base-line

--ToDO:

-- Import libraries
local GUI = require("GUI")
local system = require("System")
local event = require("Event")
local fs = require("Filesystem")
local text = require("Text")
local net = require("Network")
local screen = require("Screen")
local unicode = require('unicode')

---------------------------------------------------------------------------------
-- GUI
local badgeCells = {}
local BACKGROUND = 0x2D2D2D
local FOREGROUND = 0xE1E1E1
local BASE_BADGE = 0xB4B4B4
local LIST_ALTERNATE = 0xD2D2D2
local LIST_SELECTED = 0x3366CC
local ADD_BUTTON = 0x33B640
local LIGHT_TEXT = 0xFFFFFF
local DARK_TEXT = 0x0

-- Add a new window workspace
local workspace = GUI.workspace()
workspace:addChild(GUI.panel(1, 1, workspace.width, workspace.height, BACKGROUND))

-- Add menu object to workspace
local menu = workspace:addChild(GUI.menu(1, 1, workspace.width, FOREGROUND, DARK_TEXT, LIST_SELECTED, LIGHT_TEXT))
menu:addItem("AE2 AutoCrafter", 0x0)
local taskMenu = menu:addItem("Tasks")
local configMenu = menu:addItem("Config")

local windowHeight = workspace.height - menu.height
local yMenuOffset = menu.height + 1

-- Tasks window-------------------------------

-- 1 col - 8 row
local taskLayout = workspace:addChild(GUI.layout(1, yMenuOffset, workspace.width, windowHeight, 1, 8))
-- taskLayout.showGrid = true -- for debugging

-- status row
taskLayout:setRowHeight(1, GUI.SIZE_POLICY_ABSOLUTE, 3)
taskLayout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
taskLayout:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_CENTER)
taskLayout:setMargin(1, 1, 2, 0)

taskLayout:setPosition(1, 1, taskLayout:addChild(GUI.label(1, 1, 10, 1, LIGHT_TEXT, "Label")))

-- set all row properties
for i = 2, 8 do
  taskLayout:setRowHeight(i, GUI.SIZE_POLICY_ABSOLUTE, 6) -- row
  taskLayout:setDirection(1, i, GUI.DIRECTION_HORIZONTAL) -- col - row
  taskLayout:setAlignment(1, i, GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_CENTER) -- col - row
  taskLayout:setMargin(1, i, 2, 0) -- col - row
end

-- recalculate positions of children for layout
local function updateBadgePositions() 
  local row = 2
  local amt = 0
  for i = 1, #badgeCells do
    if amt == 4 then
      row = row + 1
      amt = 0
    end
    taskLayout:setPosition(1, row, taskLayout.children[i + 3]) --skip first row children
    amt = amt + 1
  end
  
  workspace:draw()
end

-- add new badge container
local function addTaskBadge()
  local task = taskLayout:setPosition(1, 2, taskLayout:addChild(GUI.container(1, 1, 38, 5)))
  task:addChild(GUI.panel(1, 1, task.width, task.height, BASE_BADGE))
  task:addChild(GUI.label(2, 2, 10, 1, 0x0, "Long Item name test"))
  task:addChild(GUI.label(2, 3, 10, 1, 0x0, "1000 / 4000"))
  task:addChild(GUI.label(2, 4, 10, 1, 0x0, "error..."))

  table.insert(badgeCells, task)
  updateBadgePositions()
  return task
end

-- remove badge
local function removeTaskBadge(idx)
  if idx <= #badgeCells then
    badgeCells[idx]:remove()
    table.remove(badgeCells, idx)
  end

  updateBadgePositions()
end

-- Config window-----------------------------------

-- 3 col - 2 row
local configLayout = workspace:addChild(GUI.layout(1, yMenuOffset, workspace.width, windowHeight, 3, 2))
-- configLayout.showGrid = true -- for debugging
configLayout.hidden = true

configLayout:setRowHeight(1, GUI.SIZE_POLICY_ABSOLUTE, 3)
configLayout:setRowHeight(2, GUI.SIZE_POLICY_ABSOLUTE, 46)
configLayout:setFitting(1, 1, true, false, 4, 0)
configLayout:setFitting(2, 1, true, false, 4, 0)
configLayout:setFitting(3, 1, true, false, 4, 0)

configLayout:setPosition(1, 1, configLayout:addChild(GUI.label(1, 1, 10, 1, LIGHT_TEXT, "Auto Crafted Recipes")))
configLayout:setPosition(2, 1, configLayout:addChild(GUI.label(1, 1, 10, 1, LIGHT_TEXT, "Recipe Information")))
configLayout:setPosition(3, 1, configLayout:addChild(GUI.label(1, 1, 10, 1, LIGHT_TEXT, "Available Recipes")))

-- left list panel
local selectedRecipes_list = configLayout:setPosition(1, 2, configLayout:addChild(GUI.list(1, 1, 50, 44, 3, 0, FOREGROUND, DARK_TEXT, LIST_ALTERNATE, DARK_TEXT, LIST_SELECTED, LIGHT_TEXT, false)))

-- middle info panel
local infoContainer = configLayout:setPosition(2, 2, configLayout:addChild(GUI.container(1, 1, 49, 44)))
infoContainer:addChild(GUI.panel(1, 1, infoContainer.width, infoContainer.height, FOREGROUND))
local itemName_label = infoContainer:addChild(GUI.label(1, 3, infoContainer.width, 1, DARK_TEXT, "")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER)
local itemStored_label = infoContainer:addChild(GUI.label(1, 5, infoContainer.width, 1, DARK_TEXT, "")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER)
local itemWanted_label = infoContainer:addChild(GUI.label(1, 7, infoContainer.width, 1, DARK_TEXT, "")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER)
local itemThreshold_label = infoContainer:addChild(GUI.label(1, 9, infoContainer.width, 1, DARK_TEXT, "")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER)

local addRecipe_button = infoContainer:addChild(GUI.button(11, 40, 29, 3, ADD_BUTTON, DARK_TEXT, ADD_BUTTON, LIGHT_TEXT, "Add Recipe"))
addRecipe_button.hidden = true
-- infoContainer:addChild(GUI.input(15, 7, 20, 3, 0xEEEEEEE, DARK_TEXT, 0x999999, LIGHT_TEXT, 0x2D2D2D, "", "Desired Amount"))

-- right list panel
local search_input = configLayout:setPosition(3, 2, configLayout:addChild(GUI.input(1, 1, 50, 3, 0xEEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "", "Enter Item Name")))
local availableRecipes_list = configLayout:setPosition(3, 2, configLayout:addChild(GUI.list(1, 1, 50, 40, 3, 0, FOREGROUND, DARK_TEXT, LIST_ALTERNATE, DARK_TEXT, LIST_SELECTED, LIGHT_TEXT, false)))
availableRecipes_list.selectedItem = -1

local function add_Container()
  local container = GUI.addBackgroundContainer(workspace, true, true, "Add Recipe")
  local amount = container.layout:addChild(GUI.input(1, 1, 30, 3, 0xEEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "", "Enter Wanted Amount"))
  local threshold = container.layout:addChild(GUI.input(1, 1, 30, 3, 0xEEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "0", "Enter Threshold Amount"))
  local submit = container.layout:addChild(GUI.button(1, 1, 10, 3, ADD_BUTTON, DARK_TEXT, ADD_BUTTON, LIGHT_TEXT, "Confirm"))

  return container, amount, threshold, submit
end

---------------------------------------------------------------------------------
-- App variables
local ae2
local availableRecipes = {}
local selectedRecipes = {}
local filteredRecipes = {}
local isFiltered = false

---------------------------------------------------------------------------------
-- App functions

local function clearDisplay()
  itemName_label.text = ""
  itemStored_label.text = ""
  itemWanted_label.text = ""
  itemThreshold_label.text = ""
  addRecipe_button.hidden = true
end

-- type 0 = left panel, 1 = right panel (non filtered), 2 = right panel (filtered)
local function displayItem(type, idx)
  if type == 0 then
    availableRecipes_list.selectedItem = -1
    addRecipe_button.hidden = true
    itemName_label.text = selectedRecipes[idx].label
    itemStored_label.text = string.format("Stored: %d", math.floor(selectedRecipes[idx].amount))
    itemWanted_label.text = string.format("Wanted: %d", math.floor(selectedRecipes[idx].wanted))
    itemThreshold_label.text = string.format("Threshold: %d", math.floor(selectedRecipes[idx].threshold))
  elseif type == 1 then
    selectedRecipes_list.selectedItem = -1
    addRecipe_button.hidden = false
    itemName_label.text = availableRecipes[idx].label
    itemStored_label.text = string.format("Stored: %d", math.floor(availableRecipes[idx].amount))
    itemWanted_label.text = ""
    itemThreshold_label.text = ""
  else 
    selectedRecipes_list.selectedItem = -1
    addRecipe_button.hidden = false
    itemName_label.text = filteredRecipes[idx].label
    itemStored_label.text = string.format("Stored: %d", math.floor(filteredRecipes[idx].amount))
    itemWanted_label.text = ""
    itemThreshold_label.text = ""
  end
  workspace:draw()
end

-- add items to GUI list
local function updateAvailableRecipeList(data, type)
  -- clears the list
  availableRecipes_list.selectedItem = -1
  availableRecipes_list.children = {}

  for k, v in ipairs(data) do
    availableRecipes_list:addItem(string.format("%s", v.label)).onTouch = function()
      displayItem(type, availableRecipes_list.selectedItem)
    end
  end
end

-- add items to GUI list
local function updateSelectedRecipeList()
  -- clears the list
  selectedRecipes_list.selectedItem = -1
  selectedRecipes_list.children = {}

  for k, v in ipairs(selectedRecipes) do
    selectedRecipes_list:addItem(string.format("%s", v.label)).onTouch = function()
      displayItem(0, selectedRecipes_list.selectedItem)
    end
  end
end

local function itemKey(item, withLabel)
  local key = item.name .. '$' .. math.floor(item.damage)
  if withLabel then
      --log('using label for', item.label)
      key = key .. '$' .. item.label
  end
  return key
end

local function findIndex(recipe)
  for k, v in ipairs(availableRecipes) do
    if v == recipe then
      return k
    end
  end
  return -1
end

-- check if AE2 is connected
local function checkComponent()
  if not component.isAvailable("me_interface") then
    GUI.alert("No Applied Energistics Interface found!")
    workspace:stop()
  end
  ae2 = component.get("me_interface")
end

-- load all items that are craftable from AE2 network
local function loadAvailableRecipes()

  local index = {}
  for _, recipe in ipairs(selectedRecipes) do
      local key = itemKey(recipe.item, recipe.item.label ~= nil)
      index[key] = { recipe = recipe, matches = {} }
  end

  -- retrieve all items in network
  local items, err = ae2.getItemsInNetwork()
  if err then 
    GUI.alert(err) 
    workspace:stop()
  end

  -- clear table
  availableRecipes = {}

  -- loop returned items and check if they are craftable
  for _, item in ipairs(items) do
    local key = itemKey(item, item.hasTag)
    local indexed = index[key]
    if indexed then
        table.insert(indexed.matches, item)
    elseif item.isCraftable then
        local recipe = {
            item = {
                name = item.name,
                damage = math.floor(item.damage)
            },
            label = item.label,
            amount = item.size
        }
        -- GUI.alert(recipe) --debugging
        if item.hasTag then
            -- By default, OC doesn't expose items NBT, so as a workaround we use the label as
            -- an additional discriminant. This is not perfect (still some collisions, and locale-dependent)
            recipe.item.label = recipe.label
        end
        table.insert(availableRecipes, recipe)
        index[key] = { recipe = recipe, matches = { item } }
    end

    updateAvailableRecipeList(availableRecipes, 1)
  end
end

local function addRecipe()
  container, amount, threshold, submit = add_Container()

  submit.onTouch = function()
    if #amount.text > 0 and tonumber(amount.text) ~= nil and #threshold.text > 0 and tonumber(threshold.text) ~= nil then
      local recipe = {}

      -- check if list is filtered or normal
      if isFiltered then
        recipe = filteredRecipes[availableRecipes_list.selectedItem]
        -- need to find index of filtered item from main table
        local idx = findIndex(recipe)
        if idx > 0 then table.remove(availableRecipes, idx) end
        -- reset back to normal
        filteredRecipes = {}
        search_input.text = ""
      else
        recipe = availableRecipes[availableRecipes_list.selectedItem]
        table.remove(availableRecipes, availableRecipes_list.selectedItem)
      end
      
      recipe.wanted = tonumber(amount.text)
      recipe.threshold = tonumber(threshold.text)
      -- GUI.alert(recipe) --debugging

      -- update left panel list
      table.insert(selectedRecipes, recipe)
      updateSelectedRecipeList()

      -- save to table
      -- writeDestTable(destTable)

      -- reset right panel
      updateAvailableRecipeList(availableRecipes, 1)
      -- reset center display
      clearDisplay()
      -- remove container
      container:remove()
    else 
      GUI.alert("Missing/Invalid Input!")
    end
  end
end

local function filterAvailableRecipes()
  local filter = search_input.text
  if filter and filter ~= '' then
    filter = unicode.lower(filter)
    filteredRecipes = {}
    for _, recipe in ipairs(availableRecipes) do
      if unicode.lower(recipe.label):find(filter) then
          table.insert(filteredRecipes, recipe)
      end
    end
    isFiltered = true
    updateAvailableRecipeList(filteredRecipes, 2)
  else --reload all available
    isFiltered = false
    loadAvailableRecipes()
  end
  clearDisplay()
end

---------------------------------------------------------------------------------
-- event handles

taskMenu.onTouch = function()
  if taskLayout.hidden then
    configLayout.hidden = true
    taskLayout.hidden = false
    workspace:draw()
  end
end

configMenu.onTouch = function()
  if configLayout.hidden then
    --load selected recipes
    configLayout.hidden = false
    taskLayout.hidden = true

    loadAvailableRecipes()
    workspace:draw()
  end
end

search_input.onInputFinished = function()
  filterAvailableRecipes()
end

addRecipe_button.onTouch = function()
  addRecipe()
end

--remove recipe button

---------------------------------------------------------------------------------
-- main
checkComponent()
loadAvailableRecipes()
--load selected recipes

--flow logic loop, every 10 second?

--ae2 dispatch requests loop
--checks if any cpu is free
--loops recipe list
--checks if recipe needs to be crafted (less than amt and using threshold)
--check if recipe is already being crafted or any error

--ae2 crafting check loop
--loops recipe list
--check if recipe is done crafting or any error

--future craft check function
--error check function

--store total # of cpu, # of cpu being used, # of crafting, # of qeued to craft, 


-- Draw changes on screen after customizing your window
workspace:draw()
workspace:start()