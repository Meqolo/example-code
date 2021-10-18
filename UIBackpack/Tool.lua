--// Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

--// Dependencies

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactRodux = require(ReplicatedStorage.Packages.RoactRodux)
local Flipper = require(ReplicatedStorage.Packages.Flipper)
local Maid = require(ReplicatedStorage.Packages.Maid)
local Promise = require(ReplicatedStorage.Packages.Promise)

local WeaponConfigurations = ReplicatedStorage.Shared.WeaponConfigurations
local RadialImage = require(ReplicatedStorage.Shared.Components.RadialImage)

--// Constants

local SPRING_SPEED = 3
local FIREMODE_COLOURS = {
	["Semi-Automatic"] = Color3.fromRGB(0, 95, 117),
	["Automatic"] = Color3.fromRGB(0, 121, 38),
	["Burst"] = Color3.fromRGB(140, 153, 0),
	["Pump"] = Color3.fromRGB(230, 132, 5),
	["Explosive"] = Color3.fromRGB(182, 0, 3),
	["Melee"] = Color3.fromRGB(107, 98, 185),
}
local EQUIPPED_COLOUR = Color3.fromRGB(0, 95, 117)
local UNEQUIPPED_COLOUR = Color3.fromRGB(44, 44, 44)
local STANDARD_SIZE = 70
local INCREASED_SIZE = 140

local Tool = Roact.Component:extend("Tool")

--// Code

local function GetCameraOffset(fov, targetSize)
	local x, y, z = targetSize.x, targetSize.y, targetSize.Z
	local maxSize = math.sqrt(x ^ 2 + y ^ 2 + z ^ 2)
	local fac = math.tan(math.rad(fov) / 2)
	local depth = 0.5 * maxSize / fac

	return depth + maxSize / 2
end

function Tool:init()
	self.ModelRef = Roact.createRef()
	self.CameraRef = Roact.createRef()
	self.Ammo, self.updateAmmo = Roact.createBinding(0)
	self.MaxAmmo, self.updateMaxAmmo = Roact.createBinding(0)
	self.TextTransparency, self.updateTextTransparency = Roact.createBinding(0)
	self.reloadingProgress, self.updateReloadingProgress = Roact.createBinding(0)
	self.Maid = Maid.new()

	--// Animations
	self.sizeMotor = Flipper.SingleMotor.new(STANDARD_SIZE)
	self.colourMotor = Flipper.GroupMotor.new({ UNEQUIPPED_COLOUR.R, UNEQUIPPED_COLOUR.G, UNEQUIPPED_COLOUR.B })
	self.textMotor = Flipper.SingleMotor.new(0)

	self.size, self.updateSize = Roact.createBinding(self.sizeMotor:getValue())
	self.colour, self.updateColour = Roact.createBinding(self.colourMotor:getValue())

	self.Maid:GiveTask(self.colourMotor:onStep(self.updateColour))
	self.Maid:GiveTask(self.sizeMotor:onStep(self.updateSize))
	self.Maid:GiveTask(self.textMotor:onStep(self.updateTextTransparency))

	self:setState({ DisplayToolTip = false })
end

