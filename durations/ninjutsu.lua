--[[
Copyright (c) 2024 Thorny

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]
local dataTracker;

local function Initialize(tracker, buffer)
    dataTracker = tracker;

    --Monomi: Ichi
    buffer[318] = function(targetId)
        -- Phoenix: 180s (modules/phoenix/lua/globals/spells/enhancing_ninjutsu.lua)
        return 180;
    end

    --Utsusemi: Ichi
    buffer[338] = function(targetId)
        return 900;
    end

    --Utsusemi: Ni
    buffer[339] = function(targetId)
        return 900;
    end

    --Utsusemi: San
    buffer[340] = function(targetId)
        return 900;
    end

	--Aisha: Ichi
	buffer[319] = function(targetId)
		return 120;
	end






    --Tonko: Ichi
    buffer[353] = function(targetId)
        return 180;
    end

    --Tonko: Ni
    buffer[354] = function(targetId)
        return 300;
    end
    
    --Gekka: Ichi
    buffer[505] = function(targetId)
        return 300; -- Phoenix ninjutsuPTable
    end
    
    --Yain: Ichi
    buffer[506] = function(targetId)
        return 300;
    end
    
    --Myoshu: Ichi
    buffer[507] = function(targetId)
        return 180; -- Phoenix ninjutsuPTable
    end

    --Kakka: Ichi
    buffer[509] = function(targetId)
        return 180; -- Phoenix ninjutsuPTable
    end    
    
    --Migawari: Ichi
    buffer[510] = function(targetId)
        return 60;
    end

    -- Phoenix: enfeebling ninjutsu base durations (scripts/globals/spells/enfeebling_spell.lua).
    -- A partial resist shortens these; the wear-off message clears the timer early.
    local enfeeblingNinjutsu = {
        [341] = { 180, 4 },   -- Jubaku: Ichi (paralysis)
        [342] = { 300, 4 },   -- Jubaku: Ni
        [343] = { 420, 4 },   -- Jubaku: San
        [344] = { 180, 13 },  -- Hojo: Ichi (slow)
        [345] = { 300, 13 },  -- Hojo: Ni
        [346] = { 420, 13 },  -- Hojo: San
        [347] = { 180, 5 },   -- Kurayami: Ichi (blindness)
        [348] = { 300, 5 },   -- Kurayami: Ni
        [349] = { 420, 5 },   -- Kurayami: San
        [350] = { 60, 3 },    -- Dokumori: Ichi (poison)
        [351] = { 120, 3 },   -- Dokumori: Ni
        [352] = { 360, 3 },   -- Dokumori: San
        [508] = { 180, 168 }, -- Yurin: Ichi (inhibit TP)
    };
    for id, entry in pairs(enfeeblingNinjutsu) do
        buffer[id] = function(targetId)
            return entry[1], entry[2];
        end
    end
end

return Initialize;