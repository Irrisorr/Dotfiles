-- swayimg config with Eye of GNOME (eog) key bindings.
-- Defaults and full API: /usr/share/swayimg/example.lua, /usr/share/swayimg/swayimg.lua
--
-- Not available in swayimg, so not bound: Ctrl+O / Shift+Ctrl+S (no file
-- dialogs), Ctrl+P (no printing), F10 / Ctrl+, (no menus), Shift+Ctrl+P (no
-- presenter), rotate gesture. F1 / Ctrl+/ show a cheat sheet instead of help.

--------------------------------------------------------------------------------
-- General
--------------------------------------------------------------------------------
-- Without this, opening one file from Thunar gives a list of one: nothing to flip through
swayimg.imagelist.adjacent = true

swayimg.text.font = "JetBrainsMono Nerd Font"
swayimg.text.size = 18
swayimg.text.visible = false               -- eog hides image properties until F9

swayimg.viewer.default_scale = "optimal"   -- eog "best fit": shrink to window, never upscale
swayimg.viewer.loop = false                -- eog stops at the first/last image
-- A revisited image is reloaded from disk unrotated, so Ctrl+S's list of
-- transforms (reset on every image change) always matches what's on screen
swayimg.viewer.history = 0

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
-- Keysyms follow the active layout, so on the Russian one Ctrl+O arrives as
-- Ctrl+щ. Every letter binding gets its Cyrillic twin (same physical key).
local CYRILLIC = {
  c = "Cyrillic_es", f = "Cyrillic_a",  m = "Cyrillic_softsign",
  o = "Cyrillic_shcha", p = "Cyrillic_ze", q = "Cyrillic_shorti",
  r = "Cyrillic_ka", s = "Cyrillic_yeru", w = "Cyrillic_tse",
  z = "Cyrillic_ya",
}

-- fn gets the mode it fired in, so the same binding drives viewer and slideshow
local function bind(modes, keys, fn)
  for _, mode in ipairs(modes) do
    for _, key in ipairs(keys) do
      local handler = function() fn(mode) end
      mode.on_key(key, handler)
      local prefix, letter = key:match("^(.-)(%a)$")
      if letter and (prefix == "" or prefix:sub(-1) == "+") and CYRILLIC[letter] then
        mode.on_key(prefix .. CYRILLIC[letter], handler)
      end
    end
  end
end

local function sh_quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- LuaJIT returns the exit code, Lua 5.2+ returns true/nil
local function run(cmd)
  local rc = os.execute(cmd)
  return rc == 0 or rc == true
end

-- First line of a command's output, "" when there is none
local function read_cmd(cmd)
  local out = io.popen(cmd)
  local line = out:read("*l") or ""
  out:close()
  return line
end

local function current_image()
  if swayimg.mode == "gallery" then
    return swayimg.gallery.get_image()
  end
  return swayimg.viewer.get_image()
end

local function status(msg)
  swayimg.text.status = msg
end

local viewer, slideshow, gallery = swayimg.viewer, swayimg.slideshow, swayimg.gallery
local VIEW = { viewer, slideshow }
local ALL = { viewer, slideshow, gallery }

local hide_help                            -- cheat sheet, defined at the end

--------------------------------------------------------------------------------
-- General: close, fullscreen, properties, wallpaper
--------------------------------------------------------------------------------
bind(ALL, { "Ctrl+w", "Ctrl+q", "q" }, function() swayimg.exit() end)

bind(ALL, { "Escape" }, function()
  if hide_help() then return end
  if swayimg.fullscreen then
    swayimg.fullscreen = false
  else
    swayimg.exit()
  end
end)

bind(ALL, { "F11" }, function() swayimg.fullscreen = not swayimg.fullscreen end)

-- eog's properties sidebar → swayimg's text layer (name, size, EXIF, scale)
bind(ALL, { "F9", "Alt+Return" }, function()
  if hide_help() then return end
  swayimg.text.visible = not swayimg.text.visible
end)

