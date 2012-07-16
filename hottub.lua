-- HotTubThreadMachine
-- Thread Pool implementation for LoVE
--
--------------------------------------------------------------------------------
-- Example usage:
--
--   local HotTub = require 'hottub'
--
--   function love.load()
--     HotTub.init()
--     HotTub.addTask('fib.lua', function(result)
--       print(result)
--     end, 39)
--   end
--
--   function love.update(dt)
--     HotTub.update()
--   end
--
--------------------------------------------------------------------------------
-- Copyright (c) 2012, Inmatarian <inmatarian@gmail.com>
--
-- Permission to use, copy, modify, and/or distribute this software for any
-- purpose with or without fee is hereby granted, provided that the above
-- copyright notice and this permission notice appear in all copies.

-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
-- WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
-- MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
-- SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
-- WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
-- OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
-- CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
--------------------------------------------------------------------------------

local MAX_THREADS = 2

local ready_pool = {}
local busy_list = {}
local task_queue = {}
local task_map = {}
local finished_tasks = {}

local NULLFUNC = function() end
local debuglog = print

local ACCEPTABLE_PARAMS = { boolean=true, string=true, number=true, userdata=true }

-- Worker code stored in string to keep the module self-contained
local worker_lua = [=[
  require 'love.filesystem'
  local ACCEPTABLE_PARAMS = { boolean=true, string=true, number=true, userdata=true }
  local self_thread = love.thread.getThread()
  while true do
    local control = self_thread:demand("control")
    if control == "work" then
      local taskID = self_thread:demand("taskID")
      local filename = self_thread:demand("filename")
      local argc = self_thread:demand("argc")
      local args = {}
      for i = 1, argc do
        args[i] = self_thread:demand(string.format("args_%i", i))
      end
      local ok, chunk = pcall(love.filesystem.load, filename)
      if not ok then
        error("error encountered in task: "..filename.."\n"..tostring(chunk))
      else
        local result = { pcall(chunk, unpack(args)) }
        if result[1]==false then
          error("error encountered in task: "..filename.."\n"..tostring(result[2]))
        else
          table.remove(result, 1)
          self_thread:set("results_taskID", taskID)
          self_thread:set("results_argc", #result)
          for i = 1, #result do
            assert(ACCEPTABLE_PARAMS[type(result[i])],
                "return type must be boolean, string, number or userdata")
            self_thread:set(string.format("results_args_%i", i), result[i])
          end
          self_thread:set("response", "finished")
        end
      end
    elseif control == "quit" then
      break
    end
  end
]=]

-- gives a unique task id, since callbacks can't be passed around
-- and need to be stored in task_map
local nextTaskId
do
  local id = 0
  nextTaskId = function()
    id = id + 1
    return string.format('task_%i', id)
  end
end

-- Checks thread results and fires callbacks
-- safe to use thread:demand because "response" message is set
-- after all results are stored.
-- Callbacks are fired after all threads have been serviced so
-- that new tasks can be registered safely.
local function checkResults()
  local i = #busy_list
  while i > 0 do
    local thread = busy_list[i]
    local exception = thread:get("error")
    if exception then error(exception) end
    local response = thread:get("response")
    if response == "finished" then
      local taskID = thread:demand("results_taskID")
      local task = task_map[taskID]
      task_map[taskID] = nil
      task.results = {}
      local argc = thread:demand("results_argc")
      for i = 1, argc do
        task.results[i] = thread:demand(string.format("results_args_%i", i))
      end
      debuglog("task finished", taskID, task.filename)
      table.insert(finished_tasks, task)
      table.remove(busy_list, i)
      table.insert(ready_pool, 1, thread)
    end
    i = i - 1
  end

  local N = #finished_tasks
  for i = 1, N do
    local task = finished_tasks[i]
    debuglog("calling back", task.id, task.filename)
    task.callback(unpack(task.results))
    finished_tasks[i] = nil
  end
end

-- Loads new tasks into ready threads
-- sets all of the values before setting control message, so
-- the other thread doesn't actually start until then. Minor
-- inefficiency, but allows for errors to be caught sooner
-- rather than later.
local function checkTasks(dt)
  while #task_queue > 0 do
    if #ready_pool < 1 then break end

    local task = table.remove(task_queue)
    local thread = table.remove(ready_pool)

    debuglog("starting task", task.id, task.filename, thread:getName())
    thread:set("taskID", task.id)
    thread:set("filename", task.filename)
    thread:set("argc", task.argc)
    for i = 1, task.argc do
      thread:set(string.format("args_%i", i), task.args[i])
    end
    thread:set("control", "work")

    table.insert(busy_list, thread)
  end
end

--------------------------------------------------------------------------------

local HotTub = {}

--- Initializes threads and gets them ready to perform work
-- Must call before using addTask, exit, or update
--
-- @param threads number of worker threads to spawn (default: 2)
function HotTub.init(threads, debugging)
  if not debugging then debuglog = NULLFUNC end
  assert(loadstring(worker_lua))
  threads = threads or MAX_THREADS
  local worker_lua_data = love.filesystem.newFileData(worker_lua, "worker_lua", "file")

  for i = 1, threads do
    local name = string.format("hottub_worker_%i", i)
    local thread = love.thread.newThread(name, worker_lua_data)
    thread:start()
    ready_pool[1+threads-i] = thread
  end
end

--- Call to shutdown all threads
-- Note: All tasks must be finished (can't kill threads)
--
-- @param blocking set to true to make sure threads actually quit (will block)
-- @return true when all threads have been shutdown
-- @return false if busy threads or waiting tasks
function HotTub.exit(blocking)
  if (#busy_list > 0) or (#task_queue > 0) then return false end
  for _, thread in pairs(ready_pool) do
    thread:set("control", "quit")
  end
  if blocking then
    for _, thread in pairs(ready_pool) do
      thread:wait()
    end
  end
  for i = 1, #ready_pool do
    ready_pool[i] = nil
  end
  return true
end

--- Checks for Results and starts work on tasks
-- Call update periodically so new tasks will be started, and
-- finished tasks will make callbacks.
--
-- @param dt deltatime supplied by love.update (currently unused)
function HotTub.update(dt)
  checkResults()
  checkTasks()
end

--- Add a new task to the queue.
-- As worker threads have finished old tasks and are ready, new tasks will be
-- executed in the order they are received.
--
-- @param filename a lua script that will be run in other threads
-- @param callback function called when task is finished (optional)
-- @param ... vararg parameters sent to task (optional, must be valid types)
function HotTub.addTask(filename, callback, ...)
  assert(type(filename)=="string", "Filename required for task!")
  assert(love.filesystem.isFile(filename), "File required for task!")
  for i = 1, select('#', ...) do
    assert(ACCEPTABLE_PARAMS[type(select(i, ...))],
        "params must be boolean, string, number or userdata")
  end
  local task = {
    id = nextTaskId(),
    filename = filename,
    callback = callback or NULLFUNC,
    argc = select('#', ...),
    args = {...}
  }
  task_map[task.id] = task
  table.insert(task_queue, 1, task)
  debuglog("added task", task.id, task.filename)
  checkTasks()
end

return HotTub

