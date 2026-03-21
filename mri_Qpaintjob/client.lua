Paintjob = Paintjob or {}

local resource = GetCurrentResourceName()
local path = 'client/main.lua'
local chunk = LoadResourceFile(resource, path)

assert(chunk, ('mri_Qpaintjob: could not load %s'):format(path))
assert(load(chunk, ('@@%s/%s'):format(resource, path)))()