bind(ALL, { "Ctrl+F8" }, function()
  local img = current_image()
  if img and run("dms ipc call wallpaper set " .. sh_quote(img.path) .. " >/dev/null") then
    status("Set as wallpaper")
  else
    status("Failed to set wallpaper")
  end
end)

--------------------------------------------------------------------------------
-- Navigation
--------------------------------------------------------------------------------
bind(VIEW, { "Left", "Alt+Left" }, function(m) m.open("prev") end)
bind(VIEW, { "Right", "Alt+Right" }, function(m) m.open("next") end)
bind(VIEW, { "Home", "Alt+Home" }, function(m) m.open("first") end)
bind(VIEW, { "End", "Alt+End" }, function(m) m.open("last") end)
bind(VIEW, { "Ctrl+m" }, function(m) m.open("random") end)

bind(VIEW, { "Ctrl+F9" }, function() swayimg.mode = "gallery" end)
bind({ gallery }, { "Ctrl+F9" }, function() swayimg.mode = "viewer" end)

bind({ viewer, gallery }, { "F5" }, function() swayimg.mode = "slideshow" end)
-- swayimg can't pause a slideshow, so P stops it on the current image
bind({ slideshow }, { "F5", "p" }, function() swayimg.mode = "viewer" end)

--------------------------------------------------------------------------------
-- Zoom
--------------------------------------------------------------------------------
local function zoom(m, factor)
  m.scale = m.scale * factor
end

-- "+" is Shift+= on the main row, so both spellings are bound
bind(VIEW, { "plus", "Shift+plus", "equal", "KP_Add",
             "Ctrl+plus", "Ctrl+Shift+plus", "Ctrl+equal", "Ctrl+KP_Add" },
     function(m) zoom(m, 1.1) end)
bind(VIEW, { "minus", "KP_Subtract", "Ctrl+minus", "Ctrl+KP_Subtract" },
     function(m) zoom(m, 1 / 1.1) end)
bind(VIEW, { "1", "Ctrl+0", "KP_1", "Ctrl+KP_0" }, function(m) m.set_fix_scale("real") end)
bind(VIEW, { "f" }, function(m) m.set_fix_scale("optimal") end)

--------------------------------------------------------------------------------
-- Rotation, flip and Ctrl+S
--------------------------------------------------------------------------------
-- swayimg only turns the picture on screen; the file is rewritten on Ctrl+S by
-- replaying these transforms with jpegtran (lossless JPEG) or ImageMagick.
local transforms = {}

for _, mode in ipairs(VIEW) do
  mode.on_image_change(function() transforms = {} end)
end

local function transform(m, op)
  if op == "rot90" then m.rotate(90)
  elseif op == "rot270" then m.rotate(270)
  elseif op == "flipv" then m.flip_vertical()
  else m.flip_horizontal() end
  table.insert(transforms, op)
end

bind(VIEW, { "Ctrl+r", "bracketright" }, function(m) transform(m, "rot90") end)
bind(VIEW, { "Ctrl+Shift+r", "bracketleft" }, function(m) transform(m, "rot270") end)
bind(VIEW, { "m" }, function(m) transform(m, "flipv") end)
bind(VIEW, { "Shift+m" }, function(m) transform(m, "fliph") end)

local JPEGTRAN = {
  rot90 = "-rotate 90", rot180 = "-rotate 180", rot270 = "-rotate 270",
  flipv = "-flip vertical", fliph = "-flip horizontal",
  transpose = "-transpose", transverse = "-transverse",
}
local MAGICK = {
  rot90 = "-rotate 90", rot270 = "-rotate 270", flipv = "-flip", fliph = "-flop",
}
-- EXIF Orientation → transform that turns the stored pixels into what swayimg
-- shows (it applies the tag on load); baked in, then the tag is reset to 1
local EXIF_ORIENTATION = {
  ["2"] = "fliph", ["3"] = "rot180", ["4"] = "flipv", ["5"] = "transpose",
  ["6"] = "rot90", ["7"] = "transverse", ["8"] = "rot270",
}

