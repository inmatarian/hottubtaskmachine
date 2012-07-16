
Hot Tub Task Machine
Thread Pool library for LÖVE

In order to simplify performing multithreaded tasks, this library covers a set
of basic use cases that should help overcome some common challenges. The
primary goal for this library is to launch "Fire and Forget" tasks that run in
another thread, so that the main thread running the game doesn't stall or block
while waiting for that task to finish.

Things you can use the Hot Tub for:
 * Loading large files or images
 * Uncompressing large blocks of data
 * Saving large files
 * Downloading a file
 * Uploading a score
 * Calculating something big

Things you shouldn't use the Hot Tub for:
 * Connecting to a server for online games
 * Downloading things that need a progress bar
 * Anything that would probably take longer than a few seconds
 * Calculating things where a simpler algorithm exists

Using This Library:

1. local HotTub = require 'hottub'

  Require the library as you would most Lua libraries. Place it somewhere
  useful in your source tree. For instance, if you put it in the folder
  lib/3rdparty/hottub/hottub.lua, then modify the line to this:
  local HotTub = require 'lib.3rdparty.hottub.hottub'

2. HotTub.init( threads )

  Call this function to initialize the HotTub. Only do it once, and the best
  spot to do it in love.load. By default it starts two threads, but you can
  specify a different number. Keep in mind that adding more threads doesn't
  always means more tasks can be run, as the number of cpus and cores restricts
  how many threads work at the same time. By adding too many threads and too
  many tasks, your game may actually run slower.

3. HotTub.addTask( filename, callback, parameters... )

  Add tasks with this function. Tasks are lua scripts also that are in seperate
  files, which have the parameters list passed in as the ... argument, and can
  return any number of arguments. Callbacks are functions that you can pass in
  that will be called when the task is completed.

  Note: Love restricts datatype that pass through to other threads as numbers,
  strings, booleans, or userdata. To pass simple tables, you'll need a
  serialization library.

4. HotTub.update(dt)

  Call this periodically (such as in love.update) to allow the HotTub to
  monitor threads and begin waiting tasks.

  dt isn't used at this time, but it's being reserved for future compatibility.

5. HotTub.exit( blocking )

  This can be called after all tasks have finished and for some reason you also
  want to shutdown the threads to. For most people, it's probably not necessary
  to call this function. The blocking parameter means that it'll wait for the
  threads to shut down before returning, which will stall the game. It returns
  false if there are existing tasks, and true when all threads have been
  signaled to shutdown.

  At this time, there's no way to terminate a thread that's still busy
  performing tasks.

6. Error Handling

  Errors are handled with lua's error function. This is to catch syntax errors
  or other type errors. For passing non-fatal errors back to your callback,
  you should consider using booleans or strings.

Example usage:

  local HotTub = require 'hottub'
  local text = "Waiting..."

  function love.load()
    HotTub.init()
    HotTub.addTask("fib.lua", function(result) text=result end, 37)
  end

  function love.update(dt)
    HotTub.update(dt)
  end

  function love.draw()
    love.graphics.print( text, 8, 8 )
  end


In the demo files provided, the Hot Tub calculates a large fibonacci value
using an unoptimized algorithm. This was only for demonstration, and that code
shouldn't be considered part of the library.


License:

Copyright (c) 2012, Inmatarian <inmatarian@gmail.com>

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

