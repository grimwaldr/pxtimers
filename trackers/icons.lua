--[[
* pxtimers - icons
* The icon a spell or job ability has in the game's Magic and Abilities menus, from the PNGs in
* resources/ (the same set the Recasts panel uses). Buff and debuff bars use these first, so a bar
* looks like the action that made it; the status icon is only the fallback.
*
* Ability icons are stored by recast timer, since that's what the menus group them by. Timers shared
* between jobs (one-hours, for example) have one icon per job: '<timer>_<job>.png'.
--]]

local icons = {};

local function first(paths)
    for _, path in ipairs(paths) do
        if GetFilePath(path) then
            return path;
        end
    end
    return nil;
end

function icons.spell(spellId)
    return first({ string.format('spells/%u.png', spellId) });
end

-- `abilityId` is the action packet's ability id (resource id - 512).
function icons.ability(abilityId)
    local res = AshitaCore:GetResourceManager():GetAbilityById(abilityId + 512);
    if (res == nil) then
        return nil;
    end
    local timer = res.RecastTimerId;
    local job = AshitaCore:GetMemoryManager():GetPlayer():GetMainJob();
    return first({ string.format('abilities/%u_%u.png', timer, job), string.format('abilities/%u.png', timer) });
end

function icons.action(actionType, actionId)
    if (actionType == 'Spell') then
        return icons.spell(actionId);
    elseif (actionType == 'Ability') then
        return icons.ability(actionId);
    end
    return nil;
end

return icons;
