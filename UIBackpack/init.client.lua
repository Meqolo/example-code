local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")

local Roact = require(ReplicatedStorage.Packages.Roact)
local Rodux = require(ReplicatedStorage.Packages.Rodux)
local RoactRodux = require(ReplicatedStorage.Packages.RoactRodux)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ToolHolder = require(script.ToolHolder)

local NUMBER_TO_KEY = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}

local Player = Players.LocalPlayer
local RoduxStore = Rodux.Store.new(require(script.Reducers))
local BackpackRemote = Remotes:GetEvent("Backpack")

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

local App = Roact.createElement(RoactRodux.StoreProvider, {
	store = RoduxStore,
}, {
	Main = Roact.createElement("ScreenGui", {}, {
		Holder = Roact.createElement(ToolHolder),
	}),
})

function InputHandler(_, InputState, InputObject)
	if InputState ~= Enum.UserInputState.Begin then
		return
	end

	local Key = NUMBER_TO_KEY[InputObject.KeyCode]
	if not RoduxStore:getState().Tools[Key] then
		return Enum.ContextActionResult.Pass
	end

	RoduxStore:dispatch({ type = "ChangeSelected", value = Key })
end

function BindKeys()
	ContextActionService:BindAction(
		"ToolSelect",
		InputHandler,
		false,
		Enum.KeyCode.One,
		Enum.KeyCode.Two,
		Enum.KeyCode.Three,
		Enum.KeyCode.Four,
		Enum.KeyCode.Five,
		Enum.KeyCode.Six,
		Enum.KeyCode.Seven,
		Enum.KeyCode.Eight,
		Enum.KeyCode.Nine
	)
end

Player.CharacterAdded:Connect(function(Character)
	if not Player:WaitForChild("PlayerGui"):FindFirstChild("UIBackpack") then
		Roact.mount(App, Player:WaitForChild("PlayerGui"), "UIBackpack")
		BindKeys()
	end

	local Humanoid = Character:WaitForChild("Humanoid", 5)
	if not Humanoid then
		return
	end

	Humanoid.Died:Connect(function()
		Humanoid:UnequipTools()
		RoduxStore:dispatch({ type = "UnequipTool" })
	end)
end)

Player.CharacterRemoving:Connect(function()
	ContextActionService:UnbindAction("ToolSelect")
end)

RoduxStore.changed:connect(function(newState, oldState)
	if oldState.Selected ~= newState.Selected then
		if Player.Character.Humanoid then
			Player.Character.Humanoid:UnequipTools()
			if newState.Selected then
				Player.Character.Humanoid:EquipTool(newState.Tools[newState.Selected])
			end
		end
	end
end)

BackpackRemote.OnClientEvent:Connect(function(Visible)
	if Visible then
		BindKeys()
	else
		ContextActionService:UnbindAction("ToolSelect")
		RoduxStore:dispatch({ type = "UnequipTool" })
	end

	RoduxStore:dispatch({ type = "SetVisibility", value = Visible })
end)
