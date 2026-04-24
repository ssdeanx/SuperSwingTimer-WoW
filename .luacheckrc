-- .luacheckrc for World of Warcraft AddOns
std = "lua51+min" -- Use Lua 5.1 with minimal standard library
-- Define common WoW API globals
globals = {
    "UnitName", "UnitHealth", "UnitHealthMax", "GetTime", "PlaySoundFile",
    "CreateFrame", "UIParent", "GameTooltip", "_G", "select", "pairs", "ipairs"
    -- Add other WoW API functions and globals your addon uses
}
-- Ignore unused arguments for event handler functions
unused_args = "no_self"
