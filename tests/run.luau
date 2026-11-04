--[[
	Automated tests for Steal the Aura Egg. Run from the repo root:

	    lune run tests/run.luau

	Build the place first (rojo build) - the place tests read StealTheAuraEgg.rbxlx.
	Exits with code 1 if any test fails.
]]

local process = require("@lune/process")
local H = require("./harness")

local specs = {
	require("./specs/config.spec"),
	require("./specs/data.spec"),
	require("./specs/source.spec"),
	require("./specs/place.spec"),
}

for _, spec in specs do
	local ok, err = pcall(spec, H)
	if not ok then
		H.failed += 1
		table.insert(H.failures, "spec crashed: " .. tostring(err))
		print("  CRASH " .. tostring(err))
	end
end

print(string.format("\n%d passed, %d failed", H.passed, H.failed))
if H.failed > 0 then
	process.exit(1)
end
