Paintjob = Paintjob or {}

if Paintjob.__legacyClientBoot then
    return
end

Paintjob.__legacyClientBoot = true

local resource = GetCurrentResourceName()
local files = {
    'client/utils.lua',
    'client/effects.lua',
    'client/paint.lua',
    'client/ui.lua',
}

for _, path in ipairs(files) do
    local chunk = LoadResourceFile(resource, path)
    assert(chunk, ('mri_Qpaintjob: could not load %s'):format(path))
    assert(load(chunk, ('@@%s/%s'):format(resource, path)))()
end
