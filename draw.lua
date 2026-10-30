--[[
* pxtimers - draw
* Text, icons and colour helpers for the timer bars. Everything is drawn on ImGui draw lists:
* no GDI+, no native DLL and no D3DX sprite, so it draws the same under Wine/Proton as on Windows.
*
* Fonts: 'mono' (DejaVu Sans Mono, baked atlases in lib/fonts), 'game' (FFXI's own font, read from
* the install, at scale 1 only) or 'ashita' (ImGui's font). A font that can't load falls back to
* the next one for the session and says so once in chat.
--]]

require('common');
local d3d        = require('d3d8');
local ffi        = require('ffi');
local imgui      = require('imgui');
local bitmapfont = require('lib.bitmapfont');
local gamefont   = require('lib.gamefont');
local C          = ffi.C;

local draw = {};

draw.FONTS      = { 'mono', 'game', 'ashita' };
draw.FONT_NAMES = { mono = 'DejaVu Mono', game = 'Moji (game)', ashita = 'Ashita' };

local off    = {};   -- fonts that failed, off for the session
local pushed = nil;  -- whether ImGui takes a font size (PushFont(font, size)); false once it hasn't
local warned = {};

local function say(text)
    print(string.format('\30\81[\30\06pxtimers\30\81]\30\01 %s', text));
end
draw.say = say;

local function warn_once(key, text)
    if (not warned[key]) then
        warned[key] = true;
        say(text);
    end
end

-----------------------------------
-- Colours
-----------------------------------
-- 0xAARRGGBB to { r, g, b, a } floats.
function draw.argb(c)
    return {
        bit.band(bit.rshift(c, 16), 0xFF) / 255,
        bit.band(bit.rshift(c, 8), 0xFF) / 255,
        bit.band(c, 0xFF) / 255,
        bit.band(bit.rshift(c, 24), 0xFF) / 255,
    };
end

-- { r, g, b, a } floats to 0xAARRGGBB.
function draw.to_argb(c)
    local function b(v) return math.max(0, math.min(255, math.floor(v * 255 + 0.5))); end
    return bit.tobit(bit.bor(bit.lshift(b(c[4] or 1), 24), bit.lshift(b(c[1]), 16), bit.lshift(b(c[2]), 8), b(c[3])));
end

function draw.lerp(a, b, t)
    t = math.max(0, math.min(1, t));
    return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, (a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * t };
end

function draw.alpha(c, a)
    return { c[1], c[2], c[3], (c[4] or 1) * a };
end

-- A shade dark enough that near-white text on it passes WCAG AA contrast (4.5:1) for any hue.
function draw.deep(c)
    local function lin(v) return (v <= 0.04045) and (v / 12.92) or (((v + 0.055) / 1.055) ^ 2.4); end
    local k = 1.0;
    for _ = 1, 20 do
        local l = 0.2126 * lin(c[1] * k) + 0.7152 * lin(c[2] * k) + 0.0722 * lin(c[3] * k);
        if ((0.93 + 0.05) / (l + 0.05) >= 4.5) then
            break;
        end
        k = k * 0.92;
    end
    return { c[1] * k, c[2] * k, c[3] * k, 1 };
end

function draw.u32(c)
    return imgui.GetColorU32(c);
end

-----------------------------------
-- Text
-----------------------------------
local function plain(text)
    return type(text) == 'string' and not text:find('[^\32-\126]');
end

-- ImGui's CalcTextSize comes back as a vec or as two numbers depending on the binding.
local function calc_width(text)
    local w = imgui.CalcTextSize(text);
    if (type(w) ~= 'number') then
        return (w and (w.x or w[1])) or 0;
    end
    return w;
end

--[[
* The face used for text `px` pixels tall: { width(text), draw(list, x, y, color, text), line },
* or nil to use ImGui's own font. The game font is a 16px bitmap, so it's only used near that size.
--]]
local MONO = {};
local GAME = {};

function draw.face(font, px, text)
    if (font == 'ashita' or off[font] or not plain(text)) then
        return nil;
    end
    if (font == 'game') then
        -- Bars ask for 13px text at scale 1; the game font is a fixed 16px cell, so only use it there.
        if (math.abs(px - 13) > 1) then
            return draw.face('mono', px, text);
        end
        local ok, reason = gamefont.load();
        if (not ok) then
            off.game = true;
            warn_once('game', string.format('Game font: %s. Using DejaVu Mono.', tostring(reason)));
            return draw.face('mono', px, text);
        end
        GAME.line  = gamefont.CELL;
        GAME.width = function (t) return gamefont.width(t); end;
        GAME.draw  = function (list, x, y, color, t) gamefont.draw(list, x, y, color, t); end;
        return GAME;
    end
    local f, reason = bitmapfont.get('dejavu-mono', px);
    if (not f) then
        off.mono = true;
        warn_once('mono', string.format('DejaVu Mono: %s. Using Ashita\'s font.', tostring(reason)));
        return nil;
    end
    MONO.line  = f.line;
    MONO.width = function (t) return bitmapfont.width(f, t); end;
    MONO.draw  = function (list, x, y, color, t) bitmapfont.draw(list, f, x, y, color, t, f.line, 'ring'); end;
    return MONO;
end

-- Pixel height of a text line in this font at `px`. Ashita's font is pushed at `px` (see draw.push).
function draw.line_height(font, px)
    local f = draw.face(font, px, 'A');
    if (f) then
        return f.line;
    end
    return pushed and px or imgui.GetFontSize();
end

-- Sizes Ashita's ImGui font to `px` for the window being drawn. Returns true if it needs a pop.
function draw.push(px)
    if (pushed == false) then
        return false;
    end
    local ok = pcall(imgui.PushFont, imgui.GetFont(), px);
    pushed = ok;
    return ok;
end

function draw.text_width(font, px, text)
    local f = draw.face(font, px, text);
    if (f) then
        return f.width(text);
    end
    return calc_width(text);
end

local RING = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } };

