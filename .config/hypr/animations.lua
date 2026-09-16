-- ══ Curves ═══════════════════════════════════════════════════════

-- beziers
hl.curve("easeOutExpo",   { type = "bezier", points = { {0.16, 1.00}, {0.30, 1.00} } })
hl.curve("easeOutCirc",   { type = "bezier", points = { {0.00, 0.55}, {0.45, 1.00} } })
hl.curve("snap",          { type = "bezier", points = { {0.20, 1.00}, {0.20, 1.00} } })

-- springs: lower dampening = more overshoot; lower mass = faster settle
hl.curve("easy",   { type = "spring", mass = 1.0, stiffness = 238, dampening = 24 })
hl.curve("snappy", { type = "spring", mass = 0.6, stiffness = 320, dampening = 22 })
hl.curve("bouncy", { type = "spring", mass = 1.0, stiffness = 260, dampening = 16 })
hl.curve("gentle", { type = "spring", mass = 1.2, stiffness = 150, dampening = 22 })

hl.curve("almostLinear", { type = "bezier", points = { {0.50, 0.50}, {0.75, 1.00} } })
hl.curve("linear",       { type = "bezier", points = { {0.00, 0.00}, {1.00, 1.00} } })
hl.curve("quick",        { type = "bezier", points = { {0.15, 0.00}, {0.10, 1.00} } })

-- ══ Global — must come first ═════════════════════════════════════
hl.animation({ leaf = "global", enabled = true, speed = 5, bezier = "easeOutExpo" })

-- ══ Windows ══════════════════════════════════════════════════════
hl.animation({ leaf = "windows",     enabled = true, speed = 4.5, spring = "snappy" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 4.0, spring = "bouncy", style = "popin 80%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 1.8, bezier = "easeOutExpo", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4.0, spring = "easy" })

-- ══ Workspaces ═══════════════════════════════════════════════════
hl.animation({ leaf = "workspaces",       enabled = true, speed = 5, spring = "gentle", style = "slidefade 20%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, spring = "gentle", style = "slidefadevert -10%" })

-- ══ Fades ════════════════════════════════════════════════════════
hl.animation({ leaf = "fade",       enabled = true, speed = 3.0, bezier = "snap" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 2.5, bezier = "easeOutExpo" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 1.6, bezier = "easeOutExpo" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 2.0, bezier = "easeOutCirc" })
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 3.0, bezier = "easeOutExpo" })
hl.animation({ leaf = "fadeDim",    enabled = true, speed = 3.0, bezier = "easeOutExpo" })

-- ══ Layers — waybar, wofi, wlogout, mako ═════════════════════════
hl.animation({ leaf = "layers",        enabled = true, speed = 3.5, spring = "snappy", style = "slide" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 3.5, spring = "easy", style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.8, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2.0, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.4, bezier = "almostLinear" })

-- ══ Borders ══════════════════════════════════════════════════════
hl.animation({ leaf = "border",      enabled = true, speed = 6, bezier = "easeOutExpo" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "linear" })

-- Rotating gradient border. Forces a full-refresh-rate redraw forever:
-- kills VRR, spins your fans, eats battery. Enable knowingly.
-- hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "linear", style = "loop" })

-- ══ Misc ═════════════════════════════════════════════════════════
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, spring = "easy" })

hl.layer_rule({
    name      = "wlogout-no-bounce",
    match     = { namespace = "logout_dialog" },
    animation = "fade",
})

hl.layer_rule({
    name      = "expo-fade",
    match     = { namespace = "quickshell-expo" },
    animation = "fade",
})

hl.layer_rule({
    name      = "wofi-slide-out",
    match     = { namespace = "wofi" },
    animation = "slide",
})

