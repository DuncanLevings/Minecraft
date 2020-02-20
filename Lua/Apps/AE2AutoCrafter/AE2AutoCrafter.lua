--Author: Duncan Levings
--Date: 2/17/2020
--Used https://github.com/KaseiFR/ae2-manager as base-line

--ToDO:
--allow editing config params
--fix color not showing for badge display

-- Import libraries
local GUI = require("GUI")
local computer = require("computer")
local component = require("component")
local event = require("Event")
local fs = require("Filesystem")
local text = require("Text")
local net = require("Network")
local screen = require("Screen")
local unicode = require("unicode")

---------------------------------------------------------------------------------
-- GUI
local badgeCells = {}
local BACKGROUND = 0x2D2D2D
local FOREGROUND = 0xE1E1E1
local BASE_BADGE = 0xB4B4B4
local BADGE_CRAFTING = 0x3366CC
local BADGE_ERROR = 0xCC0000
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

-- 1 col - 2 row
local taskLayout = workspace:addChild(GUI.layout(1, yMenuOffset, workspace.width, windowHeight, 1, 2))
-- taskLayout.showGrid = true -- for debugging

-- status row
taskLayout:setRowHeight(1, GUI.SIZE_POLICY_ABSOLUTE, 3)
taskLayout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
taskLayout:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_CENTER)
taskLayout:setMargin(1, 1, 2, 0)

taskLayout:setRowHeight(2, GUI.SIZE_POLICY_ABSOLUTE, 46)

local statusLabel = taskLayout:setPosition(1, 1, taskLayout:addChild(GUI.label(1, 1, 10, 1, LIGHT_TEXT, "CPU: # free / # total   Recipes  # errors  # ongoing  # queued")))

-- 1 col - 7 row
local badgeLayout = taskLayout:setPosition(1, 2, taskLayout:addChild(GUI.layout(1, 1, taskLayout.width, taskLayout.height - 3, 1, 7)))
-- badgeLayout.showGrid = true -- for debugging

-- set all row properties
for i = 1, 7 do
  badgeLayout:setRowHeight(i, GUI.SIZE_POLICY_ABSOLUTE, 6) -- row
  badgeLayout:setDirection(1, i, GUI.DIRECTION_HORIZONTAL) -- col - row
  badgeLayout:setAlignment(1, i, GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_CENTER) -- col - row
  badgeLayout:setMargin(1, i, 2, 0) -- col - row
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
local editRecipe_button = infoContainer:addChild(GUI.button(11, 35, 29, 3, ADD_BUTTON, DARK_TEXT, ADD_BUTTON, LIGHT_TEXT, "Edit Recipe"))
editRecipe_button.hidden = true
local removeRecipe_button = infoContainer:addChild(GUI.button(11, 40, 29, 3, BADGE_ERROR, DARK_TEXT, BADGE_ERROR, LIGHT_TEXT, "Remove Recipe"))
removeRecipe_button.hidden = true

-- right list panel
local search_input = configLayout:setPosition(3, 2, configLayout:addChild(GUI.input(1, 1, 50, 3, 0xEEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "", "Enter Item Name")))
local availableRecipes_list = configLayout:setPosition(3, 2, configLayout:addChild(GUI.list(1, 1, 50, 40, 3, 0, FOREGROUND, DARK_TEXT, LIST_ALTERNATE, DARK_TEXT, LIST_SELECTED, LIGHT_TEXT, false)))
availableRecipes_list.selectedItem = -1

local function add_Container()
  local container = GUI.addBackgroundContainer(workspace, true, true, "Add Recipe")
  local amount = container.layout:addChild(GUI.input(1, 1, 30, 3, 0xEEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "", "Enter Wanted Amount"))
  local threshold = container.layout:addChild(GUI.input(1, 1, 30, 3, 0xEEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "0", "Enter Threshold Amount", true))
  local submit = container.layout:addChild(GUI.button(1, 1, 10, 3, ADD_BUTTON, DARK_TEXT, ADD_BUTTON, LIGHT_TEXT, "Confirm"))

  return container, amount, threshold, submit
end

local function edit_Container(amount, threshold)
  local container = GUI.addBackgroundContainer(workspace, true, true, "Edit Recipe")
  local amount = container.layout:addChild(GUI.input(1, 1, 30, 3, 0xEEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, amount, "Enter Wanted Amount"))
  local threshold = container.layout:addChild(GUI.input(1, 1, 30, 3, 0xEEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, threshold, "Enter Threshold Amount"))
  local submit = container.layout:addChild(GUI.button(1, 1, 10, 3, ADD_BUTTON, DARK_TEXT, ADD_BUTTON, LIGHT_TEXT, "Confirm"))

  return container, amount, threshold, submit
end

