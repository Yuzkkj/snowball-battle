local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local MusicController = require(script.Parent.MusicController)

local CustomEnum = require(ReplicatedStorage.Modules.Core.CustomEnum)
local packets = require(ReplicatedStorage.Modules.Game.Packets)
local utils = require(script.Utils)

local channel = TextChatService:WaitForChild("TextChannels"):WaitForChild("RBXSystem")
local player = Players.LocalPlayer
local playerGui = player.PlayerGui

local template = ReplicatedStorage.Assets.NotificationTemplate

local LIFE_TIME = 4
local TWEEN_DURATION = 1
local DEFAULT_Y_SIZE = template.Size.Y.Scale
local NOTIFICATION_SOUND_ID = 17481582653
local ERROR_SOUND_ID = 87519554692663

type NotificationData = {
	Text: string,
	Instance: ImageLabel,
	TweenTime: number,
	CancelTweens: () -> (),
	PlayTweens: () -> (),
	Thread: thread,
	Type: CustomEnum.NotificationType,
	Amount: number,
}

local NotificationController = {
	_notifications = {} :: { NotificationData },
}

local function GetLayoutOrder(): number
	local maxOrder = -math.huge

	for _, notificationData: NotificationData in ipairs(NotificationController._notifications) do
		maxOrder = math.max(maxOrder, notificationData.Instance.LayoutOrder)
	end

	return maxOrder == -math.huge and 0 or maxOrder + 1
end

-- Checks if a message is already being displayed.
local function AlreadyExists(message: string): (boolean, NotificationData?)
	for _, NotificationData: NotificationData in NotificationController._notifications do
		if NotificationData.Text == message then
			return true, NotificationData
		end
	end

	return false
end

local function tweenSize(newNotification: ImageLabel)
	newNotification.Size = UDim2.fromScale(newNotification.Size.X.Scale, DEFAULT_Y_SIZE * 1.25)
	local sizeTween = TweenService:Create(
		newNotification,
		TweenInfo.new(0.05),
		{ Size = UDim2.fromScale(newNotification.Size.X.Scale, DEFAULT_Y_SIZE) }
	)

	sizeTween:Play()

	sizeTween.Completed:Wait()
end

function NotificationController.Start(self: NotificationController)
	packets.Notify.OnClientEvent:Connect(function(message: string)
		self:Notify(message)
	end)

	packets.Error.OnClientEvent:Connect(function(message: string)
		self:Error(message)
	end)

	packets.Announce.OnClientEvent:Connect(function(message: string, userId: number)
		self:Announce(message, userId)
	end)

	packets.SendChatMessage.OnClientEvent:Connect(function(message)
		self:SendChatMessage(message)
	end)
end

function NotificationController.Notify(self: NotificationController, message: string): ()
	local exists, notificationData = AlreadyExists(message)

	if exists and notificationData.Type == CustomEnum.NotificationType.Notification then
		if coroutine.status(notificationData.Thread) == "suspended" then
			task.cancel(notificationData.Thread)
		else
			notificationData.TweenTime = -1
			notificationData.CancelTweens()
		end

		notificationData.Amount += 1
		notificationData.Instance.TextLabel.Text = `{message} [x{notificationData.Amount}]`

		MusicController:PlaySound(NOTIFICATION_SOUND_ID, true)
		notificationData.Instance.LayoutOrder = GetLayoutOrder()
		tweenSize(notificationData.Instance)

		notificationData.Thread = task.delay(LIFE_TIME, notificationData.PlayTweens)
	else
		local newNotification = template:Clone()
		newNotification.TextLabel.Text = message
		newNotification.Parent = playerGui:WaitForChild("NotificationGui"):WaitForChild("Container")

		local tweens = {
			TweenService:Create(newNotification, TweenInfo.new(TWEEN_DURATION), { ImageTransparency = 1 }),
			TweenService:Create(newNotification.TextLabel, TweenInfo.new(TWEEN_DURATION), { TextTransparency = 1 }),
			TweenService:Create(
				newNotification.TextLabel.UIStroke,
				TweenInfo.new(TWEEN_DURATION),
				{ Transparency = 1 }
			),
		}

		MusicController:PlaySound(NOTIFICATION_SOUND_ID, true)

		notificationData = {
			["Text"] = message,
			["Instance"] = newNotification,
			["TweenTime"] = 0,
			["CancelTweens"] = function()
				for _, tween in next, tweens do
					tween:Cancel()

					newNotification.ImageTransparency = 0.75
					newNotification.TextLabel.TextTransparency = 0
					newNotification.TextLabel.UIStroke.Transparency = 0
				end
			end,
			["PlayTweens"] = function()
				for _, tween in next, tweens do
					tween:Play()
				end
				local connection = nil
				connection = RunService.Heartbeat:Connect(function(deltaTime)
					if notificationData.TweenTime == -1 then
						if connection then
							connection:Disconnect()
							connection = nil
						end
					end

					if not notificationData.TweenTime then
						if connection then
							connection:Disconnect()
							connection = nil
						end
					end

					notificationData.TweenTime += deltaTime
					if notificationData.TweenTime >= TWEEN_DURATION then
						self:RemoveMessage(message)
						if connection then
							connection:Disconnect()
							connection = nil
						end
					end
				end)
			end,
			["Type"] = CustomEnum.NotificationType.Notification,
			["Amount"] = 1,
		} :: NotificationData
		table.insert(self._notifications, notificationData)
		newNotification.LayoutOrder = GetLayoutOrder()

		tweenSize(newNotification)

		notificationData.Thread = task.delay(LIFE_TIME, notificationData.PlayTweens)
	end
