local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packet = require(ReplicatedStorage.Packages.Packet)
return {
    PlaySound = Packet("PlaySound", Packet.NumberF64, Packet.Boolean8),
	PlaySoundAt = Packet("PlaySoundAt", Packet.NumberF64, Packet.Instance),
	Notify = Packet("Notify", Packet.StringLong),
	Error = Packet("Error", Packet.StringLong),
	Announce = Packet("Announce", Packet.StringLong, Packet.NumberF64),
	SendChatMessage = Packet("SendChatMessage", Packet.StringLong),
	CanPurchase = Packet("CanPurchase", Packet.NumberF64):Response(Packet.Boolean8),
	AttemptPurchase = Packet("AttemptPurchase", Packet.NumberF64),
}