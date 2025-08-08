-- always configure the state key settings properly
local state = require '❤️.state' ('Opening', 'functional')

-- function called when the state is entered
function state:enter(hen, args)
end

-- function called when the state is exited
function state:exit(hen)
end

return state
