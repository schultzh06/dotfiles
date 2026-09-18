-- schultzh06

require("animations")

hl.bind("PRINT", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | wl-copy]]))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd([[grim - | wl-copy]]))

------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/

hl.monitor({ output = "DP-2", mode = "1920x1080@120", position = "0x0", scale = 1 })
hl.monitor({ output = "eDP-1", mode = "preferred", position = "1920x0", scale = 1.67 })

---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = terminal .. " -e yazi"
local menu        = "pkill wofi || wofi --show drun"


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function ()
    local fetchMonitor = hl.get_monitor("DP-2") and "DP-2" or "eDP-1"
    hl.exec_cmd(terminal .. [[ -e sh -c 'fastfetch; exec zsh']], { monitor = fetchMonitor })
    hl.exec_cmd("gnome-keyring-daemon --start --components=pkcs11,secrets,ssh")
    hl.exec_cmd("qs")
    hl.exec_cmd("hyprpm reload -n")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Rosewater")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Rosewater")
hl.env("EDITOR", "nvim")
hl.env("VISUAL", "nvim")


-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Reads Theme.qml's `accent` color so the active/inactive border color
-- here doesn't have to be kept in sync by hand with the quickshell bar/dock
-- accent -- see ~/.config/quickshell/Theme.qml. `accent` is usually a bare
-- reference to one of the named palette colors (e.g. "accent: peach"), so
-- this resolves that name to its hex; falls back to lavender if the file
-- is missing or the format ever changes underneath this.
local function read_quickshell_accent()
    local path = os.getenv("HOME") .. "/.config/quickshell/Theme.qml"
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()

    local hex = content:match('property%s+color%s+accent%s*:%s*"#(%x+)"')
    if hex then return hex end

    local ref = content:match('property%s+color%s+accent%s*:%s*([%a][%w]*)')
    if not ref then return nil end

    return content:match('property%s+color%s+' .. ref .. '%s*:%s*"#(%x+)"')
end

-- Blends a hex color toward white by `amount` (0-1) -- used to make the
-- border a bit lighter than the raw accent, same treatment as the
-- Bibata-Modern-Rosewater cursor (also blended 40% toward white).
local function lighten_hex(hex, amount)
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    r = math.floor(r + (255 - r) * amount)
    g = math.floor(g + (255 - g) * amount)
    b = math.floor(b + (255 - b) * amount)
    return string.format("%02x%02x%02x", r, g, b)
end

local accentHex = read_quickshell_accent() or "b4befe"
local borderHex = lighten_hex(accentHex, 0.4)

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 2,
        gaps_out = 5,

        border_size = 2,

	col = {
    	    active_border   = { colors = {"rgba(" .. borderHex .. "4d)", "rgba(" .. borderHex .. "aa)", "rgba(" .. borderHex .. "4d)"}, angle = 45 },
    	    inactive_border = "rgba(" .. borderHex .. "4d)",
	},

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 5,
        rounding_power = 2,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 1.0,
        inactive_opacity = 0.9,

        dim_inactive = true,
        dim_strength = 0.06,
        
        shadow = {
            enabled      = true,          -- macOS glass reads flat without a soft shadow under it
            range        = 5,
            render_power = 3,
            color        = 0x99000000,    -- softer/more transparent than 0xee, tighter alpha falloff
        },

        blur = {
            enabled            = true,
            size               = 4,       -- 3 is too thin to read as "frosted", 8-10 is the macOS range
            passes             = 4,       -- more passes = smoother gradient falloff, this is the biggest lever
            noise              = 0.015,    -- macOS glass isn't perfectly smooth; adds the grain
            contrast           = 1.2,
            brightness         = .96,     -- keeps it from blowing out over light wallpapers/windows
            vibrancy           = 0.25,    -- your 0.1696 is too subtle, macOS saturates what's behind it more
            vibrancy_darkness  = 0.1,
            special            = true,
            popups             = true,
            new_optimizations  = true,
            -- Without this, a blurred floating window sitting over another
            -- blurred window has to blur an already-blurred result -- the
            -- cost compounds with every blurred layer stacked underneath.
            -- xray makes every blur sample straight from the clean
            -- desktop/wallpaper behind everything instead, so stacked
            -- blurred windows cost the same as just one.
            xray               = true,
        },

    },

    animations = {
        enabled = true,
    },
})

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
-- hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
-- hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
-- hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
-- hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
-- hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = 0,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = true, -- If true disables the random hyprland logo / anime girl background. :(
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    gestures = {
        workspace_swipe_invert = false,
    },
    input = {
        numlock_by_default = true,
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
	    scroll_factor = 0.5
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "right",
    action = function()
        hl.dispatch(hl.dsp.focus({ workspace = "+1" }))
    end
})

