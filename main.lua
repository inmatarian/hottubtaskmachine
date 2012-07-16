
local HotTub = require 'hottub'

local display_text = "Waiting for fib(37)..."
local waiting = true
local spinner_text = '/'
local spinmap = { '/', '-', '\\', '|' }
local clock = 0

function love.load()
  HotTub.init()
  HotTub.addTask("fib.lua", function(result)
    waiting = false
    display_text = string.format("Results: %i", result)
  end, 37)
end

function love.update(dt)
  HotTub.update(dt)
  clock = clock + dt
  local spinx = math.floor(clock*12)%4
  spinner_text = spinmap[1+spinx]
end

function love.draw()
  love.graphics.print( display_text, 8, 8 )
  if waiting then
    love.graphics.print( spinner_text, 8, 24 )
  end
end

