-- always configure the state key settings properly, using a state initializer
local state = require '❤️.state'('Heartful', 'functional')

-- function called when the state is entered
function state:enter(hen, args)
	self.next = args.entry
	self.nextargs = args
	self.lifetime = 5
end

-- function called when the state is exited
function state:exit(hen)
	hen:enter(self.next[1], self.next[2]. self.nextargs)
end

return state