hl.gesture({
    fingers = 3,
    direction = "left",
    action = function()
        hl.dispatch(hl.dsp.focus({ workspace = "-1" }))
    end
})

hl.gesture({
  fingers = 4,
  direction = "up",
  action = function() hl.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+") end,
})

hl.gesture({
  fingers = 4,
  direction = "down",
  action = function() hl.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") end,
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier


-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd(terminal .. " --class kitty-float"))
local closeWindowBind = hl.bind(mainMod .. " + C", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("pkill wlogout || wlogout"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(terminal .. " --class yazi-float -e yazi"))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + S", hl.dsp.layout("togglesplit"))    -- dwindle only
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("overskride"))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("quickshell ipc call expo toggle"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("pkill -x qs; qs"))

hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("systemctl suspend"))

hl.bind("XF86PowerOff", hl.dsp.exec_cmd("pkill wlogout || wlogout"))

hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd('grim -g "$(slurp)" ~/Pictures/screenshots/$(date +%Y-%m-%d_%H-%M-%S).png'))

-- Move focus with mainMod + vim keys

for key, dir in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
    hl.bind(mainMod .. " + " .. key,          hl.dsp.focus({ direction = dir }))
    hl.bind(mainMod .. " + SHIFT + " .. key,  hl.dsp.window.swap({ direction = dir }))
    hl.bind(mainMod .. " + CTRL + " .. key,   hl.dsp.window.move({ direction = dir }))
end

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + Tab",         hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + grave",       hl.dsp.focus({ workspace = "previous" }))

hl.bind(mainMod .. " + comma",          hl.dsp.focus({ monitor = "-1" }))
hl.bind(mainMod .. " + period",         hl.dsp.focus({ monitor = "+1" }))
hl.bind(mainMod .. " + SHIFT + comma",  hl.dsp.workspace.move({ monitor = "-1" }))
hl.bind(mainMod .. " + SHIFT + period", hl.dsp.workspace.move({ monitor = "+1" }))

hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.pin())          -- floating, all workspaces
hl.bind(mainMod .. " + ALT + Tab", function()                    -- floating-friendly cycle
  hl.dispatch(hl.dsp.window.cycle_next())
  hl.dispatch(hl.dsp.window.bring_to_top())
end)

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + Z",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + ALT + mouse:272", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Blur for layer-shell surfaces (decoration.blur only covers windows by default)
hl.layer_rule({ name = "blur-waybar",  match = { namespace = "waybar" },        blur = true })
hl.layer_rule({ name = "blur-quickshell", match = { namespace = "quickshell" }, blur = true, ignore_alpha = 0.15 })
hl.layer_rule({ name = "blur-mako",    match = { namespace = "notifications" }, blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ name = "blur-wofi",    match = { namespace = "wofi" },          blur = true })
-- hl.layer_rule({ name = "blur-wlogout", match = { namespace = "logout_dialog" }, blur = true })
hl.layer_rule({ name = "blur-nwg-dock", match = { namespace = "nwg-dock" }, blur = true, ignore_alpha = 0.2 })

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- Floating windows

local floaters = {
    "^(imv)$",
    "^(mpv)$",
    "^(kitty-float)$",
    "^(yazi-float)$",
    "^(org.pulseaudio.pavucontrol)$",
    "^(nm-connection-editor)$",
    "^(blueman-manager)$",
    "^(io\\.github\\.kaii_lb\\.Overskride)$",
    "^(org\\.kde\\.polkit-kde-authentication-agent-1)$",
}

for _, c in ipairs(floaters) do
  hl.window_rule({
    match = { class = c },
    float = true,
    center = true,
  })
end

hl.on("config.reloaded", function()
  hl.config({
    plugin = {
      hyprbars = {
        enabled = true,
        bar_height = 26,
        bar_color = "rgba(1e1e2ebf)",
        bar_blur = true,
        inactive_button_color = "rgb(45475a)",
        bar_button_padding = 8,
        bar_buttons_alignment = "left",
        icon_on_hover = true,
      },
    },
  })

  -- macOS-style order: close, minimize, maximize (left to right)
  hl.plugin.hyprbars.add_button({
    bg_color = "rgb(f38ba8)", fg_color = "rgb(11111b)", size = 14, icon = "",
    action = [[hyprctl dispatch 'hl.dsp.window.close()']],
  })
  hl.plugin.hyprbars.add_button({
    bg_color = "rgb(f9e2af)", fg_color = "rgb(11111b)", size = 14, icon = "",
    action = [[hyprctl dispatch 'hl.dsp.window.movetoworkspacesilent("special:minimized")']],
  })
  hl.plugin.hyprbars.add_button({
    bg_color = "rgb(a6e3a1)", fg_color = "rgb(11111b)", size = 14, icon = "",
    action = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
  })
end)