-- Text with its line top at (x, y), ringed in dark so it reads on any bar colour.
function draw.text(list, font, px, x, y, color, text)
    local f = draw.face(font, px, text);
    if (f) then
        local ok, problem = pcall(f.draw, list, math.floor(x + 0.5), math.floor(y + 0.5), color, text);
        if (ok) then
            return;
        end
        off[font] = true;
        warn_once(font .. 'draw', string.format('%s font is off for this session: %s', draw.FONT_NAMES[font] or font, tostring(problem)));
    end
    local dark = imgui.GetColorU32({ 0, 0, 0, 0.85 * (color[4] or 1) });
    for _, o in ipairs(RING) do
        list:AddText({ x + o[1], y + o[2] }, dark, text);
    end
    list:AddText({ x, y }, imgui.GetColorU32(color), text);
end

-----------------------------------
-- Icons
-----------------------------------
-- Textures for status icons (from the game's resources) and the bundled ability/spell PNGs.
-- Each is made once; one that fails is remembered and skipped, so a bad icon never stops a bar.
local icons = {};

local function texture_from_memory(data, size)
    local out = ffi.new('IDirect3DTexture8*[1]');
    local ok = C.D3DXCreateTextureFromFileInMemoryEx(d3d.get_device(), data, size, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0,
        C.D3DFMT_A8R8G8B8, C.D3DPOOL_MANAGED, C.D3DX_DEFAULT, C.D3DX_DEFAULT, 0xFF000000, nil, nil, out);
    if (ok ~= C.S_OK) then
        return nil;
    end
    return d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', out[0]));
end

local function texture_from_file(path)
    local out = ffi.new('IDirect3DTexture8*[1]');
    if (C.D3DXCreateTextureFromFileA(d3d.get_device(), path, out) ~= C.S_OK) then
        return nil;
    end
    return d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', out[0]));
end

local function make_icon(key)
    if (key:sub(1, 7) == 'STATUS:') then
        local id = tonumber(key:sub(8));
        local icon = id and AshitaCore:GetResourceManager():GetStatusIconByIndex(id);
        if (icon == nil) then
            return nil;
        end
        -- Status icons carry no size; -1 lets D3DX read it from the bitmap header (as tTimers did).
        return texture_from_memory(icon.Bitmap, -1);
    end
    local path = GetImagePath(key);
    if (path == nil) then
        return nil;
    end
    return texture_from_file(path);
end

-- The ImGui texture id for an icon key ('STATUS:n' or a resources path), or nil.
function draw.icon(key)
    if (key == nil) then
        return nil;
    end
    local entry = icons[key];
    if (entry == nil) then
        local ok, texture = pcall(make_icon, key);
        if (ok and texture ~= nil) then
            entry = { texture = texture, id = tonumber(ffi.cast('uint32_t', texture)) };
        else
            entry = false;
        end
        icons[key] = entry;
    end
    return entry and entry.id or nil;
end

function draw.release()
    icons = {};
    pcall(bitmapfont.release);
    pcall(gamefont.release);
    collectgarbage();
end

return draw;
