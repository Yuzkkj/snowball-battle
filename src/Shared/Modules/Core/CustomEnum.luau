local module = {}

module.NotificationType = {
	Notification = "Notification",
	Error = "Error",
	Announce = "Announce",
}

export type NotificationType = keyof<typeof(module.NotificationType)>

return module
