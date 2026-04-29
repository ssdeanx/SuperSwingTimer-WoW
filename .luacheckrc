-- .luacheckrc for World of Warcraft AddOns
std = "lua51+min" -- Use Lua 5.1 with minimal standard library
-- Define common WoW API globals
globals = {
    "UnitName", "UnitHealth", "UnitHealthMax", "GetTime", "PlaySoundFile",
    "CreateFrame", "UIParent", "GameTooltip", "_G", "select", "pairs", "ipairs",
    "SuperSwingTimerDB", "C_Timer", "C_UnitAuras", "C_UnitAuras.GetPlayerAuraBySpellID",
    "GetTime", "GetSpellInfo", "GetItemInfo", "GetInventoryItemLink", "GetInventoryItemID",
    "SLASH_SUPERSWINGTIMER1", "SLASH_SUPERSWINGTIMER2", "SLASH_SUPERSWINGTIMER3", "SLASH_SUPERSWINGTIMER4",
    "GetTimePrecise", "GetSpellCooldown", "HunterTimerDB", "SwangThangDB"
    -- Add other WoW API functions and globals your addon uses
}
-- Allow longer lines in this addon repository to avoid false positives
max_line_length = 260
-- Disable warnings for unused function arguments
unused_args = false