end

function NotificationController.Error(self: NotificationController, message: string): ()
	local exists, notificationData = AlreadyExists(message)

	if exists and notificationData.Type == CustomEnum.NotificationType.Error then
		if coroutine.status(notificationData.Thread) == "suspended" then
			task.cancel(notificationData.Thread)
		else
			notificationData.TweenTime = -1
			notificationData.CancelTweens()
		end

		notificationData.Amount += 1
		notificationData.Instance.TextLabel.Text = `<b>{message} [x{notificationData.Amount}]</b>`

		MusicController:PlaySound(ERROR_SOUND_ID, true)
		notificationData.Instance.LayoutOrder = GetLayoutOrder()
		tweenSize(notificationData.Instance)

		notificationData.Thread = task.delay(LIFE_TIME, notificationData.PlayTweens)
	else
		local newNotification = template:Clone()
		newNotification.TextLabel.TextColor3 = Color3.fromRGB(255, 85, 85)
		newNotification.TextLabel.Text = `<b>{message}</b>`
		newNotification.Parent = playerGui:WaitForChild("NotificationGui"):WaitForChild("Container")

		local tweens = {
			TweenService:Create(newNotification, TweenInfo.new(TWEEN_DURATION), { ImageTransparency = 1 }),
			TweenService:Create(newNotification.TextLabel, TweenInfo.new(TWEEN_DURATION), { TextTransparency = 1 }),
			TweenService:Create(
				newNotification.TextLabel.UIStroke,
				TweenInfo.new(TWEEN_DURATION),
				{ Transparency = 1 }
			),
		}

		MusicController:PlaySound(ERROR_SOUND_ID, true)

		notificationData = {
			["Text"] = message,
			["Instance"] = newNotification,
			["TweenTime"] = 0,
			["CancelTweens"] = function()
				for _, tween in next, tweens do
					tween:Cancel()

					newNotification.ImageTransparency = 0.75
					newNotification.TextLabel.TextTransparency = 0
					newNotification.TextLabel.UIStroke.Transparency = 0
				end
			end,
			["PlayTweens"] = function()
				for _, tween in next, tweens do
					tween:Play()
				end
				local connection = nil
				connection = RunService.Heartbeat:Connect(function(deltaTime)
					if notificationData.TweenTime == -1 then
						if connection then
							connection:Disconnect()
							connection = nil
						end
					end

					if not notificationData.TweenTime then
						if connection then
							connection:Disconnect()
							connection = nil
						end
					end

					notificationData.TweenTime += deltaTime
					if notificationData.TweenTime >= TWEEN_DURATION then
						self:RemoveMessage(message)
						if connection then
							connection:Disconnect()
							connection = nil
						end
					end
				end)
			end,
			["Type"] = CustomEnum.NotificationType.Error,
			["Amount"] = 1,
		} :: NotificationData
		table.insert(self._notifications, notificationData)
		newNotification.LayoutOrder = GetLayoutOrder()

		tweenSize(newNotification)

		notificationData.Thread = task.delay(LIFE_TIME, notificationData.PlayTweens)
	end
end

