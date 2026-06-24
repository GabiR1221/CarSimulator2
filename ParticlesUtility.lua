--ParticlesModule in UtilitesModule
local Particles = {}

Particles.PlayParticle = function(Parent, Particle, EmitCount, Properties)
	local suc,er = spawn(function()
		if game.Players.LocalPlayer.Data.Settings.Effects.Value then
			local Attachment = Instance.new("Attachment")
			Attachment.Parent = Parent
			local NewParticle = Particle:Clone()
			NewParticle.Color = Properties.Color or NewParticle.Color
			NewParticle.Parent = Attachment
			
			NewParticle:Emit(EmitCount)
			task.wait(NewParticle.Lifetime.Max * 2)
			Attachment:Destroy()
		end
	end)
	
	if er then warn(er) end
end

return Particles
