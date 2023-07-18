_G.__ROACT_17_MOCK_SCHEDULER__ = true

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestEZ = require(ReplicatedStorage.Packages.TestEZ)

print("Starting tests. This may take a moment...")
TestEZ.TestBootstrap:run({ ReplicatedStorage.Packages.ReactRedux })
