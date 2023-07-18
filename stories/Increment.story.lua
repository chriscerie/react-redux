--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local ReactRedux = require(ReplicatedStorage.Packages.ReactRedux)
local Redux = require(ReplicatedStorage.Packages.Redux)

local e = React.createElement

type State = number

local store = Redux.Store.new(Redux.createReducer(0, {
	INCREMENT = function(state, _action)
		return state + 1
	end,
} :: {
	[string]: (State, { [string]: any }) -> State,
}))

local function Child()
	local count = ReactRedux.useSelector(function(state: State)
		return state
	end)

	return e("TextLabel", {
		Text = `Count: {count} (should be same)`,
		Position = UDim2.fromScale(0.5, 0.6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	})
end

local Component: React.FC<{}> = function(_props)
	local dispatch = ReactRedux.useDispatch()
	local count = ReactRedux.useSelector(function(state: State)
		return state
	end)

	return e("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.4, 0.4),
		Position = UDim2.fromScale(0.5, 0.5),
		Text = `Count: {count}, increment by 100`,
		[React.Event.Activated] = function()
			task.defer(function()
				for _ = 1, 100 do
					dispatch({
						type = "INCREMENT",
					})
				end
			end)
		end,
	}, {
		Child = e(Child),
	})
end

return function(target)
	local root = ReactRoblox.createRoot(target)
	root:render(e(ReactRedux.Provider, {
		store = store :: {},
	}, {
		App = e(Component),
	}))

	return function()
		root:unmount()
	end
end
