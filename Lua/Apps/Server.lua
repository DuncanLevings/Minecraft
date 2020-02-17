
-- Import libraries
local GUI = require("GUI")
local system = require("System")
local event = require("Event")
local fs = require("Filesystem")
local net = require("Network")
local component = require("Component")
local text = require("Text")

---------------------------------------------------------------------------------
-- GUI

-- Add a new window to MineOS workspace
local workspace = GUI.workspace()

-- Main background
workspace:addChild(GUI.panel(1, 1, workspace.width, workspace.height, 0x2D2D2D))

-- Layout grid of 2 col - 2 row
local layout = workspace:addChild(GUI.layout(1, 1, workspace.width, workspace.height, 2, 2))

-- layout.showGrid = true -- for debugging

layout:setRowHeight(1, GUI.SIZE_POLICY_ABSOLUTE, 5)
layout:setRowHeight(2, GUI.SIZE_POLICY_ABSOLUTE, 45)

-- top button row
layout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
layout:setDirection(2, 1, GUI.DIRECTION_HORIZONTAL)

local addNew = layout:setPosition(1, 1, layout:addChild(GUI.button(1, 1, 29, 3, 0xE1E1E1, 0x0F0F0F, 0x696969, 0xE1E1E1, "Add")))
local editSelected = layout:setPosition(1, 1, layout:addChild(GUI.button(1, 1, 25, 3, 0xE1E1E1, 0x0F0F0F, 0x696969, 0xE1E1E1, "Edit")))
local deleteSelected = layout:setPosition(1, 1, layout:addChild(GUI.button(1, 1, 14, 3, 0xE1E1E1, 0x0F0F0F, 0x696969, 0xE1E1E1, "Delete")))

layout:setSpacing(2, 1, 2)
local startServer = layout:setPosition(2, 1, layout:addChild(GUI.button(1, 1, 38, 3, 0x00FF00, 0x0F0F0F, 0x00FF00, 0x0F0F0F, "Start")))
startServer.disabled = true

local stopServer = layout:setPosition(2, 1, layout:addChild(GUI.button(1, 1, 38, 3, 0xFF0000, 0x0F0F0F, 0xFF0000, 0x0F0F0F, "Stop")))

-- data row list
local destList = layout:setPosition(1, 2, layout:addChild(GUI.list(1, 1, 70, 44, 3, 0, 0xE1E1E1, 0x4B4B4B, 0xD2D2D2, 0x4B4B4B, 0x3366CC, 0xFFFFFF, false)))
destList.selectedItem = -1

-- data row log
-- Layout grid of 2 col - 1 row
local logLayout = layout:setPosition(2, 2, layout:addChild(GUI.layout(1, 1, 80, 44, 2, 1)))
logLayout:setRowHeight(1, GUI.SIZE_POLICY_ABSOLUTE, 45)

-- logLayout.showGrid = true -- for debugging

local destLog = logLayout:setPosition(1, 1, logLayout:addChild(GUI.textBox(1, 1, 38, 44, 0x2D2D2D, 0xFFFFFF, {}, 1, 1, 0)))
local recLog = logLayout:setPosition(2, 1, logLayout:addChild(GUI.textBox(1, 1, 38, 44, 0x2D2D2D, 0xFFFFFF, {}, 1, 1, 0)))

local function addNew_Container()
  local container = GUI.addBackgroundContainer(workspace, true, true, "Add New Destination")
  local name = container.layout:addChild(GUI.input(1, 1, 50, 3, 0xEEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "", "Enter Destination Name"))
  address = container.layout:addChild(GUI.input(1, 1, 50, 3, 0xEEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "", "Enter Destination Address"))

  local file = container.layout:addChild(GUI.filesystemChooser(2, 2, 50, 3, 0xE1E1E1, 0x888888, 0x3C3C3C, 0x888888, "/Mounts/", "Open", "Cancel", "Choose", "/"))
  file:setMode(GUI.IO_MODE_OPEN, GUI.IO_MODE_FILE)
  file:addExtensionFilter(".txt")

  local submit = container.layout:addChild(GUI.button(1, 1, 30, 3, 0xE1E1E1, 0x0F0F0F, 0x696969, 0xE1E1E1, "Add Destination"))

  return container, name, address, file, submit
end

local function edit_Container(name, address, path)
  local container = GUI.addBackgroundContainer(workspace, true, true, "Edit Destination")
  local name = container.layout:addChild(GUI.input(1, 1, 50, 3, 0xEEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, name, "Enter Destination Name"))
  local address = container.layout:addChild(GUI.input(1, 1, 50, 3, 0xEEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, address, "Enter Destination Address"))

  local file = container.layout:addChild(GUI.filesystemChooser(2, 2, 50, 3, 0xE1E1E1, 0x888888, 0x3C3C3C, 0x888888, path, "Open", "Cancel", "Choose", "/"))
  file:setMode(GUI.IO_MODE_OPEN, GUI.IO_MODE_FILE)
  file:addExtensionFilter(".txt")

  local submit = container.layout:addChild(GUI.button(1, 1, 30, 3, 0xE1E1E1, 0x0F0F0F, 0x696969, 0xE1E1E1, "Save Destination"))

  return container, name, address, file, submit
end

local function delete_Container(name)
  local container = GUI.addBackgroundContainer(workspace, true, true, "Confirm Delete")
  local submit = container.layout:addChild(GUI.button(1, 1, 30, 3, 0xCC0000, 0x0F0F0F, 0xFF0000, 0x0F0F0F, string.format("Delete %s", name)))
  return container, submit
