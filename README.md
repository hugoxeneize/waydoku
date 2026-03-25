# waydoku

a sudoku game inside [waywall](https://github.com/tesselslate/waywall), the wayland compositor for minecraft speedrunning.

heavily inspired by [waywordle](https://github.com/arjuncgore/waywordle) by gore — a lot of the key capture pattern and plugin structure comes from that project. go check it out!

---

## how it looks

press your hotkey and a sudoku grid appears on top of waywall. move around with `wasd`, fill in numbers, get 3 wrong and it's game over. press the hotkey again to hide

## installation

**1. clone the repo into your waywall config folder**

```bash
git clone https://github.com/hugoxeneize/waydoku ~/.config/waywall/waydoku
```

if you use a profile subfolder (like `hugoxeneizeasd`), clone it there instead:

```bash
git clone https://github.com/hugoxeneize/waydoku ~/.config/waywall/yourprofile/waydoku
```

**2. add one line to your waywall config**

if you have an `extras.lua`, add it there:

```lua
-- extras.lua
return function(config)
    require("waydoku.init").setup(config)
end
```

if you use a profile subfolder:

```lua
require("yourprofile.waydoku.init").setup(config)
```

or just add it to your main `init.lua` before `return config`:

```lua
require("waydoku.init").setup(config)

return config
```

---

## configuration

at the top of `init.lua` there's a `cfg` table you can edit:

```lua
local cfg = {
    x         = 50,       -- horizontal position on screen (pixels)
    y         = 50,       -- vertical position on screen (pixels)
    size      = 3,        -- text size (bigger = larger grid)
    start_key = "F8",     -- hotkey to toggle waydoku on/off
    difficulty = "medium" -- "easy", "medium" or "hard"
}
```

tweak `x` and `y` to move the grid wherever you want on your screen. `size` controls how big everything is — 3 is a good default for 1366x768.

---

## how to play

| key | action |
|-----|--------|
| `F8` | toggle waydoku on/off (or whatever you set as `start_key`) |
| `w a s d` | move cursor around the grid |
| `1` - `9` | place a number in the selected cell |
| `0` or `backspace` | erase the selected cell |
| `r` | start a new game |

- numbers in **white** are given clues (can't be changed)
- numbers in **cyan** are your correct answers
- numbers in **red** are wrong
- **yellow** is your current cursor position
- **3 mistakes = game over** — the grid turns red and only `r` works

---

## difficulty

| difficulty | clues given |
|------------|-------------|
| easy | 38 |
| medium | 30 |
| hard | 23 |

## credits

- [waywordle](https://github.com/arjuncgore/waywordle) by arjuncgore — key capture pattern and plugin structure
- [waywall](https://github.com/tesselslate/waywall) by tesselslate — the compositor that makes all of this possible
