local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local PlayerDataController = require(script.Parent.PlayerDataController)
local MusicController = require(script.Parent.MusicController)

local Signal = require(ReplicatedStorage.Packages.Signal)

local productsData = require(ReplicatedStorage.Modules.Game.ProductsData)
local soundIds = require(ReplicatedStorage.Modules.Game.SoundIds)
local packets = require(ReplicatedStorage.Modules.Game.Packets)

local player = Players.LocalPlayer
local purchaseGui = player.PlayerGui:WaitForChild("PurchaseGui")
local background = purchaseGui:WaitForChild("Background")
local icon = background:WaitForChild("Icon")

local VISIBILITY_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut)
local SPIN_INFO = TweenInfo.new(0.8, Enum.EasingStyle.Circular)
local SPIN_DELAY = 0.4

local PurchaseController = {}

function PurchaseController.Init(self: PurchaseController): ()
	self.GamepassAdded = Signal.new()
end

function PurchaseController.Start(self: PurchaseController): ()
	self._gamepasses = PlayerDataController:Get({"Gamepasses"})

	packets.AttemptPurchase.OnClientEvent:Connect(function(productId: number)
		self:AttemptPurchase(productId)
	end)

	PlayerDataController:GetValueInsertedSignal({"Gamepasses"}):Connect(function(gamepass: number)
		local alreadyExists = table.find(self._gamepasses, gamepass)

		if not alreadyExists then
			table.insert(self._gamepasses, gamepass)
		end

		self.GamepassAdded:Fire(gamepass, productsData[gamepass].Name)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
		if self._isBusy then
			self:_TogglePurchaseGui()
		end
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, wasPurchased)
		if self._isBusy then
			self:_TogglePurchaseGui()
		end
	end)
end

function PurchaseController._TogglePurchaseGui(self: PurchaseController): ()
	self._isBusy = not self._isBusy

	if self._isBusy then
		purchaseGui.Enabled = true

		MusicController:PlaySound(soundIds.PurchaseStarted)

		TweenService:Create(background, VISIBILITY_INFO, { BackgroundTransparency = 0.5 }):Play()
		TweenService:Create(icon, VISIBILITY_INFO, {
			Position = UDim2.fromScale(0.5, 0.5),
			ImageTransparency = 0,
		}):Play()

		while self._isBusy do
			local tween = TweenService:Create(icon, SPIN_INFO, { Rotation = 360 })

			tween:Play()

			tween.Completed:Wait()

			icon.Rotation = 0

			task.wait(SPIN_DELAY)
		end
	else
		local tween1 = TweenService:Create(background, VISIBILITY_INFO, {
			BackgroundTransparency = 1,
		})
		local tween2 = TweenService:Create(icon, VISIBILITY_INFO, {
			Position = UDim2.fromScale(0.5, 0.75),
			ImageTransparency = 1,
		})

		tween1:Play()
		tween2:Play()

		tween1.Completed:Wait()

		purchaseGui.Enabled = false
	end
end

function PurchaseController.HasGamepass(self: PurchaseController, gamepass: number | string): boolean
	repeat
		task.wait()
	until self._gamepasses

	if type(gamepass) == "number" then
		return table.find(self._gamepasses, gamepass) ~= nil
	elseif type(gamepass) == "string" then
		for productId, productData in pairs(productsData) do
			if productData.Name == gamepass and productData.Type == Enum.InfoType.GamePass then
				return table.find(self._gamepasses, productId) ~= nil
			end
		end

		error(`No gamepass with name "{gamepass}" was founded.`)
	else
		error("Type of gamepass should be either a number (gamepass id) or a string (gamepass name).")
	end
end

function PurchaseController.AttemptPurchase(self: PurchaseController, productId: number): ()
	if self._isBusy then
		return
	end

	local productData = productsData[productId]
	if not productData then
		return
	end

	if productData.Type == Enum.InfoType.GamePass and table.find(self._gamepasses, productId) then
		return
	end

	local canPrompt = packets.CanPurchase:Fire(productId)
	if not canPrompt then
		return
	end

	if productData.Type == Enum.InfoType.GamePass then
		MarketplaceService:PromptGamePassPurchase(player, productId)
	elseif productData.Type == Enum.InfoType.Product then
		MarketplaceService:PromptProductPurchase(player, productId)
	else
		return
	end

	self:_TogglePurchaseGui()
end

type PurchaseController = typeof(PurchaseController) & {
	_isBusy: boolean,
	_gamepasses: { number },
	GamepassAdded: Signal.Signal<number, string>,
}

return PurchaseController :: PurchaseController
