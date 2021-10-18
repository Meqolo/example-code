local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rodux = require(ReplicatedStorage.Packages.Rodux)
local Llama = require(ReplicatedStorage.Packages.Llama)

local InitState = {
	Selected = nil,
	Visible = true,
	SelectedNum = 0,
	NumTools = 0,
	Tools = {},
}

function SelectTool(State, NewSelected)
	if NewSelected == State.Selected then
		State.Selected = nil
	else
		State.Selected = NewSelected
	end

	return State
end

return Rodux.createReducer(InitState, {
	SetTools = function(state, action)
		local NewState = Llama.Dictionary.copy(state)
		NewState.Tools = action.value
		return NewState
	end,

	ChangeSelected = function(state, action)
		if not state.Tools[tonumber(action.value)] then
			return state
		end

		local NewState = Llama.Dictionary.copy(state)
		return SelectTool(NewState, tonumber(action.value))
	end,

	ControllerChangeSelected = function(state, action)
		local NewState = Llama.Dictionary.copy(state)
		NewState.SelectedNum += action.value

		if NewState.SelectedNum < 1 then
			NewState.SelectedNum = #NewState.Tools
		elseif NewState.SelectedNum > #NewState.Tools then
			NewState.SelectedNum = 1
		end

		return SelectTool(NewState, NewState.SelectedNum)
	end,

	SetNumberOfTools = function(state, action)
		local NewState = Llama.Dictionary.copy(state)
		NewState.NumTools = action.value
		return NewState
	end,

	UnequipTool = function(state)
		local NewState = Llama.Dictionary.copy(state)
		NewState.Selected = nil
		return NewState
	end,

	SetVisibility = function(state, action)
		local NewState = Llama.Dictionary.copy(state)
		NewState.Visible = action.value
		return NewState
	end,
})
