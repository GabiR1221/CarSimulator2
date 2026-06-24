---ButtonAnimationsModule in UtilitesModule
local ButtonAnimations = {}
local Tween = require(script.Parent.Tween)

--// Creates the animation of the buttons
ButtonAnimations.Create = function(Frame : Button, Modifier : SizeModifier, Length : TweenLength)
	local BaseSize = {X = Frame.Size.X.Scale, Y = Frame.Size.Y.Scale}
	
	local HasOverlay = false
	local HasGradientBorder = false
		
	if Frame:FindFirstChild("Overlay") then -- for if there is an overlay it will do 3d effect
		HasOverlay = {X = Frame.Overlay.Size.X.Scale, Y = Frame.Overlay.Size.Y.Scale}
	end
	
	if Frame:FindFirstChild("Border") and Frame.Border:FindFirstChild("UIGradient") then -- for if there is a gradient itll change offset
		HasGradientBorder = {X = Frame.Border.UIGradient.Offset.X, Y = Frame.Border.UIGradient.Offset.Y}
	end
		
	--// Setup
	if not Length then Length = 0.075 end
	if not Modifier then Modifier = 1.05 end 
	
	--// Hover in & out
	Frame.MouseEnter:Connect(function()
		Frame:TweenSize(UDim2.fromScale(BaseSize.X * Modifier, BaseSize.Y * Modifier), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, Length)
		
		--// 3D Effect
		
		if HasOverlay then
			Frame.Overlay:TweenSize(UDim2.fromScale(HasOverlay.X*Modifier,HasOverlay.Y*Modifier), Enum.EasingDirection.Out, Enum.EasingStyle.Linear, Length, true)
		end
		
		--// Rotate Gradient
		if HasGradientBorder then
			Tween.Tween(Frame.Border.UIGradient, {Speed = Length}, {Offset = Vector2.new(HasGradientBorder.X + 0.5, HasGradientBorder.Y)})
		end
	end)
		
	Frame.MouseLeave:Connect(function()
		wait(Length)
		Frame:TweenSize(UDim2.fromScale(BaseSize.X, BaseSize.Y), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, Length)
		
		--// Resets overlay
		if HasOverlay then
			Frame.Overlay:TweenSize(UDim2.fromScale(HasOverlay.X,HasOverlay.Y), Enum.EasingDirection.Out, Enum.EasingStyle.Linear, Length, true)
		end
		
		--// Resets Gradient
		
		if HasGradientBorder then
			Tween.Tween(Frame.Border.UIGradient, {Speed = Length}, {Offset = Vector2.new(HasGradientBorder.X, HasGradientBorder.Y)})
		end
	end)
	
	local Button = Frame:FindFirstChildOfClass("TextButton")
	
	--// Button Presses
	if Button then
		Button.MouseButton1Down:Connect(function()
			Frame:TweenSize(UDim2.fromScale(BaseSize.X / Modifier, BaseSize.Y / Modifier), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, Length/1.5)
		end)
		
		Button.MouseButton1Up:Connect(function()
			Frame:TweenSize(UDim2.fromScale(BaseSize.X * Modifier, BaseSize.Y * Modifier), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, Length/1.5)
			
			--// Resets overlay
			if HasOverlay then
				Frame.Overlay:TweenSize(UDim2.fromScale(HasOverlay.X,HasOverlay.Y), Enum.EasingDirection.Out, Enum.EasingStyle.Linear, Length/1.5, true)
			end
			
			--// Resets Gradient

			if HasGradientBorder then
				Tween.Tween(Frame.Border.UIGradient, {Speed = Length/1.5}, {Offset = Vector2.new(HasGradientBorder.X, HasGradientBorder.Y)})
			end
		end)
	end
end

return ButtonAnimations
