--
-- THIS CODE IS ONLY FOR DEMONSTRATION PURPOSES
-- PLEASE DO NOT USE THIS CODE
--
-- SERIOUSLY, 1ST YEAR COMP.SCI. STUFF HERE.
-- BETTER VERSIONS EXIST, USE THEM.
-- 

local PARAM = select(1, ...) or 0

local function fib(x)
  if x < 2 then return x end
  return fib(x-2) + fib(x-1)
end

return fib(PARAM)