local TMP = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/swayimg-save"

-- -perfect refuses instead of leaving untransformed edge blocks; the caller
-- then falls back to ImageMagick
local function save_jpeg(path)
  local orientation = read_cmd("exiv2 -q -K Exif.Image.Orientation -Pv " .. sh_quote(path) .. " 2>/dev/null")
  local ops = { EXIF_ORIENTATION[orientation] }
  for _, op in ipairs(transforms) do table.insert(ops, op) end

  local tmp, next_tmp = sh_quote(TMP .. ".jpg"), sh_quote(TMP .. ".next.jpg")
  local ok = run("cp -- " .. sh_quote(path) .. " " .. tmp)
  for _, op in ipairs(ops) do
    ok = ok and run(("jpegtran -copy all -perfect %s -outfile %s %s 2>/dev/null && mv -f %s %s")
                    :format(JPEGTRAN[op], next_tmp, tmp, next_tmp, tmp))
  end
  if ok and EXIF_ORIENTATION[orientation] then
    ok = run("exiv2 -q -M'set Exif.Image.Orientation 1' " .. tmp)
  end
  -- cp onto the original keeps its permissions and inode
  ok = ok and run("cp -- " .. tmp .. " " .. sh_quote(path))
  os.remove(TMP .. ".jpg")
  return ok
end

-- Debian/Ubuntu may only ship the versioned name
local MAGICK_BIN = read_cmd("command -v magick || command -v magick-im7.q16")

local function save_magick(path, ext)
  if MAGICK_BIN == "" then return false end
  local args = {}
  for _, op in ipairs(transforms) do table.insert(args, MAGICK[op]) end
  local tmp = TMP .. "." .. ext
  local ok = run(("%s %s -auto-orient %s %s && cp -- %s %s"):format(
    sh_quote(MAGICK_BIN), sh_quote(path), table.concat(args, " "),
    sh_quote(tmp), sh_quote(tmp), sh_quote(path)))
  os.remove(tmp)
  return ok
end

bind(VIEW, { "Ctrl+s" }, function(m)
  local img = m.get_image()
  if not img then return end
  if #transforms == 0 then
    status("Nothing to save")
    return
  end
  local ext = (img.path:match("%.([^./]+)$") or ""):lower()
  local jpeg = ext == "jpg" or ext == "jpeg" or ext == "jpe" or ext == "jfif"
  if (jpeg and save_jpeg(img.path)) or save_magick(img.path, ext) then
    transforms = {}
    status("Saved")
  else
    status("Save failed")
  end
end)

--------------------------------------------------------------------------------
-- Scrolling a large image
--------------------------------------------------------------------------------
local STEP = 100

-- set_abs_position takes whole pixels; touchpad deltas are fractional
local function pan(m, dx, dy)
  local pos = m.get_position()
  m.set_abs_position(math.floor(pos.x + dx + 0.5), math.floor(pos.y + dy + 0.5))
end

bind(VIEW, { "Ctrl+Left", "Ctrl+Prior", "Ctrl+Home" }, function(m) pan(m, STEP, 0) end)
bind(VIEW, { "Ctrl+Right", "Ctrl+Next", "Ctrl+End" }, function(m) pan(m, -STEP, 0) end)
bind(VIEW, { "Ctrl+Up", "Prior" }, function(m) pan(m, 0, STEP) end)
bind(VIEW, { "Ctrl+Down", "Next" }, function(m) pan(m, 0, -STEP) end)

--------------------------------------------------------------------------------
-- Clipboard, trash, delete
--------------------------------------------------------------------------------
bind(ALL, { "Ctrl+c" }, function()
  local img = current_image()
  if img and run("wl-copy < " .. sh_quote(img.path)) then
    status("Copied to clipboard")
  end
end)

local last_trashed

bind(ALL, { "Delete" }, function()
  local img = current_image()
  if img and run("gio trash -- " .. sh_quote(img.path)) then
    last_trashed = img.path
    swayimg.imagelist.remove(img.path)
    status("Moved to trash (Ctrl+Z to undo)")
  end
end)