function Tool:ConfigureTool()
	return Promise.new(function(resolve, reject)
		local PhysicalTool = self.props.PhysicalTool
		if not PhysicalTool then
			return reject("[UIBackpack] no physical tool")
		end

		local Config = PhysicalTool:WaitForChild("Configuration", 5)
		local MainConfiguration = WeaponConfigurations:FindFirstChild(PhysicalTool.Name)

		if MainConfiguration and Config and Config:IsA("Configuration") then
			MainConfiguration = require(MainConfiguration)

			if MainConfiguration.Type == "Gun" or MainConfiguration.Type == "Stun" then
				local function updateFireMode()
					local colour = FIREMODE_COLOURS[Config.CurrentFireMode.Value]
					self.colourMotor:setGoal({
						Flipper.Spring.new(colour.R, { frequency = SPRING_SPEED / 1.05 }),
						Flipper.Spring.new(colour.G, { frequency = SPRING_SPEED / 1.05 }),
						Flipper.Spring.new(colour.B, { frequency = SPRING_SPEED / 1.05 }),
					})
				end

				self.sizeMotor:setGoal(Flipper.Spring.new(INCREASED_SIZE, { frequency = SPRING_SPEED }))
				updateFireMode()

				self.updateAmmo(Config.CurrentAmmo.Value)
				self.updateMaxAmmo(Config.AmmoRemaining.Value)
				self.Maid:GiveTask(Config.CurrentAmmo.Changed:Connect(self.updateAmmo))
				self.Maid:GiveTask(Config.AmmoRemaining.Changed:Connect(self.updateMaxAmmo))
				self.Maid:GiveTask(Config.CurrentFireMode.Changed:Connect(updateFireMode))

				self.Maid:GiveTask(Config.Reloading.Changed:Connect(function()
					local Reloading = not (Config.Reloading.Value < 1e-15) -- epsilon due to floating point errors
					self.updateReloadingProgress(Config.Reloading.Value)
					if Reloading then
						self.textMotor:setGoal(Flipper.Spring.new(1, { frequency = SPRING_SPEED }))
					else
						self.textMotor:setGoal(Flipper.Spring.new(0, { frequency = SPRING_SPEED }))
					end
				end))
			elseif MainConfiguration.Type == "Melee" then
				local colour = FIREMODE_COLOURS["Melee"]
				self.colourMotor:setGoal({
					Flipper.Spring.new(colour.R, { frequency = SPRING_SPEED / 1.05 }),
					Flipper.Spring.new(colour.G, { frequency = SPRING_SPEED / 1.05 }),
					Flipper.Spring.new(colour.B, { frequency = SPRING_SPEED / 1.05 }),
				})
			else
				return reject("[UIBackpack] unknown weapon type: ", MainConfiguration.Type)
			end
		else
			self.colourMotor:setGoal({
				Flipper.Spring.new(EQUIPPED_COLOUR.R, { frequency = SPRING_SPEED / 1.5 }),
				Flipper.Spring.new(EQUIPPED_COLOUR.G, { frequency = SPRING_SPEED / 1.5 }),
				Flipper.Spring.new(EQUIPPED_COLOUR.B, { frequency = SPRING_SPEED / 1.5 }),
			})
		end

		resolve()
	end)
end

function Tool:CreateViewport()
	local VPModel = self.ModelRef:getValue()
	VPModel:ClearAllChildren()

	local NewTool = self.props.PhysicalTool:Clone()
	NewTool.Parent = VPModel

	self.Maid:GiveTask(function()
		NewTool:Destroy()
	end)

	--// Creates Part, size and position of model
	local BBPart = Instance.new("Part")
	BBPart.Size = VPModel:GetExtentsSize()
	BBPart.CFrame = VPModel:GetBoundingBox()
	BBPart.Transparency = 1
	BBPart.Anchored = true
	BBPart.Parent = VPModel
	VPModel.PrimaryPart = BBPart

	self.Maid:GiveTask(function()
		BBPart:Destroy()
	end)

	--// Rotates model 30 degrees
	VPModel:SetPrimaryPartCFrame(CFrame.new(0, 0, 0))
	VPModel:SetPrimaryPartCFrame(BBPart.CFrame * CFrame.Angles(math.rad(30), 0, 0))

	--// Makes camera look at tool
	local Camera = self.CameraRef:getValue()
	Camera.CFrame = CFrame.new(
		BBPart.Position - BBPart.CFrame.rightVector * GetCameraOffset(170, VPModel:GetExtentsSize()),
		BBPart.Position
	)

	return
end

function Tool:didMount()
	self:CreateViewport()
end

function Tool:willUnmount()
	self.Maid:DoCleaning()
end

function Tool:didUpdate(prevProps)
	if self.props.LayoutOrder ~= self.props.Selected then
		self.colourMotor:setGoal({
			Flipper.Spring.new(UNEQUIPPED_COLOUR.R, { frequency = SPRING_SPEED / 1.5 }),
			Flipper.Spring.new(UNEQUIPPED_COLOUR.G, { frequency = SPRING_SPEED / 1.5 }),
			Flipper.Spring.new(UNEQUIPPED_COLOUR.B, { frequency = SPRING_SPEED / 1.5 }),
		})

		self.sizeMotor:setGoal(Flipper.Spring.new(STANDARD_SIZE, { frequency = SPRING_SPEED }))
		self.updateReloadingProgress(0)
	elseif self.props.LayoutOrder == self.props.Selected then
		self:ConfigureTool():catch(warn)
	end

	if self.props.PhysicalTool ~= prevProps.PhysicalTool then
		self:CreateViewport()
	end
