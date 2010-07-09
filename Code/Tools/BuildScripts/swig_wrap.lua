------------------------------------------------------------------------------
-- Copyright (C) 2008-2010, Shane J. M. Liesegang
-- All rights reserved.
-- 
-- Redistribution and use in source and binary forms, with or without 
-- modification, are permitted provided that the following conditions are met:
-- 
--     * Redistributions of source code must retain the above copyright 
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright 
--       notice, this list of conditions and the following disclaimer in the 
--       documentation and/or other materials provided with the distribution.
--     * Neither the name of the copyright holder nor the names of any 
--       contributors may be used to endorse or promote products derived from 
--       this software without specific prior written permission.
-- 
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
-- ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
-- POSSIBILITY OF SUCH DAMAGE.
------------------------------------------------------------------------------

if (package.path == nil) then
  package.path = ""
end
local mydir = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]]
if (mydir == nil) then
  mydir = "."
end
package.path = mydir .. "?.lua;" .. package.path
package.path = package.path .. ";" .. mydir .. "lua-lib/penlight-0.8/lua/?/init.lua"
package.path = package.path .. ";" .. mydir .. "lua-lib/penlight-0.8/lua/?.lua"

require "angel_build"
require "lfs"
require "pl.path"
require "pl.lapp"

local args = pl.lapp [[
  Checks the included files in the aggregate scripting interface and touches it if any of them are newer than the generated wrapper.
    -p,--project_directory (string)  Project directory
    -D,--define (default SWIGLUA) An optional string to define when invoking swig 
    -f,--force_regeneration Whether or not to just force a reneration of the wrappings.
  ]]

-- add the quotes if we'll need them later
if (args.project_directory:find(' ')) then
  args.project_directory = '"' .. args.project_directory .. '"'
end

local INTERFACE_DIRECTORY = fulljoin(args.project_directory, "Angel", "Scripting", "Interfaces")
local MASTER_FILE = "angel.i"
local WRAPPER_FILE = ""
if (args.define == "INTROGAME") then
  WRAPPER_FILE = "AngelLuaWrappingIntroGame.cpp"
else
  WRAPPER_FILE = "AngelLuaWrapping.cpp"
end
local AGGREGATE_INTERFACE = fulljoin(INTERFACE_DIRECTORY, MASTER_FILE)
local WRAPPER_SOURCE = fulljoin(INTERFACE_DIRECTORY, WRAPPER_FILE)

local SWIG_PATH = get_swig_path()
local SWIG_OPTIONS = ""
if (args.define ~= nil and args.define ~= "SWIGLUA") then
  SWIG_OPTIONS = SWIG_OPTIONS .. " -D" .. args.define
end
local SWIG_OPTIONS = SWIG_OPTIONS .. " -c++ -lua -Werror -I" .. INTERFACE_DIRECTORY .. " -o " .. WRAPPER_SOURCE .. " " .. AGGREGATE_INTERFACE

lfs.chdir(fulljoin(args.project_directory, "Tools", "BuildScripts"))

if (not pl.path.exists(AGGREGATE_INTERFACE:gsub('"', ''))) then
  io.stderr:write("ERROR: Couldn't find " .. AGGREGATE_INTERFACE .. ".\n")
  os.exit(1)
end

if (args.define ~= nil and args.define ~= "SWIGLUA") then
  generate_typemaps(INTERFACE_DIRECTORY, args.define)
else
  generate_typemaps(INTERFACE_DIRECTORY)
end

local should_regenerate = false

local interface_file = io.open(AGGREGATE_INTERFACE:gsub('"', ''), 'r')

local files = {}
for line in interface_file:lines() do
  local include_pattern = "^%%include (.+%.i)"
  local _, _, f = line:find(include_pattern)
  if (f ~= nil) then
    table.insert(files, f)
  end
end
interface_file:close()

if (pl.path.exists(WRAPPER_SOURCE) and not args.force_regeneration) then
  local wrapper_modification = lfs.attributes(WRAPPER_SOURCE, "modification")
  local update = false
  for _, f in pairs(files) do
    -- oh, hardcoded nonsense, how i love you
    if     (args.define == "INTROGAME" and f == "inheritance.i") then
      -- print("Skipping " .. f)
    elseif (args.define ~= "INTROGAME" and f == "inheritance_intro.i") then
      -- print("Skipping " .. f)
    else
      if (pl.path.exists(fulljoin(INTERFACE_DIRECTORY, f))) then
        if (wrapper_modification < lfs.attributes(fulljoin(INTERFACE_DIRECTORY, f), "modification")) then
          update = true
          print("At least " .. f .. " was newer than " .. WRAPPER_FILE .. " -- touching " .. MASTER_FILE .. " and regenerating " .. WRAPPER_FILE)
          lfs.touch(AGGREGATE_INTERFACE)
          os.remove(WRAPPER_SOURCE)
          break
        end
      else
        -- could be a system file, could just be missing; not our problem either way
      end
    end
  end

  if (not update) then
    print("Interface files are up to date.")
  else
    should_regenerate = true
  end
  
else
  if (args.force_regeneration) then
    print("Forcing regeneration of " .. WRAPPER_FILE)
  else
    print("No existing wrapper file; generating " .. WRAPPER_FILE)
  end
  should_regenerate = true
end

if (should_regenerate) then
  local difftime = 0
  if (pl.path.exists(WRAPPER_SOURCE)) then
    difftime = lfs.attributes(WRAPPER_SOURCE, "modification") - os.time()
  end
  os.execute(SWIG_PATH .. SWIG_OPTIONS)
  if(difftime < -61 or difftime > 0) then
    lfs.touch(WRAPPER_SOURCE, os.time() + 61)
  end
end

