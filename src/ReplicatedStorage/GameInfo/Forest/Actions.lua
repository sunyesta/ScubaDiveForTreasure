return {
	ActionID = {
		Outcomes = {
			Success = function() end,
			Failure = function() end,
			HugeFailure = function() end,
		},
		Shuffles = {
			Success = 2,
			Failure = 1,
			HugeFailure = 1,
		},
	},
}
