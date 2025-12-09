-- Formats a number of seconds into a time string.
type Format = "Compact" | "Extended"

local function compact(seconds: number): string
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60

	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	else
		return string.format("%02d:%02d", minutes, secs)
	end
end

local function extended(seconds: number): string
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60

	if days > 0 then
		return string.format("%dd %dh %dm", days, hours, minutes)
	else
		return string.format("%dh %dm %ds", hours, minutes, secs)
	end
end

local function formatTime(seconds: number, format: Format?): string
	format = format or "Compact"
	seconds = math.max(0, math.floor(seconds))

	if format == "Compact" then
		return compact(seconds)
	elseif format == "Extended" then
		return extended(seconds)
	else
		return tostring(seconds)
	end
end

return formatTime