local function remove_Container(name)
  local container = GUI.addBackgroundContainer(workspace, true, true, "Confirm Remove")
  local submit = container.layout:addChild(GUI.button(1, 1, 30, 3, 0xCC0000, 0x0F0F0F, 0xFF0000, 0x0F0F0F, string.format("Remove %s", name)))
  return container, submit
end

---------------------------------------------------------------------------------
-- App variables
local recipePath = "/Data/savedRecipes.txt"
local ae2
local availableRecipes = {}
local selectedRecipes = {}
local filteredRecipes = {}
local status = {}
local isFiltered = false

-- Control how many CPUs to use. 0 is unlimited, negative to keep some CPU free, between 0 and 1 to reserve a share,
-- and greater than 1 to allocate a fixed number.
local allowedCpus = -2
-- Maximum size of the crafting requests
local maxBatch = 1024
-- How often to check the AE system, in second
local fullCheckInterval = 10        -- full scan
local craftingCheckInterval = 1     -- only check ongoing crafting

---------------------------------------------------------------------------------
-- App functions

-- recalculate positions of children for layout
local function updateBadgePositions(badges) 
  local row = 1
  local amt = 0
  for i = 1, badges do
    if amt == 4 then
      row = row + 1
      amt = 0
    end
    badgeLayout:setPosition(1, row, badgeLayout.children[i]) --skip first row children
    amt = amt + 1
  end
  
  workspace:draw()
end

-- add new badge container
local function drawTaskBadges()
  badgeLayout.children = {}
  local badges = 0
  for _, recipe in ipairs(selectedRecipes) do
    local color =
    recipe.error and BADGE_ERROR or
            recipe.crafting and BADGE_CRAFTING or
            (recipe.stored or 0) < recipe.wanted and BASE_BADGE

    if color then
        local badge = badgeLayout:setPosition(1, 1, badgeLayout:addChild(GUI.container(1, 1, 38, 5)))
        badge:addChild(GUI.panel(1, 1, badge.width, badge.height, BASE_BADGE))
        badge:addChild(GUI.label(2, 2, 10, 1, DARK_TEXT, recipe.label))
        badge:addChild(GUI.label(2, 3, 10, 1, DARK_TEXT, string.format('%s / %s', recipe.stored or '?', recipe.wanted)))
        if recipe.error then
          badge:addChild(GUI.label(2, 4, 10, 1, DARK_TEXT, tostring(recipe.error)))
        end

        badges = badges + 1
    end
  end
  
  updateBadgePositions(badges)
end

-- update recipe table
local function writeRecipes(data) 
  local result, reason = fs.writeTable(recipePath, data, true)
  if result == true then
    -- loadRecipes() -- update
  else
    GUI.alert(reason)
  end
end

-- read from table data and populate file data
local function loadRecipes() 
  if fs.exists(recipePath) then
    selectedRecipes = fs.readTable(recipePath)
  else 
    writeRecipes({}) -- new blank table
  end
end

local function updateStatusLabel()
  statusLabel.text = string.format('CPU: %d free / %d total   Recipes:  %d errors  %d ongoing  %d queued',
  status.cpu.free, status.cpu.all, status.recipes.error, status.recipes.crafting, status.recipes.queue)
end

-- reset middle panel
local function clearDisplay()
  itemName_label.text = ""
  itemStored_label.text = ""
  itemWanted_label.text = ""
  itemThreshold_label.text = ""
  addRecipe_button.hidden = true
  editRecipe_button.hidden = true
  removeRecipe_button.hidden = true
end

-- type 0 = left panel, 1 = right panel (non filtered), 2 = right panel (filtered)
local function displayItem(type, idx)
  if type == 0 then
    availableRecipes_list.selectedItem = -1
    addRecipe_button.hidden = true
    editRecipe_button.hidden = false
    removeRecipe_button.hidden = false
    itemName_label.text = selectedRecipes[idx].label
    itemStored_label.text = string.format("Stored: %d", selectedRecipes[idx].stored)
    itemWanted_label.text = string.format("Wanted: %d", selectedRecipes[idx].wanted)
    itemThreshold_label.text = string.format("Threshold: %d", selectedRecipes[idx].threshold)
  elseif type == 1 then
    selectedRecipes_list.selectedItem = -1
    addRecipe_button.hidden = false
    editRecipe_button.hidden = true
    removeRecipe_button.hidden = true
    itemName_label.text = availableRecipes[idx].label
    itemStored_label.text = string.format("Stored: %d", availableRecipes[idx].stored)
    itemWanted_label.text = ""
    itemThreshold_label.text = ""
  else 
    selectedRecipes_list.selectedItem = -1
    addRecipe_button.hidden = false
    editRecipe_button.hidden = true
    removeRecipe_button.hidden = true
    itemName_label.text = filteredRecipes[idx].label
    itemStored_label.text = string.format("Stored: %d", filteredRecipes[idx].stored)
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

