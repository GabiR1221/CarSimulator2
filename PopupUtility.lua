--PopupModule in UtilitesModule
local RS = game:GetService("ReplicatedStorage")
local Short = require(script.Parent.Short)
local Module = {}

local Player = game.Players.LocalPlayer

function CreatePopup(Type)
	if Player.Data.Settings.Popups.Value then
		local NewPopup = RS.Assets.Templates[Type]:Clone()
		NewPopup.Size = UDim2.new(0.1,0,0.1,0)
		NewPopup.Visible = true
		NewPopup.Parent = Player.PlayerGui.Interface.HUD.Popups
		return NewPopup
	end
	
	return
end

function PlayAnimation(Popup, Time)
	coroutine.wrap(function()
		Popup:TweenSize(UDim2.new(1,0,1,0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, Time * 0.2)
		task.wait(Time * 0.8)
		Popup:TweenSize(UDim2.new(0,0,0,0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, Time * 0.2)
		task.wait(Time * 0.2)
		Popup:Destroy()
	end)()
end

function Module.CreateBottomStatPopup(Amount, Stat, Colors, Time)
	local NewPopup = CreatePopup("BottomStatPopup")

	if not NewPopup then return end
	
	NewPopup.Amt.Text = "You got +"..Short.en(Amount)
	NewPopup.Stat.Text = Stat
	NewPopup.Stat.TextColor3 = Colors.TextColor  or Color3.fromRGB(255,255,255)
	NewPopup.Stat.UIGradient.Color = Colors.UIGradient or ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(255,255,255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,255))})
	NewPopup.Stat.UIStroke.Color = Colors.StrokeColor or Color3.fromRGB(0,0,0)
	
	PlayAnimation(NewPopup, Time)
end

--// So I don't have to copy paste the same RGB in every script
local function DefaultColors(Label, Color)
	if Color == "Green" then
		Label.TextColor3 = Color3.fromRGB(109, 255, 41)
		Label.UIStroke.Color = Color3.fromRGB(69, 157, 25)
	elseif Color == "Red" then
		Label.TextColor3 = Color3.fromRGB(255, 67, 67)
		Label.UIStroke.Color = Color3.fromRGB(181, 0, 0)
	else
		Label.TextColor3 = Color.TextColor
		Label.UIStroke.Color = Color.StrokeColor
	end
end

function Module.CreateBottomPopup(Message, Time, Color)
	local NewPopup = CreatePopup("BottomPopup")

	if not NewPopup then return end
	
	DefaultColors(NewPopup.Label, Color)
	NewPopup.Label.Text = Message

	PlayAnimation(NewPopup, Time)
end

return Module
