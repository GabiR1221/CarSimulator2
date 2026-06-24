--TweenModule in UtilitesModule
local Module = {}

local TweenService = game:GetService("TweenService")

function Module.Tween(Object, Info, Goal1)
	local info = TweenInfo.new(
		Info.Speed or 0.25,
		Info.EasingStyle or Enum.EasingStyle.Quad,
		Info.EasingDirection or Enum.EasingDirection.In,
		Info.RepeatCount or 0,
		Info.Reverses or false,
		Info.DelayTime or 0
	)
	
	local Tween = TweenService:Create(Object, info, Goal1)
	Tween:Play()
end

function Module.TweenModel(EndCFrame,TI,Model)
	local NewCFrameValue = Instance.new("CFrameValue")
	NewCFrameValue.Value = Model.PrimaryPart.CFrame
	local Tween = TweenService:Create(NewCFrameValue,TI,EndCFrame)
	local Connection
	Connection = NewCFrameValue.Changed:Connect(function()
		Model:PivotTo(NewCFrameValue.Value)
	end)
	Tween:Play()
	Tween.Completed:Connect(function()
		NewCFrameValue:Destroy()
		Connection:Disconnect()
	end)
end

return Module
