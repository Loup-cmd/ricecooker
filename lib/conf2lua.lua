#!/usr/bin/env lua
-- conf2lua.lua — best-effort hyprlang (hyprland.conf) → Hyprland Lua converter.
--
--   lua conf2lua.lua <hyprland.conf> <out.lua> [<start-list-out>] [<config-root>]
--
-- Writes one Lua statement per line so `Hyprland --verify-config -c out.lua`
-- can point at each line it rejects; `ricing install` then comments those out
-- until the file is clean. Converted: variables ($var), source = (inlined),
-- sections and `a:b:c = v` options, env, bezier, animation, exec binds,
-- window/layer rules (v1, v2 and match: syntax). exec-once/exec commands are
-- written to <start-list-out> (one per line) so they can become start=
-- entries of the ricing's ricing.conf. monitor= lines are dropped (the
-- hypr-switch machine overlay owns monitors). <config-root> maps
-- ~/.config/<x> paths used by `source =` onto the captured snapshot.

local input, output, start_out, config_root = arg[1], arg[2], arg[3], arg[4]
if not input or not output then
  io.stderr:write("usage: conf2lua.lua <hyprland.conf> <out.lua> [<start-list-out>] [<config-root>]\n")
  os.exit(2)
end

local home = os.getenv("HOME") or ""
local vars = {}
local lines_out = {}
local starts = {}
local seen_files = {}