function NotificationController.Announce(self: NotificationController, message: string, userId: number): ()
	local exists, notificationData = AlreadyExists(message)

	if exists and notificationData.Type == CustomEnum.NotificationType.Announcement then
		if coroutine.status(notificationData.Thread) == "suspended" then
			task.cancel(notificationData.Thread)
		else
			notificationData.TweenTime = -1
			notificationData.CancelTweens()
		end

		notificationData.Amount += 1
		local username = Players:GetNameFromUserIdAsync(userId) or "Unknown"
		local usernameColor = utils.getUsernameColor(username)
		notificationData.Instance.TextLabel.Text =
			`<b><font color="#{usernameColor:ToHex()}">{utils.getDisplayNameAsync(userId)}:</font></b> {message} [x{notificationData.Amount}]`

		MusicController:PlaySound(NOTIFICATION_SOUND_ID, true)
		notificationData.Instance.LayoutOrder = GetLayoutOrder()
		tweenSize(notificationData.Instance)

		notificationData.Thread = task.delay(LIFE_TIME, notificationData.PlayTweens)
	else
		local newNotification = template:Clone()
		local username = Players:GetNameFromUserIdAsync(userId) or "Unknown"
		local usernameColor = utils.getUsernameColor(username)
		local displayName = utils.getDisplayNameAsync(userId)
		newNotification.TextLabel.Text = `<b><font color="#{usernameColor:ToHex()}">{displayName}:</font></b> {message}`
		newNotification.Parent = playerGui:WaitForChild("NotificationGui"):WaitForChild("Container")

		local tweens = {
			TweenService:Create(newNotification, TweenInfo.new(TWEEN_DURATION), { ImageTransparency = 1 }),
			TweenService:Create(newNotification.TextLabel, TweenInfo.new(TWEEN_DURATION), { TextTransparency = 1 }),
			TweenService:Create(
				newNotification.TextLabel.UIStroke,
				TweenInfo.new(TWEEN_DURATION),
				{ Transparency = 1 }
			),
		}

		MusicController:PlaySound(NOTIFICATION_SOUND_ID, true)

		notificationData = {
			["Text"] = message,
			["Instance"] = newNotification,
			["TweenTime"] = 0,
			["CancelTweens"] = function()
				for _, tween in next, tweens do
					tween:Cancel()

					newNotification.ImageTransparency = 0.75
					newNotification.TextLabel.TextTransparency = 0
					newNotification.TextLabel.UIStroke.Transparency = 0
				end
			end,
			["PlayTweens"] = function()
				for _, tween in next, tweens do
					tween:Play()
				end
				local connection = nil
				connection = RunService.Heartbeat:Connect(function(deltaTime)
					if notificationData.TweenTime == -1 then
						if connection then
							connection:Disconnect()
							connection = nil
						end
					end

					if not notificationData.TweenTime then
						if connection then
							connection:Disconnect()
							connection = nil
						end
					end

					notificationData.TweenTime += deltaTime
					if notificationData.TweenTime >= TWEEN_DURATION then
						self:RemoveMessage(message)
						if connection then
							connection:Disconnect()
							connection = nil
						end
					end
				end)
			end,
			["Type"] = CustomEnum.NotificationType.Announcement,
			["Amount"] = 1,
		} :: NotificationData
		table.insert(self._notifications, notificationData)
		newNotification.LayoutOrder = GetLayoutOrder()

		self:SendChatMessage(`<font color="#{usernameColor:ToHex()}">{displayName}:</font> {message}`)

		tweenSize(newNotification)

		notificationData.Thread = task.delay(LIFE_TIME, notificationData.PlayTweens)
	end
end

function NotificationController.SendChatMessage(_: NotificationController, message: string): ()
	channel:DisplaySystemMessage(`<font color="#ffffff">{message}</font>`)
end

function NotificationController.RemoveMessage(self: NotificationController, message: string): boolean
	local exists, notificationData = AlreadyExists(message)
	if not exists then
		return false
	end

	notificationData = table.remove(self._notifications, table.find(self._notifications, notificationData))

	if coroutine.status(notificationData.Thread) == "suspended" then
		task.cancel(notificationData.Thread)
	else
		notificationData.TweenTime = -1
		notificationData.CancelTweens()
	end

	notificationData.Instance:Destroy()
	table.clear(notificationData)

	return true
end

type NotificationController = typeof(NotificationController)

return NotificationController :: NotificationController
