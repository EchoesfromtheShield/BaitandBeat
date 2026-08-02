-- Bait & Beat
-- Matron/Maiden-compatible repository entrypoint.
-- The maintained script source remains under norns/bait_and_beat.

local project_root = _path.code .. "BaitandBeat/"
local original_include = include

include = function(path)
  if path:match("^bait_and_beat/") then
    return original_include("BaitandBeat/norns/" .. path)
  end
  return original_include(path)
end

local ok, err = pcall(dofile, project_root .. "norns/bait_and_beat/bait_and_beat.lua")
include = original_include

if not ok then
  error(err)
end
