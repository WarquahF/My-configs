-- Tiling feel (Liquid Glass desktop).
--
-- Owns how the dwindle layout *moves*: tiles that settle into place instead
-- of teleporting, a border that reacts when focus lands, and a focus glow
-- that follows the wallpaper. Your animations.lua and decorations.lua keep
-- owning the static look -- gaps, rounding, opacity, blur, border colours.
-- This file is required after them and overrides only the motion, so
-- deleting the require line restores your settings on the next reload.
--
-- Deliberately motion-first. This is Intel UHD G4 driving 1920x1080 with
-- decoration.blur.passes = 4, so there is little per-frame headroom left:
-- everything below costs only while something is actually moving. The two
-- effects that would cost every frame are handled accordingly --
-- borderangle runs "once" per focus change rather than "loop", and
-- decoration.motion_blur is left off (flip it on at the bottom if you want
-- it and can spare the frames).

local ok, palette = pcall(require, "config.matugen")
local accent = (ok and type(palette) == "table" and palette.accent) or "0xff89b4fa"

-- Curves -----------------------------------------------------------------
-- `settle` overshoots a little and comes back: that slight overshoot is
-- what reads as weight, and is the difference between a tile that moved and
-- a tile that was simply redrawn somewhere else.
hl.curve("settle", { type = "spring", mass = 1, stiffness = 400, dampening = 26 })
-- Fast out of the gate, long tail. Used for anything that should feel
-- immediate but not abrupt.
hl.curve("snappy", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1 } } })

-- Window motion -----------------------------------------------------------
-- New tiles scale up into their slot and closing reverses it, so a window
-- appears where it belongs instead of flying in from a screen edge.
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.5, bezier = "snappy", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "snappy", style = "popin 85%" })

-- The one that actually makes tiling feel alive: whenever the layout
-- reflows -- opening, closing, swapping, resizing a neighbour -- every
-- affected tile springs to its new geometry instead of snapping.
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, spring = "settle" })

-- Focus reactions ---------------------------------------------------------
-- Border colour eases between active and inactive rather than flicking.
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "snappy" })
-- One gradient sweep when focus lands. "once", not "loop": a looping
-- borderangle repaints forever and would sit on the GPU (and the battery)
-- even on an idle desktop.
hl.animation({ leaf = "borderangle", enabled = true, speed = 2.5, bezier = "easeOutQuint", style = "once" })
-- Glow fades with focus instead of popping on.
hl.animation({ leaf = "fadeGlow", enabled = true, speed = 4, bezier = "snappy" })

-- Layer surfaces (rofi, wlogout, the wallpaper filmstrip) fade rather than
-- appear, which matters because they sit over blurred glass.
hl.animation({ leaf = "layers", enabled = true, speed = 4, bezier = "snappy", style = "fade" })

-- Layout + focus glow -----------------------------------------------------
hl.config({
    general = {
        -- Dragged floating windows catch on their neighbours and the screen
        -- edge, so "roughly there" lands aligned.
        snap = {
            enabled = true,
            window_gap = 12,
            monitor_gap = 12,
        },
    },
    dwindle = {
        -- Keep the split orientation a container was created with, so
        -- closing a window does not silently re-orient its siblings.
        preserve_split = true,
        -- Resize the edge you are pulling rather than always the same one.
        smart_resizing = true,
    },
    decoration = {
        -- The focused tile is lit in the wallpaper's accent colour. This is
        -- the wallpaper connection: waybar/scripts/wallpaper-theme.sh pushes
        -- the new accent here on every wallpaper change, so scrolling
        -- wallpapers re-lights the desktop live. Rendered with the window,
        -- like the shadow that is already on -- not a per-frame pass.
        glow = {
            enabled = true,
            range = 12,
            render_power = 2,
            color = accent,
        },
    },
})

-- Optional, costs real frames on this GPU -- uncomment to try:
-- hl.config({ decoration = { motion_blur = { enabled = true, samples = 5 } } })
