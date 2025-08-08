--[[
	we don't do anything here, but supply a target
	state (entry point) to your game, this can
	either be in the conf.json as:
		
		"enter": "opening"

	or a function that returns the target state

		function hen.begin(arg, unfilteredArg)
			return "opening". "state"
		end

	which just return the target state to enter
]]

-- require Heartful engine
require '❤️'