local function add(line) lines_out[#lines_out + 1] = line end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function dirname(path) return path:match("^(.*)/[^/]*$") or "." end

local function lua_string(s) return string.format("%q", s) end

local function substitute(value)
  -- Longest variable names first so $foo_bar wins over $foo.
  local names = {}
  for name in pairs(vars) do names[#names + 1] = name end
  table.sort(names, function(a, b) return #a > #b end)
  for _, name in ipairs(names) do
    value = value:gsub("%$" .. name:gsub("%p", "%%%0"), (vars[name]:gsub("%%", "%%%%")))
  end
  return value
end

local function strip_comment(line)
  -- hyprlang: '#' starts a comment, '##' is a literal '#'.
  local out, i = {}, 1
  while i <= #line do
    local c = line:sub(i, i)
    if c == "#" then
      if line:sub(i + 1, i + 1) == "#" then
        out[#out + 1] = "#"
        i = i + 2
      else
        break
      end
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  return table.concat(out)
end

local function resolve_path(path, base_dir)
  path = trim(path)
  path = path:gsub("^~", home):gsub("%$HOME", home)
  if config_root then
    local rest = path:match("^" .. home:gsub("%p", "%%%0") .. "/%.config/(.*)$")
    if rest then
      local candidate = config_root .. "/" .. rest
      local f = io.open(candidate, "r")
      if f then f:close(); return candidate end
    end
  end
  if not path:match("^/") then path = base_dir .. "/" .. path end
  return path
end

-- ---------------------------------------------------------------- values --

local function is_color(token)
  return token:match("^rgba?%b()$") or token:match("^0x%x%x%x%x%x%x%x%x$")
end

local function color_string(token)
  local hex = token:match("^0x(%x%x)(%x%x%x%x%x%x)$")
  if hex then
    local a, rgb = token:match("^0x(%x%x)(%x%x%x%x%x%x)$")
    return "rgba(" .. rgb .. a .. ")"
  end
  return token
end

local function lua_value(value)
  local v = trim(value)
  local lower = v:lower()
  if lower == "true" or lower == "yes" or lower == "on" then return "true" end
  if lower == "false" or lower == "no" or lower == "off" then return "false" end
  if v:match("^%-?%d+$") or v:match("^%-?%d*%.%d+$") then return v end

  -- Gradients: "rgba(..) rgba(..) 45deg"
  local tokens = {}
  for token in v:gmatch("%S+") do tokens[#tokens + 1] = token end
  if #tokens >= 1 and is_color(tokens[1]) then
    local colors, angle = {}, nil
    for _, token in ipairs(tokens) do
      if is_color(token) then
        colors[#colors + 1] = lua_string(color_string(token))
      elseif token:match("^%-?%d+deg$") then
        angle = token:match("^(%-?%d+)deg$")
      end
    end
    if #colors == 1 and not angle then return colors[1] end
    return "{ colors = { " .. table.concat(colors, ", ") .. " }" .. (angle and (", angle = " .. angle) or "") .. " }"
  end
  return lua_string(v)
end

-- "general:col.active_border" -> "general = { col = { active_border = X } }"
local function nested(path, value)
  local parts = {}
  for part in path:gmatch("[^:%.]+") do parts[#parts + 1] = part end
  local s = value
  for i = #parts, 1, -1 do
    local key = parts[i]
    if not key:match("^[%a_][%w_]*$") then key = "[" .. lua_string(key) .. "]" end
    s = "{ " .. key .. " = " .. s .. " }"
  end
  return s
end

-- ------------------------------------------------------------- keywords --

local function split_commas(s, max)
  local parts = {}
  local rest = s
  while true do
    if max and #parts == max - 1 then
      parts[#parts + 1] = trim(rest)
      break
    end
    local a, b = rest:find(",", 1, true)
    if not a then
      parts[#parts + 1] = trim(rest)
      break
    end
    parts[#parts + 1] = trim(rest:sub(1, a - 1))
    rest = rest:sub(b + 1)
  end
  return parts
end

local function emit_bezier(value)
  local p = split_commas(value)
  if #p < 5 then return end
  add(string.format('hl.curve(%s, { type = "bezier", points = { {%s, %s}, {%s, %s} } })',
    lua_string(p[1]), p[2], p[3], p[4], p[5]))
end

local function emit_animation(value)
  local p = split_commas(value)
  if #p < 2 then return end
  local enabled = (p[2] == "1" or p[2]:lower() == "on" or p[2]:lower() == "true") and "true" or "false"
  local fields = { "leaf = " .. lua_string(p[1]), "enabled = " .. enabled }
  if p[3] and p[3] ~= "" then fields[#fields + 1] = "speed = " .. p[3] end
  if p[4] and p[4] ~= "" then fields[#fields + 1] = "bezier = " .. lua_string(p[4]) end
  if p[5] and p[5] ~= "" then fields[#fields + 1] = "style = " .. lua_string(p[5]) end
  add("hl.animation({ " .. table.concat(fields, ", ") .. " })")
end

local function emit_env(value)
  local p = split_commas(value, 2)
  if #p < 2 then return end
  add(string.format("hl.env(%s, %s)", lua_string(p[1]), lua_string(p[2])))
end

local mod_names = { SUPER = "SUPER", WIN = "SUPER", MOD4 = "SUPER", LOGO = "SUPER",
  SHIFT = "SHIFT", CTRL = "CTRL", CONTROL = "CTRL", ALT = "ALT", MOD1 = "ALT" }

local function emit_bind(keyword, value)
  local flags = keyword:match("^bind(%a*)$") or ""
  if flags:find("m") then return end -- mouse binds: Omarchy provides them
  local p = split_commas(value, 4)
  if #p < 3 then return end
  local mods, key, dispatcher, args = p[1], p[2], p[3]:lower(), p[4] or ""
  if dispatcher ~= "exec" or args == "" then return end
  local chord = {}
  for mod in mods:upper():gmatch("[%w_]+") do
    chord[#chord + 1] = mod_names[mod] or mod
  end
  if key == "" then return end
  chord[#chord + 1] = key
  local opts = {}
  if flags:find("l") then opts[#opts + 1] = "locked = true" end
  if flags:find("e") then opts[#opts + 1] = "repeating = true" end
  if flags:find("r") then opts[#opts + 1] = "release = true" end
  local line = string.format("hl.bind(%s, hl.dsp.exec_cmd(%s)",
    lua_string(table.concat(chord, " + ")), lua_string(args))
  if #opts > 0 then line = line .. ", { " .. table.concat(opts, ", ") .. " }" end
  add(line .. ")")
end

-- Window/layer rule effect "name args" -> Lua field.
local function rule_effect(effect)
  local name, rest = effect:match("^(%S+)%s*(.*)$")
  if not name then return nil end
  name = name:lower()
  local aliases = { noblur = "no_blur", noshadow = "no_shadow", noborder = "no_border",
    noanim = "no_anim", nofocus = "no_focus", noinitialfocus = "no_initial_focus",
    dimaround = "dim_around", keepaspectratio = "keep_aspect_ratio",
    ignorezero = "ignore_alpha", ignorealpha = "ignore_alpha", stayfocused = "stay_focused",
    bordersize = "border_size", bordercolor = "border_color", idleinhibit = "idle_inhibit",
    maxsize = "max_size", minsize = "min_size", suppressevent = "suppress_event" }
  name = aliases[name] or name
  if name == "ignore_alpha" and rest == "" then return "ignore_alpha = 0" end
  if rest == "" or rest:lower() == "on" or rest:lower() == "true" then return name .. " = true" end
  if rest:lower() == "off" or rest:lower() == "false" then return name .. " = false" end
  if name == "size" or name == "move" or name == "max_size" or name == "min_size" then
    local a, b = rest:match("^(%S+)%s+(%S+)$")
    if a then
      local function num_or_str(x) return x:match("^%-?%d+%.?%d*$") and x or lua_string(x) end
      return name .. " = { " .. num_or_str(a) .. ", " .. num_or_str(b) .. " }"
    end
  end
  if rest:match("^%-?%d+%.?%d*$") then return name .. " = " .. rest end
  return name .. " = " .. lua_string(rest)
end

local function emit_window_rule(keyword, value)
  local parts = split_commas(value)
  local matches, effects = {}, {}
  if keyword == "windowrule" and #parts == 2 and not parts[2]:find(":") and not parts[1]:find("match:") then
    -- v1: "effect, regex"
    matches[#matches + 1] = "class = " .. lua_string(parts[2])
    effects[#effects + 1] = rule_effect(parts[1])
  else
    for _, part in ipairs(parts) do
      local mk, mv = part:match("^match:(%w+)%s+(.+)$")
      if not mk then mk, mv = part:match("^(%w+):(.+)$") end
      if mk and (mk == "class" or mk == "title" or mk == "initialclass" or mk == "initialtitle"
        or mk == "initial_class" or mk == "initial_title" or mk == "xwayland" or mk == "floating"
        or mk == "fullscreen" or mk == "pinned" or mk == "workspace" or mk == "tag") then
        local key = ({ initialclass = "initial_class", initialtitle = "initial_title" })[mk] or mk
        local v = trim(mv)
        if v == "1" or v == "0" or v == "true" or v == "false" then
          matches[#matches + 1] = key .. " = " .. ((v == "1" or v == "true") and "true" or "false")
        else
          matches[#matches + 1] = key .. " = " .. lua_string(v)
        end
      elseif part ~= "" then
        effects[#effects + 1] = rule_effect(part)
      end
    end
  end
  if #matches == 0 or #effects == 0 then return end
  add("hl.window_rule({ match = { " .. table.concat(matches, ", ") .. " }, " .. table.concat(effects, ", ") .. " })")
end

local function emit_layer_rule(value)
  local parts = split_commas(value)
  local matches, effects = {}, {}
  for _, part in ipairs(parts) do
    local mv = part:match("^match:namespace%s+(.+)$")
    if mv then
      matches[#matches + 1] = "namespace = " .. lua_string(trim(mv))
    end
  end
  if #matches == 0 and #parts == 2 then
    matches[#matches + 1] = "namespace = " .. lua_string(parts[2])
    effects[#effects + 1] = rule_effect(parts[1])
  else
    for _, part in ipairs(parts) do
      if not part:match("^match:") and part ~= "" then effects[#effects + 1] = rule_effect(part) end
    end
  end
  if #matches == 0 or #effects == 0 then return end
  add("hl.layer_rule({ match = { " .. table.concat(matches, ", ") .. " }, " .. table.concat(effects, ", ") .. " })")
end

-- --------------------------------------------------------------- parser --

local section = {}

local function handle_assignment(key, value, base_dir)
  value = substitute(value)
  local lkey = key:lower()
  local full = table.concat(section, ":")
  if lkey == "source" then
    local path = resolve_path(value, base_dir)
    if path:find("[%*%?]") then
      local pipe = io.popen("ls -1 " .. path .. " 2>/dev/null")
      if pipe then
        for match in pipe:lines() do
          dofile_conf(match) -- luacheck: ignore
        end
        pipe:close()
      end
    else
      dofile_conf(path)
    end
    return
  end
  if lkey == "exec-once" or lkey == "exec" or lkey == "execr-once" or lkey == "execr" then
    starts[#starts + 1] = value
    return
  end
  if lkey == "monitor" or lkey == "workspace" or lkey == "plugin" or lkey == "submap"
    or lkey == "permission" or lkey == "exec-shutdown" or lkey == "unbind" or lkey == "gesture" then
    return
  end
  if lkey == "env" then return emit_env(value) end
  if lkey == "bezier" then return emit_bezier(value) end
  if lkey == "animation" then return emit_animation(value) end
  if lkey:match("^bind%a*$") then return emit_bind(lkey, value) end
  if lkey == "windowrule" or lkey == "windowrulev2" then return emit_window_rule(lkey, value) end
  if lkey == "layerrule" then return emit_layer_rule(value) end
  if lkey == "blurls" then
    add("hl.layer_rule({ match = { namespace = " .. lua_string(trim(value)) .. " }, blur = true })")
    return
  end
  if section[1] == "device" then return end
  local path = (full ~= "" and (full .. ":") or "") .. key
  -- Options renamed by newer Hyprland releases.
  local renamed = {
    ["decoration:drop_shadow"] = "decoration:shadow:enabled",
    ["decoration:shadow_range"] = "decoration:shadow:range",
    ["decoration:shadow_render_power"] = "decoration:shadow:render_power",
    ["decoration:shadow_ignore_window"] = "decoration:shadow:ignore_window",
    ["decoration:shadow_offset"] = "decoration:shadow:offset",
    ["decoration:shadow_scale"] = "decoration:shadow:scale",
    ["decoration:col.shadow"] = "decoration:shadow:color",
    ["decoration:col.shadow_inactive"] = "decoration:shadow:color_inactive",
    ["decoration:blur_size"] = "decoration:blur:size",
    ["decoration:blur_passes"] = "decoration:blur:passes",
    ["decoration:blur_new_optimizations"] = "decoration:blur:new_optimizations",
    ["decoration:blur_xray"] = "decoration:blur:xray",
    ["decoration:blur_ignore_opacity"] = "decoration:blur:ignore_opacity",
  }
  if path == "decoration:blur" and (value == "true" or value == "false" or value == "1" or value == "0" or value == "yes" or value == "no") then
    path = "decoration:blur:enabled"
  end
  path = renamed[path] or path
  if path == "master:new_is_master" then
    path = "master:new_status"
    value = (lua_value(value) == "true") and "master" or "slave"
  end
  add("hl.config(" .. nested(path, lua_value(value)) .. ")")
end

function dofile_conf(path)
  if seen_files[path] then return end
  seen_files[path] = true
  local file = io.open(path, "r")
  if not file then
    add("-- hypr-switch: source not found: " .. path)
    return
  end
  local base_dir = dirname(path)
  for raw in file:lines() do
    local line = trim(strip_comment(raw))
    if line ~= "" then
      local var, vvalue = line:match("^%$([%w_]+)%s*=%s*(.-)%s*$")
      if var then
        vars[var] = substitute(vvalue)
      elseif line:match("^[%w_%.%-:]+%s*{$") or line:match("^[%w_%.%-:]+%s*{%s*$") then
        local name = line:match("^([%w_%.%-:]+)")
        section[#section + 1] = name
      elseif line == "}" then
        section[#section] = nil
      else
        local key, value = line:match("^([%w_%.%-:]+)%s*=%s*(.-)$")
        if key then handle_assignment(key, value, base_dir) end
        -- inline "name { key = value }" blocks
        local inline_name, body = line:match("^([%w_%.%-]+)%s*{(.*)}$")
        if inline_name and not key then
          section[#section + 1] = inline_name
          for k, v in body:gmatch("([%w_%.%-]+)%s*=%s*([^;]+)") do handle_assignment(k, v, base_dir) end
          section[#section] = nil
        end
      end
    end
  end
  file:close()
end

dofile_conf(input)

local out = assert(io.open(output, "w"))
out:write("-- Generated by hypr-switch (conf2lua) from " .. input .. "\n")
out:write("-- Lines Hyprland rejected are commented out with [hypr-switch: rejected].\n")
for _, line in ipairs(lines_out) do out:write(line, "\n") end
out:close()

if start_out then
  local s = assert(io.open(start_out, "w"))
  for _, command in ipairs(starts) do s:write(command, "\n") end
  s:close()
end

io.stdout:write(string.format("conf2lua: %d statements, %d autostart commands\n", #lines_out, #starts))
