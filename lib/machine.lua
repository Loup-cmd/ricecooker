-- hypr-switch machine overlay.
--
-- Loaded at the very end of every non-default ricing's hyprland.lua (after the
-- keymap overlay). Upstream dotfiles hard-code their author's monitors and a
-- US keyboard; this puts back what belongs to *this* machine:
--   * monitors from the default (Omarchy) shell's hypr/monitors.lua,
--   * the keyboard layout Omarchy uses (/etc/vconsole.conf via its keyboard
--     module, with the same Latin-first rule), leaving the ricing's other
--     input settings (sensitivity, touchpad feel…) alone.
-- A ricing can opt out with `machine_overlay=false` in its ricing.conf.

local home = os.getenv("HOME") or ""
local storage = home .. "/.hypr-switch"

local function read_meta_flag(key)
  local file = io.open(storage .. "/.current_shell", "r")
  if not file then return nil end
  local shell = file:read("*l") or ""
  file:close()
  local meta = io.open(storage .. "/shells/" .. shell .. "/ricing.conf", "r")
  if not meta then return nil end
  local value = nil
  for line in meta:lines() do
    local k, v = line:match("^%s*([%w_.%-]+)%s*=%s*(.-)%s*$")
    if k == key then value = v end
  end
  meta:close()
  return value
end

local function apply_monitors()
  if read_meta_flag("machine_monitors") == "false" then return end
  local path = storage .. "/shells/default/configs/config/hypr/monitors.lua"
  local file = io.open(path, "r")
  if not file then return end
  file:close()
  local ok, err = pcall(dofile, path)
  if not ok then print("[hypr-switch] machine monitors failed: " .. tostring(err)) end
end

local function vconsole()
  local values = {}
  local file = io.open("/etc/vconsole.conf", "r")
  if not file then return values end
  for line in file:lines() do
    local k, v = line:match("^%s*([%w_]+)%s*=%s*\"?([^\"]*)\"?%s*$")
    if k then values[k] = v end
  end
  file:close()
  return values
end

local function apply_keyboard()
  if read_meta_flag("machine_keyboard") == "false" then return end

  local omarchy = os.getenv("OMARCHY_PATH") or "/usr/share/omarchy"
  if not package.path:find(omarchy, 1, true) then
    package.path = omarchy .. "/?.lua;" .. package.path
  end

  local selected = nil
  local ok, keyboard = pcall(require, "default.hypr.keyboard")
  if ok and type(keyboard) == "table" and type(keyboard.selected) == "function" then
    local ok_sel, value = pcall(keyboard.selected)
    if ok_sel and type(value) == "table" then selected = value end
  end
  selected = selected or vconsole()

  local layout = selected.XKBLAYOUT
  if not layout or layout == "" then return end
  local variant = selected.XKBVARIANT or ""
  local options = ""
  local symbols = io.open("/etc/xkb/symbols/omarchy", "r")
  if symbols then
    symbols:close()
    options = "omarchy:shift_caps_compose"
  end

  local non_latin = " af am ara bd bg by et ge gr il in iq ir kg kh kz la lk mk mm mn mv np rs ru sy th tj ua "
  local first = layout:match("^[^,]*")
  if non_latin:find(" " .. first .. " ", 1, true) then
    layout = "us," .. layout
    variant = "," .. variant
    options = (options ~= "" and options .. "," or "") .. "grp:alts_toggle"
  end

  hl.config({
    input = {
      kb_layout = layout,
      kb_variant = variant,
      kb_model = "",
      kb_options = options,
      kb_rules = "",
    },
  })
end

apply_monitors()
apply_keyboard()
