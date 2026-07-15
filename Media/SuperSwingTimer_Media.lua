local _, ns = ...

-- ============================================================
-- Super Swing Timer — bundled media registry.
-- Self-contained: no external libs (LibSharedMedia is optional and
-- guarded so a missing LSM never crashes load). All paths resolve to
-- this addon's own Media/ folder.
-- ============================================================

ns.Media = ns.Media or {}

-- Statusbar fill textures (valid 256x32 fills copied from MerfinPlus
-- and rehomed under our own addon path).
ns.Media.statusbar = {
    MerfinMain     = [[Interface\AddOns\SuperSwingTimer\Media\statusbar\MerfinMain.tga]],
    MerfinMainDark = [[Interface\AddOns\SuperSwingTimer\Media\statusbar\MerfinMainDark.tga]],
    MerfinFlatt    = [[Interface\AddOns\SuperSwingTimer\Media\statusbar\MerfinFlatt.tga]],
    MerfinTexture  = [[Interface\AddOns\SuperSwingTimer\Media\statusbar\MerfinTexture.blp]],
    Flatt          = [[Interface\AddOns\SuperSwingTimer\Media\statusbar\Flatt.blp]],
}

-- Register into LibSharedMedia if it is present (optional, never required).
local libStub = rawget(_G, "LibStub")
local LSM = libStub and libStub("LibSharedMedia-3.0", true)
if LSM and LSM.Register then
    for name, path in pairs(ns.Media.statusbar) do
        LSM:Register("statusbar", "SST: " .. name, path)
    end
end