-- Undo the last trash: find its entry by original path and restore it
bind(ALL, { "Ctrl+z" }, function()
  if not last_trashed then return end
  local uri
  local list = io.popen("gio trash --list")
  for line in list:lines() do
    local u, orig = line:match("^(%S+)\t(.+)$")
    if orig == last_trashed then uri = u end
  end
  list:close()
  if uri and run("gio trash --restore " .. sh_quote(uri)) then
    swayimg.imagelist.add(last_trashed)
    if swayimg.mode ~= "gallery" then
      viewer.open_path(last_trashed)
    end
    status("Restored")
    last_trashed = nil
  end
end)

-- eog asks before deleting for good; swayimg has no dialogs, so press twice
local pending_delete, pending_time

bind(ALL, { "Shift+Delete" }, function()
  local img = current_image()
  if not img then return end
  if pending_delete == img.path and os.time() - pending_time <= 3 then
    pending_delete = nil
    if os.remove(img.path) then
      swayimg.imagelist.remove(img.path)
      status("Deleted permanently")
    else
      status("Delete failed")
    end
  else
    pending_delete, pending_time = img.path, os.time()
    status("Shift+Delete again to delete permanently")
  end
end)

--------------------------------------------------------------------------------
-- Mouse and touchpad
--------------------------------------------------------------------------------
-- Mouse wheel zooms at the cursor like eog; on the touchpad zoom is the pinch
-- (built in), and two fingers drag an image larger than the window. A
-- horizontal swipe over an image that fits flips images; with niri's
-- natural-scroll, swiping left gives positive deltas → next image. Deltas
-- accumulate so one swipe flips one image, not one per event.
local PAN_SPEED = 60
local SWIPE_THRESHOLD = 4
local swipe, swipe_time = 0, 0

-- swayimg doesn't say where a scroll came from: a wheel moves in whole
-- notches (1, or 1/8 on hi-res wheels), a touchpad in arbitrary fractions
local function is_wheel(delta)
  return delta ~= 0 and delta * 8 == math.floor(delta * 8)
end

for _, mode in ipairs(VIEW) do
  mode.on_scroll(function(_, horizontal, vertical)
    if is_wheel(vertical) and horizontal == 0 then
      local mouse = swayimg.get_mouse_pos()
      local scale = mode.scale
      mode.set_abs_scale(scale - scale * vertical / 10.0, mouse.x, mouse.y)
      return
    end

    local img = mode.get_image()
    if not img then return end
    local win = swayimg.get_window_size()
    local wide = img.width * mode.scale > win.width
    local tall = img.height * mode.scale > win.height
    if wide or tall then
      pan(mode, wide and -horizontal * PAN_SPEED or 0, tall and -vertical * PAN_SPEED or 0)
    end

    if not wide and horizontal ~= 0 and os.time() - swipe_time >= 0.3 then
      swipe = swipe + horizontal
      if math.abs(swipe) >= SWIPE_THRESHOLD then
        mode.open(swipe > 0 and "next" or "prev")
        swipe, swipe_time = 0, os.time()
      end
    end
  end)
end

--------------------------------------------------------------------------------
-- Cheat sheet (F1, Ctrl+?)
--------------------------------------------------------------------------------
-- Drawn in the text layer in place of the image info, so the info schemes
-- (example.lua defaults) are kept here to put back.
local INFO = {
  viewer = {
    topleft = {
      "File:\t{name}",
      "Format:\t{format}",
      "File size:\t{sizehr}",
      "File time:\t{time}",
      "EXIF date:\t{meta.Exif.Photo.DateTimeOriginal}",
      "EXIF camera:\t{meta.Exif.Image.Model}",
    },
    topright = {
      "Image:\t{list.index} of {list.total}",
      "Frame:\t{frame.index} of {frame.total}",
      "Size:\t{frame.width}x{frame.height}",
    },
    bottomleft = { "Scale:\t{scale}" },
    bottomright = {},
  },
  slideshow = { topleft = { "{name}" }, topright = {}, bottomleft = {}, bottomright = {} },
  gallery = {
    topleft = { "File:\t{name}" },
    topright = { "{list.index} of {list.total}" },
    bottomleft = {},
    bottomright = {},
  },
}