local function filter(array, predicate)
  local res = {}
  for _, v in ipairs(array) do
      if predicate(v) then table.insert(res, v) end
  end
  return res
end

local function contains(haystack, needle)
  if haystack == needle then return true end
  if type(haystack) ~= type(needle) or type(haystack) ~= 'table' then return false end

  for k, v in pairs(needle) do
      if not contains(haystack[k], v) then return false end
  end

  return true
end

-- check if AE2 is connected
local function checkComponent()
  if not component.isAvailable("me_interface") then
    GUI.alert("No Applied Energistics Interface found!")
    workspace:stop()
  end
  ae2 = component.get("me_interface")
end

-- return true if recipe is done crafting or was canceled
function checkFuture(recipe)
  if not recipe.crafting then return end

  local canceled, err = recipe.crafting.isCanceled()
  if canceled or err then
      recipe.crafting = nil
      recipe.error = err or 'canceled'
      return true
  end

  local done, err = recipe.crafting.isDone()
  if err then recipe.error = err end
  if done then
      recipe.crafting = nil
      return true
  end

  return false
end

-- load all items that are craftable from AE2 network
local function updateRecipes(learnNewRecipes)

  -- index saved recipes
  local index = {}
  for _, recipe in ipairs(selectedRecipes) do
      local key = itemKey(recipe.item, recipe.item.label ~= nil)
      index[key] = { recipe=recipe, matches={} }
  end

  -- retrieve all items in network
  local items, err = ae2.getItemsInNetwork()
  if err then 
    GUI.alert(err) 
    workspace:stop()
  end

  if learnNewRecipes then availableRecipes = {} end -- clear table if available recipes need to be updated

  -- loop returned items and check if they are craftable
  for _, item in ipairs(items) do
    local key = itemKey(item, item.hasTag)
    local indexed = index[key] -- check if item is already accounted for in saved recipes

    if indexed then
      table.insert(indexed.matches, item)
    elseif learnNewRecipes and item.isCraftable then
        local recipe = {
            item = {
                name = item.name,
                damage = math.floor(item.damage)
            },
            label = item.label,
            wanted = 0
        }
        -- GUI.alert(recipe) --debugging
        if item.hasTag then
            -- By default, OC doesn't expose items NBT, so as a workaround we use the label as
            -- an additional discriminant. This is not perfect (still some collisions, and locale-dependent)
            recipe.item.label = recipe.label
        end
        table.insert(availableRecipes, recipe)
        index[key] = { recipe=recipe, matches={item} }
    end
  end

  -- Check the recipes
  for _, entry in pairs(index) do
    local recipe = entry.recipe
    local matches = filter(entry.matches, function(e) return contains(e, recipe.item) end)
    local craftable = false
    recipe.error = nil

    checkFuture(recipe)

    if #matches == 0 then
        recipe.stored = 0
    elseif #matches == 1 then
        local item = matches[1]
        recipe.stored = math.floor(item.size)
        craftable = item.isCraftable
    else
        local id = recipe.item.name .. ':' .. recipe.item.damage
        recipe.stored = 0
        recipe.error = id .. ' match ' .. #matches .. ' items'
    end

    if not recipe.error and recipe.wanted > 0 and not craftable then
        -- Warn the user as soon as an item is not craftable rather than wait to try
        recipe.error = 'Not craftable'
    end
  end

  if learnNewRecipes then
    updateAvailableRecipeList(availableRecipes, 1) --update right panel
  end
end

local function addRecipe()
  local container, amount, threshold, submit = add_Container()

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
      
      recipe.wanted = math.floor(tonumber(amount.text))
      recipe.threshold = math.floor(tonumber(threshold.text))
      table.insert(selectedRecipes, recipe)
      -- GUI.alert(recipe) --debugging
      
      writeRecipes(selectedRecipes) -- save to table
      updateSelectedRecipeList() -- update left panel list
      updateAvailableRecipeList(availableRecipes, 1) -- reset right panel
      clearDisplay() -- reset center display
      container:remove() -- remove container
    else 
      GUI.alert("Missing/Invalid Input!")
    end
  end
end

local function editRecipe()
  local recipe = selectedRecipes[selectedRecipes_list.selectedItem]
  local container, amount, threshold, submit = edit_Container(recipe.wanted, recipe.threshold)

  submit.onTouch = function()
    if tonumber(amount.text) ~= nil and tonumber(threshold.text) ~= nil then
      recipe.wanted = math.floor(tonumber(amount.text))
      recipe.threshold = math.floor(tonumber(threshold.text))
      -- GUI.alert(recipe) --debugging
      
      writeRecipes(selectedRecipes) -- save to table
      clearDisplay() -- reset center display
      container:remove() -- remove container
    else 
      GUI.alert("Missing/Invalid Input!")
    end
  end
