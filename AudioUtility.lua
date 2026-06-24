---AudioModule in UtilitesModule
local module = {}

module.PlayAudio = function(Soundname, Volume)
	coroutine.wrap(function()
		local Sound = game.ReplicatedStorage.Assets.Sounds[Soundname]:Clone()
		Sound.Volume = Volume or Sound.Volume
		Sound.Parent = game.SoundService
		Sound:Play()
		wait(Sound.TimeLength)
		Sound:Destroy()
	end)()
end

return module
