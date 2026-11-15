-- hypr-switch helpers for ricing Hyprland configs.
--
-- A ricing's hyprland.lua can use:
--
--   local hs = dofile((os.getenv("HOME") or "") .. "/.hypr-switch/lib/hypr-switch.lua")
--   hs.omarchy_base({ shell = false })  -- Omarchy defaults without its shell
--   ...the ricing's own look, rules and binds...
--   hs.autostart("my-ricing")           -- start= entries of its ricing.conf
--
-- ricing.conf lives next to the snapshot: ~/.hypr-switch/shells/<name>/ricing.conf
-- (key=value, one per line, repeatable keys such as start= and packages=).
-- ricing-switch reads the same file for live switches, so login and live
-- switch start exactly the same programs.

local M = {}

local home = os.getenv("HOME") or ""
M.storage = home .. "/.hypr-switch"

function M.current()
  local file = io.open(M.storage .. "/.current_shell", "r")
  if not file then return "default" end
  local name = file:read("*l") or "default"
  file:close()
  return name
end

-- Parse shells/<name>/ricing.conf. Repeatable keys become lists.
local list_keys = { start = true, stop = true, packages = true, aur = true }

function M.meta(name)
  local meta = { start = {}, stop = {}, packages = {}, aur = {} }
  local file = io.open(M.storage .. "/shells/" .. name .. "/ricing.conf", "r")
  if not file then return meta end
  for line in file:lines() do
    if not line:match("^%s*#") then
      local key, value = line:match("^%s*([%w_.%-]+)%s*=%s*(.-)%s*$")
      if key and value ~= "" then
        if list_keys[key] then
          table.insert(meta[key], value)
        else
          meta[key] = value
        end
      end
    end
  end
  file:close()
  return meta
end

-- Load Omarchy's defaults (bindings, window rules, envs, helpers). With
-- { shell = false } Omarchy's autostart is replaced by the same session
-- services minus omarchy-launch-shell, so the ricing's own bar,
-- notifications and wallpaper are the only interface running.
function M.omarchy_base(opts)
  opts = opts or {}
  local omarchy = os.getenv("OMARCHY_PATH") or "/usr/share/omarchy"
  dofile(omarchy .. "/default/hypr/bootstrap.lua")

  if opts.shell == false then
    package.loaded["default.hypr.autostart"] = true
  end

  require("default.hypr.omarchy")

  if opts.shell == false then
    pcall(require, "default.hypr.startup-cursor")
    hl.on("hyprland.start", function()
      if omarchy_startup_cursor_pending and omarchy_startup_cursor then
        hl.env("XCURSOR_PATH", omarchy_startup_cursor.path)
        hl.env("XCURSOR_THEME", omarchy_startup_cursor.xcursor)
      end
      hl.exec_cmd("dbus-update-activation-environment --systemd --all")
      hl.exec_cmd("omarchy-provision-first-run")
      hl.exec_cmd("omarchy-powerprofiles-init")
      hl.exec_cmd(o.launch("omarchy-hyprland-monitor-watch"))
      hl.exec_cmd(o.launch("udiskie --automount --no-notify --no-tray"))
      hl.exec_cmd(o.launch("herdr server"))
      hl.exec_cmd("sleep 2 && omarchy-hook post-boot")
    end)
  end
end

-- Start what the ricing declares at login: every start= entry and, with
-- wallpaper=builtin, hypr-switch's Quickshell wallpaper layer.
function M.autostart(name)
  name = name or M.current()
  local meta = M.meta(name)
  hl.on("hyprland.start", function()
    if meta.wallpaper == "builtin" then
      hl.exec_cmd("qs -p " .. M.storage .. "/lib/wallpaper")
    end
    for _, command in ipairs(meta.start) do
      hl.exec_cmd(command)
    end
  end)
end

return M
