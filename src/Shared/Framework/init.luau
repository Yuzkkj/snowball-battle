local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Promise = require(ReplicatedStorage.Packages.Promise)

local utils = require(script.Utils)

local isServer = RunService:IsServer()
local isClient = RunService:IsClient()

local framework = {}

framework.WaitForServer = true

if isServer then
	framework.Start = function(self: Framework)
		return Promise.new(function(resolve)
			local ServerScriptService = game:GetService("ServerScriptService")

			local servicesFolder = ServerScriptService.Services
			local componentsFolder = ServerScriptService.Components
			local handlersFolder = ServerScriptService.Handlers

			local services = utils.getContents(servicesFolder)

			warn(`Initializing services`)
			utils.callFrom("Init", services, function(serviceName)
				print(`{serviceName} initialized`)
			end)

			warn(`Starting services`)
			utils.callFrom("Start", services, function(serviceName)
				print(`{serviceName} started`)
			end)

			local components = utils.getContents(componentsFolder)

			warn(`Starting components`)
			utils.startComponents(components)

			if self.WaitForServer then
				script:SetAttribute("ServerFinished", true)
			end

			local handlers = utils.getContents(handlersFolder)

			warn(`Starting handlers`)
			utils.callFrom("Start", handlers, function(handlerName)
				print(`{handlerName} handler started`)
			end)

			resolve()
		end)
	end
end

if isClient then
	framework.Start = function(self: Framework)
		return Promise.new(function(resolve)
			if self.WaitForServer and not script:GetAttribute("ServerFinished") then
				print("Waiting for server to load...")

				repeat
					task.wait(1)
				until script:GetAttribute("ServerFinished")
			end

			local controllersFolder = ReplicatedStorage.Controllers
			local componentsFolder = ReplicatedStorage.Components
			local handlersFolder = ReplicatedStorage.Handlers
			local userInterfaceFolder = ReplicatedStorage.UserInterface

			local controllers = utils.getContents(controllersFolder)

			warn(`Initializing controllers`)
			utils.callFrom("Init", controllers, function(controllerName)
				print(`{controllerName} initialized`)
			end)

			warn(`Starting controllers`)
			utils.callFrom("Start", controllers, function(controllerName)
				print(`{controllerName} started`)
			end)

			local components = utils.getContents(componentsFolder)

			warn(`Starting components`)
			utils.startComponents(components)

			local handlers = utils.getContents(handlersFolder)

			warn("Starting handlers")
			utils.callFrom("Start", handlers, function(handlerName)
				print(`{handlerName} handler started`)
			end)

			local contents = utils.getContents(userInterfaceFolder)

			warn(`Starting user interface`)
			utils.callFrom("Start", contents, function(contentName)
				print(`Started UI {contentName}`)
			end)

			resolve()
		end)
	end
end

type Framework = typeof(framework)

return framework :: Framework
