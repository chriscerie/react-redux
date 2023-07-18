local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local ReactRedux = require(ReplicatedStorage.Packages.ReactRedux)
local Redux = require(ReplicatedStorage.Packages.Redux)

local e = React.createElement
local act = function(fn)
	ReactRoblox.act(function()
		fn()

		-- This won't work without this for upstream rtl.act cases
		task.wait()
		task.wait()
	end)
end

return function()
	describe("useSelector", function()
		type NormalStateType = {
			count: number,
		}
		local normalStore: typeof(Redux.Store.new())
		local renderedItems: { any } = {}
		local useNormalSelector = ReactRedux.useSelector

		local container: Folder
		local root: ReactRoblox.RootType

		beforeEach(function()
			normalStore = Redux.Store.new(function(state: NormalStateType)
				state = state or { count = -1 }
				return {
					count = state.count + 1,
				}
			end)
			renderedItems = {}

			container = Instance.new("Folder")
			root = ReactRoblox.createRoot(container)
		end)

		describe("core subscription behavior", function()
			it("selects the state on initial render", function()
				local result: number?
				local Comp = function()
					local count = useNormalSelector(function(state: NormalStateType)
						return state.count
					end)

					React.useLayoutEffect(function()
						result = count
					end, {})

					return e("TextLabel", {
						Text = count,
					})
				end

				act(function()
					root:render(e(ReactRedux.Provider, {
						store = normalStore,
					}, {
						Comp = e(Comp),
					}))
				end)

				expect(result).to.equal(0)
			end)

			it("selects the state and renders the component when the store updates", function()
				local selectorToHaveBeenCalledTimes = 0
				local selector = function(state: NormalStateType)
					selectorToHaveBeenCalledTimes += 1
					return state.count
				end
				local result: number?

				local Comp = function()
					local count = useNormalSelector(selector)

					result = count

					React.useLayoutEffect(function()
						result = count
					end)

					return
				end

				act(function()
					root:render(e(ReactRedux.Provider, {
						store = normalStore,
					}, {
						Comp = e(Comp),
					}))
				end)

				expect(result).to.equal(0)
				expect(selectorToHaveBeenCalledTimes).to.equal(1)

				act(function()
					normalStore:dispatch({
						type = "",
					})
				end)

				expect(result).to.equal(1)
				expect(selectorToHaveBeenCalledTimes).to.equal(2)
			end)
		end)

		describe("lifecycle interactions", function()
			it("always uses the latest state", function()
				local store = Redux.Store.new(function(c: number)
					c = c or 1
					return c + 1
				end, -1)

				local Comp = function()
					local selector = React.useCallback(function(c: number)
						return c + 1
					end, {})

					local value = ReactRedux.useSelector(selector)
					table.insert(renderedItems, value)

					return
				end

				act(function()
					root:render(e(ReactRedux.Provider, {
						store = store,
					}, {
						Comp = e(Comp),
					}))
				end)

				expect(#renderedItems).to.equal(1)
				expect(renderedItems[1]).to.equal(1)

				act(function()
					store:dispatch({
						type = "",
					})
				end)

				expect(#renderedItems).to.equal(2)
				expect(renderedItems[1]).to.equal(1)
				expect(renderedItems[2]).to.equal(2)
			end)

			it("subscribes to the store synchronously", function()
				local appSubscription

				local Child = function()
					local _count = useNormalSelector(function(s: NormalStateType)
						return s.count
					end)
					return
				end

				local Parent = function()
					local context = React.useContext(ReactRedux.ReactReduxContext)
					appSubscription = context.subscription
					local count = useNormalSelector(function(s: NormalStateType)
						return s.count
					end)
					return if count == 1 then e(Child) else nil
				end

				act(function()
					root:render(e(ReactRedux.Provider, {
						store = normalStore,
					}, {
						Comp = e(Parent),
					}))
				end)

				-- Parent component only
				expect(#appSubscription.getListeners().get()).to.equal(1)

				act(function()
					normalStore:dispatch({
						type = "",
					})
				end)

				-- Parent component + 1 child component
				expect(#appSubscription.getListeners().get()).to.equal(2)
			end)

			it("unsubscribes when the component is unmounted", function()
				local appSubscription

				local Child = function()
					local _count = useNormalSelector(function(s: NormalStateType)
						return s.count
					end)
					return
				end

				local Parent = function()
					local context = React.useContext(ReactRedux.ReactReduxContext)
					appSubscription = context.subscription
					local count = useNormalSelector(function(s: NormalStateType)
						return s.count
					end)
					return if count == 0 then e(Child) else nil
				end

				act(function()
					root:render(e(ReactRedux.Provider, {
						store = normalStore,
					}, {
						Comp = e(Parent),
					}))
				end)

				-- Parent + 1 child component
				expect(#appSubscription.getListeners().get()).to.equal(2)

				act(function()
					normalStore:dispatch({
						type = "",
					})
				end)

				-- Parent component only
				expect(#appSubscription.getListeners().get()).to.equal(1)
			end)

			it("notices store updates between render and store subscription effect", function()
				local Child = function(props: { count: number })
					React.useLayoutEffect(function()
						if props.count == 0 then
							normalStore:dispatch({
								type = "",
							})
						end
					end, { props.count })
					return
				end

				local Comp = function()
					local count = useNormalSelector(function(s)
						return s.count
					end)

					React.useLayoutEffect(function()
						table.insert(renderedItems, count)
					end)

					return e(Child, {
						count = count,
					})
				end

				act(function()
					root:render(e(ReactRedux.Provider, {
						store = normalStore,
					}, {
						Comp = e(Comp),
					}))
				end)

				-- With `useSyncExternalStore`, we get three renders of `<Comp>`:
				-- 1) Initial render, count is 0
				-- 2) Render due to dispatch, still sync in the initial render's commit phase

				-- ROBLOX DEVIATION: With upstream migration to rtl.act, renderedItems went back to [0, 1]
				-- However, we are still on [0, 1, 1]
				-- More info: https://github.com/reduxjs/react-redux/commit/3281250ef28cac7e548e57ecfd15836f130d0bf5
				expect(#renderedItems).to.equal(3)
				expect(renderedItems[1]).to.equal(0)
				expect(renderedItems[2]).to.equal(1)
				expect(renderedItems[2]).to.equal(1)
			end)
		end)
	end)
end
