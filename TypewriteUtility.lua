--TypewriteModule in UtilitesModule
local module = {}

function module.Create(TextLabel, Text)
	local TextLength = string.len(Text)
	
	TextLabel.Text = Text
	TextLabel.MaxVisibleGraphemes = 0 -- Characters Visible
	
	repeat 
		task.wait(0.03) 
		TextLabel.MaxVisibleGraphemes += 1
	until
		TextLabel.MaxVisibleGraphemes == TextLength
end

return module