end

---------------------------------------------------------------------------------
-- App variables

local dataPath = "/home/destTable.txt"
local destTable = {}
local isActive = true

---------------------------------------------------------------------------------
-- App functions

local function GetFileName(url)
  return url:match("^.+/(.+)$")
end

-- add items to GUI list
local function updateList()
  -- clears the list
  destList.selectedItem = -1
  destList.children = {}

  for k, v in ipairs(destTable) do
    destList:addItem(string.format("%s - %s - %s", v.name, v.address, GetFileName(v.file)))
  end
end

-- update destination table
local function writeDestTable(data) 
  local result, reason = fs.writeTable(dataPath, data, true)
  if result == true then
    readDestTable()
    updateList()
  else
    GUI.alert(reason)
  end
end

-- update data
local function writeDataTable(path, data) 
  local result, reason = fs.writeTable(path, data, true)
  if result == true then
    readDestTable()
    -- updateList()
  else
    GUI.alert(reason)
  end
end

-- read from table data and populate file data
function readDestTable() 
  destTable = fs.readTable(dataPath)
  for k, v in ipairs(destTable) do
    v.data = fs.readTable(v.file) -- populate table data from selected file
  end
end

-- retrieve all destinations
local function getDestinations() 
    if fs.exists(dataPath) then
      readDestTable()
      updateList()
    else 
      -- new blank dest table
      writeDestTable({})
    end
end

-- checks if table contains key
local function setContains(value)
  for k, v in ipairs(destTable) do
    if v.name == value then
      return true
    end
  end

  return false
end

-- adding a new destination
local function addDestination()
  container, name, address, file, submit = addNew_Container()

  local filePath
  file.onSubmit = function(path)
    filePath = path
  end 

  submit.onTouch = function()
    if #name.text > 0 and #address.text > 0 and filePath ~= nil then
      if setContains(name.text) then
        GUI.alert("Destination name already exists!")
      else
        table.insert(destTable, { name = name.text, address = address.text, file = filePath })
        -- save to table
        writeDestTable(destTable)
        -- remove container
        container:remove()
      end
    else 
      GUI.alert("Missing Input!")
    end
  end
end

-- edit selected destination
local function editDestination()
  if destList.selectedItem ~= -1 then
    item = destTable[destList.selectedItem]

    container, name, address, file, submit = edit_Container(item.name, item.address, item.file)
    local filePath
    file.onSubmit = function(path)
      filePath = path
    end 

    submit.onTouch = function()
      local path
      -- check if a new file was selected
      if filePath ~= nil then
        path = filePath
      else 
        path = item.file
      end

      if #name.text > 0 and #address.text > 0 and path ~= nil then
        if item.name ~= name.text and setContains(name.text) then
          GUI.alert("Destination name already exists!")
        else
          destTable[destList.selectedItem] = { name = name.text, address = address.text, file = path }
          -- save to table
          writeDestTable(destTable)
          -- remove container
          container:remove()
        end
      else 
        GUI.alert("Missing Input!")
      end
    end
  else 
    GUI.alert("Nothing selected to edit!")
  end
end

-- delete selected desination
local function deleteDesination()
  if destList.selectedItem ~= -1 then
    item = destTable[destList.selectedItem]

    container, submit = delete_Container(item.name)

    submit.onTouch = function()
      table.remove(destTable, destList.selectedItem)
      writeDestTable(destTable)
      container:remove()
    end
  else 
    GUI.alert("Nothing selected to delete!")
  end
end

local function serverSend()
  -- clear log
  -- destLog.lines = {}
  -- recLog.lines = {}

  for k, v in ipairs(destTable) do
    -- modem address, string data
    net.sendMessage(v.address, v.data.status)
    table.insert(destLog.lines, {text = string.format("Sending to ... %s", v.name), color = 0xFFFFFF})
  end
end

-- received data from remote clients
-- format of { status: true/false, data = {}}
local function serverReceive(source, data)
  for k, v in ipairs(destTable) do
    if v.address == source then
      
      local receivedTable, reason = text.deserialize(data)
      GUI.alert(receivedTable)
      -- writeDataTable(v.file, receivedTable)
      table.insert(recLog.lines, {text = string.format("Received from ... %s", v.name), color = 0xFFFFFF})
    end
  end
end

---------------------------------------------------------------------------------
-- event handles

addNew.onTouch = function()
  addDestination()
end

editSelected.onTouch = function()
  editDestination()
end

deleteSelected.onTouch = function()
  deleteDesination()
end

startServer.onTouch = function()
  isActive = true
  startServer.disabled = true
  stopServer.disabled = false
  workspace:draw()
end

stopServer.onTouch = function()
  isActive = false
  startServer.disabled = false
  stopServer.disabled = true
  workspace:draw()
end
---------------------------------------------------------------------------------
-- main

getDestinations() 

-- main loop for sending
-- event.addHandler(function()
--   if isActive then
--     serverSend()
--     workspace:draw()
--   end
-- end, 4)

-- main loop for receiving
-- e1 = event, e2 = destination, e3 = source, e4 = port, e5 = distance, e6 = message data
event.addHandler(function(e1, e2, e3, e4, e5, e6)
  if isActive then
    if e1 == "modem_message" then
      serverReceive(e3, e6)
      workspace:draw()
    end
  end
end)

workspace:draw()
workspace:start() -- Start processing events for workspace