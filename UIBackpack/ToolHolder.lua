local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactRodux = require(ReplicatedStorage.Packages.RoactRodux)
local Maid = require(ReplicatedStorage.Packages.Maid)
local BackpackConfig = require(ReplicatedStorage.Shared.BackpackConfiguration)

local ToolHolder = Roact.Component:extend("ToolHolder")
local ToolComponent = require(script.Parent.Tool)

local ORDER_PRIORITY = {
	Primary = 1,
	Secondary = 2,
	Misc = 3,
}

function ToolHolder:AddTools(Tools, NewTool)
	local toolType = "Misc"
	if BackpackConfig.Primary[NewTool.Name] then
		toolType = "Primary"
	elseif BackpackConfig.Secondary[NewTool.Name] then
		toolType = "Secondary"
	end

	local insertPlace = 1
	local exists = false

	for i, v in pairs(Tools) do
		local origToolType = "Misc"
		if BackpackConfig.Primary[v.Name] then
			origToolType = "Primary"
		elseif BackpackConfig.Secondary[v.Name] then
			origToolType = "Secondary"
		end

		if toolType == "Misc" then
			insertPlace = #Tools + 1
		elseif ORDER_PRIORITY[toolType] < ORDER_PRIORITY[origToolType] then
			insertPlace = i
		end

		if NewTool == v then
			exists = true
		end
	end

	if not exists then
		table.insert(Tools, insertPlace, NewTool)

		local ToolMaid
		ToolMaid = self.Maid:GiveTask(NewTool.AncestryChanged:Connect(function(child, parent)
			if
				parent ~= Players.LocalPlayer:WaitForChild("Backpack", 0.1)
				and parent ~= Players.LocalPlayer.Character
			then
				local NewTools = self.state.Tools
				table.remove(NewTools, table.find(NewTools, child))

				self:setState({
					Tools = NewTools,
				})

				self.Maid[ToolMaid] = nil
			end
		end))
	end

	self.props.SetTools(Tools)

	return Tools
end

function ToolHolder:init()
	self.Maid = Maid.new()
	local Tools = {}
	for _, v in pairs(Players.LocalPlayer:WaitForChild("Backpack"):GetChildren()) do
		Tools = self:AddTools(Tools, v)
	end
	self:setState({ Tools = Tools })

	local function KeyWrapper(ActionName, InputState)
		if InputState ~= Enum.UserInputState.Begin then
			return
		end
		if ActionName == "ControlSelectUp" then
			self.props.ControlSelectUp()
		elseif ActionName == "ControlSelectDown" then
			self.props.ControlSelectDown()
		end
	end

	ContextActionService:BindAction("ControlSelectUp", KeyWrapper, false, Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction("ControlSelectDown", KeyWrapper, false, Enum.KeyCode.ButtonR1)

	self.Maid:GiveTask(function()
		ContextActionService:UnbindAction("ControlSelectUp")
		ContextActionService:UnbindAction("ControlSelectDown")
	end)
end

function ToolHolder:didMount()
	self.Maid:GiveTask(Players.LocalPlayer:WaitForChild("Backpack", 1).ChildAdded:Connect(function(child)
		local GTools = self:AddTools(self.state.Tools, child)
		self:setState({
			Tools = GTools,
		})
	end))
end

function ToolHolder:willUnmount()
	self.Maid:DoCleaning()
end

function ToolHolder:render()
	local Children = {
		UIListLayout = Roact.createElement("UIListLayout", {
			Padding = UDim.new(0, 3),
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for i, Tool in pairs(self.state.Tools) do
		Children[i] = Roact.createElement(ToolComponent, {
			LayoutOrder = i,
			PhysicalTool = Tool,
			SelectedNum = self.props.SelectedNum,
		})
	end

	return Roact.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 1, -5),
		Size = UDim2.fromOffset(581, 92),
		Visible = self.props.Visible,
	}, Children)
end

return RoactRodux.connect(function(state, _props)
	return {
		Selected = state.Selected,
		SelectedNum = state.SelectedNum,
		Visible = state.Visible,
	}
end, function(dispatch)
	return {
		ControlSelectUp = function()
			dispatch({ type = "ControllerChangeSelected", value = 1 })
		end,
		ControlSelectDown = function()
			dispatch({ type = "ControllerChangeSelected", value = -1 })
		end,
		SetTools = function(props)
			dispatch({ type = "SetTools", value = props })
		end,
	}
end)(ToolHolder)
