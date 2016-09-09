
--[[
		Filename: PerformanceStatsManagerScript.lua
		Written by: dbanks
		Description: Handles performance stats gui.
--]]

--[[ Services ]]--
local PlayersService = game:GetService("Players")
local Settings = UserSettings()
local GameSettings = Settings.GameSettings
local CoreGuiService = game:GetService('CoreGui')

--[[ Modules ]]--
local StatsAggregatorManagerClass = require(CoreGuiService.RobloxGui.Modules.Stats.StatsAggregatorManager)
local StatsButtonClass = require(CoreGuiService.RobloxGui.Modules.Stats.StatsButton)
local StatsViewerClass = require(CoreGuiService.RobloxGui.Modules.Stats.StatsViewer)
local StatsUtils = require(CoreGuiService.RobloxGui.Modules.Stats.StatsUtils)
local TopbarConstants = require(CoreGuiService.RobloxGui.Modules.TopbarConstants)

--[[ Fast Flags ]]--
local getShowPerformanceStatsInGuiSuccess, showPerformanceStatsInGuiValue = 
	pcall(function() return settings():GetFFlag("ShowPerformanceStatsInGui") end)
local showPerformanceStatsInGui = getShowPerformanceStatsInGuiSuccess and showPerformanceStatsInGuiValue


--[[ Script Variables ]]--
local masterFrame = Instance.new("Frame")
masterFrame.Name = "PerformanceStats"

local statsAggregatorManager = StatsAggregatorManagerClass.new()
local statsViewer = StatsViewerClass.new()
local statsButtonsByType ={}
local currentDisplayType = nil

for i, displayType in ipairs(StatsUtils.AllStatDisplayTypes) do
  local button = StatsButtonClass.new(displayType)
  statsButtonsByType[displayType] = button
end

--[[ Functions ]]--
function ConfigureMasterFrame()
  -- Set up the main frame that contains the whole PS GUI.  
  -- Avoid the top button bar.
  masterFrame.Position = UDim2.new(0, 0, 0, 0)
  masterFrame.Size = UDim2.new(1, 0, 1, 0)
  masterFrame.Selectable = false
  masterFrame.BackgroundTransparency = 0.8
  masterFrame.Active = false  
  masterFrame.ZIndex = 0
  
  -- FIXME(dbanks)
  -- Debug, can see the whole frame.
  -- masterFrame.BackgroundColor3 = Color3.new(0, 0.5, 0.5)
  -- masterFrame.BackgroundTransparency = 0.8  
end

function ConfigureStatButtonsInMasterFrame()
  -- Set up the row of buttons across the top and handler for button press.
  for i, displayType in ipairs(StatsUtils.AllStatDisplayTypes) do
    AddButton(displayType, i)
  end
end

function OnButtonToggled(toggledDisplayType) 
  local toggledButton = statsButtonsByType[toggledDisplayType]
  local selectedState = toggledButton._isSelected
  selectedState = not selectedState
  
  if (selectedState) then 
    currentDisplayType = toggledDisplayType
  else
    currentDisplayType = nil
  end
  
  UpdateButtonSelectedStates()
  UpdateViewerVisibility()
end

function UpdateButtonSelectedStates()
  for i, buttonType in ipairs(StatsUtils.AllStatDisplayTypes) do
      local button = statsButtonsByType[buttonType]
      button:SetIsSelected(buttonType == currentDisplayType)
  end  
end

function UpdateViewerVisibility()
  -- If someone is on, show the Viewer.
  -- FIXME(dbanks)
  -- Configure with details of the dude currently selected.  
  if (currentDisplayType == nil) then 
    statsViewer:SetVisible(false)
    statsViewer:SetStatsAggregator(nil)
  else
    statsViewer:SetStatsDisplayType(currentDisplayType)
    local aggregatorType = StatsUtils.DisplayTypeToAggregatorType[currentDisplayType]
    statsViewer:SetStatsAggregator(statsAggregatorManager:GetAggregator(aggregatorType))
    
    statsViewer:SetVisible(true)
  end
end

function AddButton(displayType, index) 
  -- Configure size and position of button.
  -- Configure callback behavior to toggle
  --    button on or off and show/hide viewer.
  -- Parent button in main screen.
  local button = statsButtonsByType[displayType]
  
  button:SetParent(masterFrame)
  local aggregatorType = StatsUtils.DisplayTypeToAggregatorType[displayType]
  button:SetStatsAggregator(
    statsAggregatorManager:GetAggregator(aggregatorType))
  
  local fraction = 1.0/StatsUtils.NumButtonTypes
  local size = UDim2.new(fraction, 0, 0, StatsUtils.ButtonHeight)
  local position = UDim2.new(fraction * (index - 1), 0, 0, 0)
  button:SetSizeAndPosition(size, position)
  
  button:SetToggleCallbackFunction(OnButtonToggled)
end

function ConfigureStatViewerInMasterFrame()
  -- Set up the widget that shows currently selected button.
  statsViewer:SetParent(masterFrame)
  
  local size = UDim2.new(0.5, 0, 0.5, 0)
  local position = UDim2.new(0.5, 0, 0.25, 0)
  statsViewer:SetSizeAndPosition(size, position)
end

function UpdatePerformanceStatsVisibility() 
  local localPlayer = PlayersService.LocalPlayer
  
  local isVisible = (GameSettings.PerformanceStatsVisible and localPlayer ~= nil)
  if isVisible then 
    masterFrame.Visible = true
    masterFrame.Parent = CoreGuiService.RobloxGui
  else
    masterFrame.Visible = false
    masterFrame.Parent = nil
  end
end


--[[ Top Level Code ]]--
-- If flag is not enabled, bounce.
if not showPerformanceStatsInGui then 
	return
end

-- Set up our GUI.
ConfigureMasterFrame()
ConfigureStatButtonsInMasterFrame()
ConfigureStatViewerInMasterFrame()

-- Watch for changes in performance stats visibility.
GameSettings.PerformanceStatsVisibleChanged:connect(
  UpdatePerformanceStatsVisibility)

-- Start listening for updates in stats.
statsAggregatorManager:StartListening()

-- Make sure we're showing buttons and viewer based on current selection.
UpdateButtonSelectedStates()
UpdateViewerVisibility()

-- Make sure stats are visible or not, as specified by current setting.
UpdatePerformanceStatsVisibility()

-- This may change if Player shows up...
spawn(function()
    local localPlayer = PlayersService.LocalPlayer
    while not localPlayer do
      PlayersService.PlayerAdded:wait()
      localPlayer = PlayersService.LocalPlayer
    end
    UpdatePerformanceStatsVisibility()
end)