end

local function removeRecipe()
  local recipe = selectedRecipes[selectedRecipes_list.selectedItem]
  local container, submit = remove_Container(recipe.label)

  submit.onTouch = function()
    table.remove(selectedRecipes, selectedRecipes_list.selectedItem)
    updateRecipes(true)
    writeRecipes(selectedRecipes) -- save to table
    updateSelectedRecipeList() -- update left panel list
    clearDisplay() -- reset center display
    container:remove()
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
    updateRecipes(true)
  end
  clearDisplay()
end

-- checks CPU status
local function enoughCpus(available, ongoing, free)
  if free == 0 then return false end
  if ongoing == 0 then return true end
  if allowedCpus == 0 then return true end
  if allowedCpus > 0 and allowedCpus < 1 then
      return  (ongoing + 1) / available <= allowedCpus
  end
  if allowedCpus >= 1 then
      return ongoing < allowedCpus
  end
  if allowedCpus > -1 then
      return (free - 1) / available <= -allowedCpus
  end
  return free > -allowedCpus
end

-- checks if any CPU are available
local function hasFreeCpu()
  local cpus = ae2.getCpus()
  local free = 0
  for i, cpu in ipairs(cpus) do
      if not cpu.busy then free = free + 1 end
  end
  local ongoing = 0
  for _, recipe in ipairs(selectedRecipes) do
      if recipe.crafting then ongoing = ongoing + 1 end
  end

  if enoughCpus(#cpus, ongoing, free) then
      return true
  else
      return false
  end
end

local function findRecipeWork()
  for _, recipe in ipairs(selectedRecipes) do
      if recipe.error or recipe.crafting then goto continue end

      local needed = recipe.wanted - recipe.stored
      if needed <= (recipe.wanted - recipe.threshold) then goto continue end --check if needed is below set threshold
      if needed <= 0 then goto continue end

      event.sleep(1)
      local craftables, err = ae2.getCraftables(recipe.item)
      if err then
          recipe.error = 'ae2.getCraftables ' .. tostring(err)
      elseif #craftables == 0 then
          recipe.error = 'No crafting pattern found'
      elseif #craftables == 1 then
          coroutine.yield(recipe, needed, craftables[1])
      else
          recipe.error = 'Multiple crafting patterns'
      end

      ::continue::
  end
end

function updateStatus(duration)

  -- CPU data
  local cpus = ae2.getCpus()
  status.cpu = {
      all = #cpus,
      free = 0,
  }
  for _, cpu in ipairs(cpus) do
      status.cpu.free = status.cpu.free + (cpu.busy and 0 or 1)
  end

  -- Recipe stats
  status.recipes = {
      error = 0,
      crafting = 0,
      queue = 0,
  }
  for _, recipe in ipairs(selectedRecipes) do
      if recipe.error then
          status.recipes.error = status.recipes.error + 1
      elseif recipe.crafting then
          status.recipes.crafting = status.recipes.crafting + 1
      elseif (recipe.stored or 0) < (recipe.wanted or 0) then
          status.recipes.queue = status.recipes.queue + 1
      end
  end

  updateStatusLabel()
end

-- main loop function
function ae2Run(learnNewRecipes)
  updateRecipes(learnNewRecipes)

  local finder = coroutine.create(findRecipeWork)
  while hasFreeCpu() do
      local _, recipe, needed, craft = coroutine.resume(finder) -- finds any work dispatches until all CPUs are used

      if recipe then
          -- Request crafting
          local amount = math.min(needed, maxBatch)
          recipe.crafting = craft.request(amount)
          event.sleep(1)
          checkFuture(recipe) -- might fail very quickly (missing resource, ...)
      else
          break
      end
  end

  drawTaskBadges()
  updateStatus()
  workspace:draw()
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

    updateRecipes(true)
    updateSelectedRecipeList()
    workspace:draw()
  end
end

search_input.onInputFinished = function()
  filterAvailableRecipes()
end

addRecipe_button.onTouch = function()
  addRecipe()
end

editRecipe_button.onTouch = function()
  editRecipe()
end

removeRecipe_button.onTouch = function()
  removeRecipe()
end

---------------------------------------------------------------------------------
-- main
checkComponent()
loadRecipes() --load selected recipes

-- checks if any recipes have finished crafting or was cancelled to force main loop call
event.addHandler(function()
  for _, recipe in ipairs(selectedRecipes) do
    if checkFuture(recipe) then
      ae2Run(false)
      return
    end
  end
end, craftingCheckInterval)

-- main loop
event.addHandler(function(e1)
  ae2Run(false)
end, fullCheckInterval)

workspace:draw()
workspace:start()