-- Lists swayimg's own defaults that are still active too (Enter, S, T, A,
-- Insert, Backspace, Shift+PgUp/PgDn, mouse drags)
local HELP_VIEW = {
  topleft = {
    "Hotkeys  (F1 / Ctrl+/ / Esc to close)",
    "",
    "← →  Alt+← →\tprevious / next",
    "Home  End\tfirst / last",
    "Ctrl+M\trandom",
    "2-finger swipe\tprevious / next",
    "Enter  Ctrl+F9\tfolder overview (gallery)",
    "",
    "+ -  wheel  pinch\tzoom",
    "1  Ctrl+0\treal size",
    "F\tbest fit",
    "Backspace\treset zoom and position",
    "2 fingers  left drag\tmove large image",
    "Ctrl+arrows\tmove large image",
    "PgUp  PgDn\tscroll up / down",
    "",
    "Ctrl+R  Shift+Ctrl+R  ] [\trotate",
    "M  Shift+M\tflip",
    "Ctrl+S\tsave rotation to file",
  },
  topright = {
    "F11\tfullscreen",
    "F5  S\tslideshow",
    "P  F5  S\tstop slideshow",
    "F9  Alt+Enter  T\timage info",
    "Shift+PgUp  Shift+PgDn\tanimation frame",
    "A\tanti-aliasing",
    "",
    "Ctrl+C\tcopy image",
    "Right drag\tdrop file into an app",
    "Ctrl+F8\tset as wallpaper",
    "Insert\tmark image",
    "Delete\tmove to trash",
    "Ctrl+Z\tundo trash",
    "Shift+Delete ×2\tdelete for good",
    "",
    "Esc  Ctrl+W  Q\tclose",
  },
  bottomleft = {},
  bottomright = {},
}

local HELP_GALLERY = {
  topleft = {
    "Hotkeys  (F1 / Ctrl+/ / Esc to close)",
    "",
    "Arrows  Home  End\tselect",
    "PgUp  PgDn  wheel\tselect",
    "Enter  Ctrl+F9  click\topen",
    "+ -  Ctrl+wheel\tthumbnail size",
    "F5  S\tslideshow",
  },
  topright = {
    "F11  F\tfullscreen",
    "T\timage info",
    "Ctrl+C\tcopy image",
    "Right drag\tdrop file into an app",
    "Insert\tmark image",
    "Delete  Ctrl+Z\ttrash / undo",
    "Shift+Delete ×2\tdelete for good",
    "Esc  Ctrl+W  Q\tclose",
  },
  bottomleft = {},
  bottomright = {},
}

local help_shown = false

local function set_schemes(v, s, g)
  viewer.text, slideshow.text, gallery.text = v, s, g
end

-- Returns true when there was a cheat sheet to close
hide_help = function()
  if not help_shown then return false end
  help_shown = false
  set_schemes(INFO.viewer, INFO.slideshow, INFO.gallery)
  swayimg.text.background = 0x00000000
  swayimg.text.timeout = 5
  swayimg.text.visible = false
  return true
end

local function show_help()
  help_shown = true
  set_schemes(HELP_VIEW, HELP_VIEW, HELP_GALLERY)
  swayimg.text.background = 0xcc000000
  swayimg.text.timeout = 0                -- stay until closed
  -- re-show so the layer picks up the timeout even if it was already visible
  swayimg.text.visible = false
  swayimg.text.visible = true
end

-- Ctrl+? arrives as Ctrl+Shift+question; Ctrl+/ is the same key without Shift
bind(ALL, { "F1", "Ctrl+Shift+question", "Ctrl+slash" }, function()
  if not hide_help() then show_help() end
end)