end

function Tool:render()
	return Roact.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = self.size:map(function(value)
			return UDim2.fromOffset(value, 92)
		end),
		LayoutOrder = self.props.LayoutOrder,
		[Roact.Event.MouseEnter] = function()
			self:setState({ DisplayToolTip = true })
		end,
		[Roact.Event.MouseLeave] = function()
			self:setState({ DisplayToolTip = false })
		end,
	}, {
		ToolHold = Roact.createElement("ImageButton", {
			BackgroundTransparency = 1,
			Image = "rbxassetid://2790382281",
			ImageColor3 = self.colour:map(function(value)
				return Color3.new(value[1], value[2], value[3])
			end),
			ImageTransparency = 0.5,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(4, 4, 252, 252),
			SliceScale = 1,
			[Roact.Event.Activated] = function()
				self.props.ToolSelect(self.props.LayoutOrder)
			end,
			ClipsDescendants = true,
			Size = UDim2.new(1, 0, 0, 70),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
		}, {
			ToolNumber = Roact.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(5, 0),
				Size = UDim2.fromOffset(20, 20),
				Font = Enum.Font.GothamSemibold,
				Text = self.props.LayoutOrder,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 20,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 3,
			}),
			ViewportFame = Roact.createElement("ViewportFrame", {
				Size = UDim2.new(0, 70, 1, 0),
				BackgroundTransparency = 1,
				BackgroundColor3 = Color3.fromRGB(95, 95, 95),
				CurrentCamera = self.CameraRef,
			}, {
				Camera = Roact.createElement("Camera", {
					[Roact.Ref] = self.CameraRef,
				}),
				Model = Roact.createElement("Model", {
					[Roact.Ref] = self.ModelRef,
				}),
			}),
			Ammo = Roact.createElement("TextLabel", {
				Size = UDim2.new(0, 65, 0.5, 0),
				Position = UDim2.fromOffset(72.5, 0),
				Font = Enum.Font.GothamSemibold,
				TextTransparency = self.TextTransparency,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 24,
				Text = self.Ammo,
				BackgroundTransparency = 1,
			}),
			MaxAmmo = Roact.createElement("TextLabel", {
				Size = UDim2.new(0, 65, 0.5, 0),
				Position = UDim2.new(0, 72.5, 0.5, 0),
				Font = Enum.Font.GothamSemibold,
				TextTransparency = self.TextTransparency,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 24,
				Text = self.MaxAmmo,
				BackgroundTransparency = 1,
			}),
			AmmoBorder = Roact.createElement("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 77, 0.5, 0),
				BackgroundTransparency = self.TextTransparency,
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(55, 2),
			}),
			Radial = Roact.createElement(RadialImage, {
				progress = self.reloadingProgress,

				imageProps = {
					BackgroundTransparency = 1,
					Size = UDim2.new(0, 50, 0, 50),
					Position = UDim2.new(1, -10, 0, 10),
					AnchorPoint = Vector2.new(1, 0),
				},
			}),
		}),
		ToolTip = Roact.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			Image = "rbxassetid://2790382281",
			ImageColor3 = Color3.fromRGB(44, 44, 44),
			ImageTransparency = 0.5,
			LayoutOrder = self.props.LayoutOrder,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(4, 4, 252, 252),
			SliceScale = 1,
			ClipsDescendants = true,
			Size = UDim2.new(
				0,
				TextService:GetTextSize(
					self.props.PhysicalTool.Name,
					16,
					Enum.Font.SourceSansBold,
					Vector2.new(100000, 100000)
				).X + 10,
				0,
				20
			),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Visible = self.state.DisplayToolTip,
		}, {
			Text = Roact.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				TextSize = 16,
				Text = self.props.PhysicalTool.Name,
				TextColor3 = Color3.new(1, 1, 1),
				Size = UDim2.fromScale(1, 1),
			}),
		}),
	})
end

return RoactRodux.connect(function(state, _props)
	return {
		Selected = state.Selected,
		SelectedNum = state.SelectedNum,
	}
end, function(dispatch)
	return {
		ToolSelect = function(props)
			return dispatch({ type = "ChangeSelected", value = props })
		end,
	}
end)(Tool)
