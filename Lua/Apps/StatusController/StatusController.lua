
-- Import libraries
local GUI = require("GUI")
local system = require("System")

---------------------------------------------------------------------------------
--GUI
local BACKGROUND = 0x2D2D2D
local FOREGROUND = 0xE1E1E1
local ACTIVE = 0x00DB40
local LIGHT_TEXT = 0xFFFFFF
local DARK_TEXT = 0x0

local workspace = GUI.workspace()
workspace:addChild(GUI.panel(1, 1, workspace.width, workspace.height, BACKGROUND))

-- HOME ---------------------------------------------------------

-- 13 col - 13 row
local homeLayout = workspace:addChild(GUI.layout(4, 3, workspace.width, workspace.height, 11, 9))
-- homeLayout.showGrid = true -- for debugging

--row styling
for i = 1, 9 do
  homeLayout:setRowHeight(i, GUI.SIZE_POLICY_ABSOLUTE, 5) -- row
  homeLayout:setAlignment(1, i, GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER) -- col - row
  homeLayout:setSpacing(1, i, 0) -- row
  homeLayout:setMargin(1, i, 0, 0) -- col - row
end
--col styling
for i = 1, 11 do
  homeLayout:setColumnWidth(i, GUI.SIZE_POLICY_ABSOLUTE, 14) -- col
  homeLayout:setAlignment(i, 1, GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_CENTER) -- col - row
  homeLayout:setSpacing(i, 1, 0) -- row
  homeLayout:setMargin(i, 1, 0, 0) -- col - row
end

-- HOME STATUS -------------------------------------------------
local homeStatus = workspace:addChild(GUI.layout(1, 1, workspace.width, workspace.height, 1, 1))
local returnHome = homeStatus:addChild(GUI.button(1, 1, 10, 3, FOREGROUND, DARK_TEXT, FOREGROUND, LIGHT_TEXT, "Back"))
homeStatus.hidden = true

local function addBadge(col, row)
  local badge = homeLayout:setPosition(6, 5, homeLayout:addChild(GUI.container(1, 1, 12, 5)))
  badge:addChild(GUI.panel(1, 1, badge.width, badge.height, ACTIVE))
  local button = badge:addChild(GUI.button(1, 1, 12, 5, ACTIVE, DARK_TEXT, ACTIVE, LIGHT_TEXT, "Home"))
  return button
end

---------------------------------------------------------------------------------
-- App variables
local homeButton = addBadge(6, 5)

---------------------------------------------------------------------------------
-- App functions

---------------------------------------------------------------------------------
-- event handles
returnHome.onTouch = function()
  homeLayout.hidden = false
  homeStatus.hidden = true
end

homeButton.onTouch = function()
  homeLayout.hidden = true
  homeStatus.hidden = false
end

---------------------------------------------------------------------------------
-- main

workspace:draw()
workspace:start()
