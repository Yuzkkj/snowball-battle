local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local Signal = require(ReplicatedStorage.Packages.Signal)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

local INFO = TweenInfo.new(0.1, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut)

local GuiController = {
	_guis = {},
	_guiData = {},
}

local function openGui(gui: ScreenGui, guiData: { OriginalSize: UDim2, OpenedPosition: UDim2 })
	local mainFrame = gui:FindFirstChild("MainFrame") :: GuiObject
	if not mainFrame then
		return
	end

	playerGui.MainGui.Enabled = false

	TweenService:Create(Lighting.Blur, INFO, { Size = 12 }):Play()

	local originalSize = guiData.OriginalSize
	local openedPosition = guiData.OpenedPosition

	mainFrame.Size = UDim2.fromScale(0, 0)
	mainFrame.Position = UDim2.fromScale(openedPosition.X.Scale, 1.5)

	gui.Enabled = true

	TweenService:Create(mainFrame, INFO, {
		Size = originalSize,
		Position = openedPosition,
	}):Play()
end

local function closeGui(gui: ScreenGui, guiData: { OriginalSize: UDim2, OpenedPosition: UDim2 })
	local mainFrame = gui:FindFirstChild("MainFrame") :: GuiObject
	if not mainFrame then
		return
	end

	playerGui.MainGui.Enabled = true

	TweenService:Create(Lighting.Blur, INFO, { Size = 0 }):Play()

	local openedPosition = guiData.OpenedPosition

	local tween = TweenService:Create(mainFrame, INFO, {
		Size = UDim2.fromScale(0, 0),
		Position = UDim2.fromScale(openedPosition.X.Scale, 1.5),
	})
	tween:Play()
	tween.Completed:Once(function()
		gui.Enabled = false
	end)
end

function GuiController.Init(self: GuiController): ()
	self.GuiOpened = Signal.new()
	self.GuiClosed = Signal.new()
end

function GuiController.Start(self: GuiController): ()
	CollectionService:GetInstanceAddedSignal("Gui"):Connect(function(screenGui)
		self:AddGui(screenGui)
	end)

	for _, screenGui in pairs(playerGui:GetChildren()) do
		if not screenGui:IsA("ScreenGui") then
			continue
		end

		if CollectionService:HasTag(screenGui, "Gui") then
			self:AddGui(screenGui)
		end
	end
end

function GuiController.AddGui(self: GuiController, gui: ScreenGui): ()
	if gui.Parent == game:GetService("StarterGui") then
		return
	end

	if not gui:IsA("ScreenGui") then
		error(`[C]: Expected type ScreenGui, got {typeof(gui)}.`)
	end

	local mainFrame = gui:FindFirstChild("MainFrame") :: GuiObject
	if mainFrame then
		self._guiData[gui.Name] = {
			OriginalSize = mainFrame.Size,
			OpenedPosition = mainFrame.Position,
		}
	end

	self._guis[gui.Name] = gui
end

function GuiController.RemoveGui(self: GuiController, name: string)
	local gui = self._guis[name]
	if gui ~= nil then
		if gui.Enabled then
			self:Close(name)
		end

		self._guis[name] = nil
		self._guiData[name] = nil
	end
end

function GuiController.Open(self: GuiController, guiName: string): ()
	local gui = self._guis[guiName]
	local guiData = self._guiData[guiName]

	if gui ~= nil and guiData ~= nil then
		if not gui.Enabled then
			for guiName, instance in pairs(self._guis) do
				if instance.Enabled then
					self:Close(guiName)
				end
			end

			task.spawn(openGui, gui, guiData)

			self.GuiOpened:Fire(guiName)
		else
			task.spawn(closeGui, gui, guiData)
		end
	else
		warn(`[C]: No Gui founded with name "{guiName}".`)
	end
end

function GuiController.Close(self: GuiController, guiName: string): ()
	local gui = self._guis[guiName]
	local guiData = self._guiData[guiName]

	if gui ~= nil and guiData ~= nil then
		if gui.Enabled then
			task.spawn(closeGui, gui, guiData)

			self.GuiClosed:Fire(guiName)
		else
			warn(`[C]: {guiName} Gui is already closed.`)
		end
	else
		error(`[C]: No Gui founded with name "{guiName}".`)
	end
end

type GuiController = typeof(GuiController) & {
	GuiOpened: Signal.Signal<string>,
	GuiClosed: Signal.Signal<string>,
}

return GuiController :: GuiController
