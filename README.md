# dotfiles

Personal dotfiles for an Arch Linux + Hyprland desktop, with a hand-built
[Quickshell](https://quickshell.org) bar/dock/workspace-overview styled in
Catppuccin Mocha, and a mostly-macOS-inspired UI direction (auto-hiding dock,
magnification, Mission Control-style workspace overview).

Tracked with a [bare git repo](https://www.atlassian.com/git/tutorials/dotfiles)
rooted at `~` — see **Install** below.

## What's here

| Path | Purpose |
| --- | --- |
| `.config/hypr/` | Hyprland config (native Lua config via `hyprland.lua`, not stock hyprlang), animations, hyprlock, hypridle, hyprpaper |
| `.config/quickshell/` | The actual bar + dock + workspace overview ("Expo") — see its own `CLAUDE.md` for architecture notes |
| `.config/waybar/` | Earlier waybar config Quickshell was modeled on/replaces — kept for reference, not currently active |
| `.config/mako/` | Notifications |
| `.config/wofi/` | App launcher |
| `.config/wlogout/` | Power menu (custom-recolored icons) |
| `.config/kitty/` | Terminal |
| `.config/nvim/` | Neovim (native `vim.pack`, no plugin manager) |
| `.config/yazi/` | File manager |
| `.config/btop/`, `.config/cava/` | System monitor, audio visualizer |
| `.config/starship.toml` | Shell prompt |
| `.zshrc`, `.bashrc`, `.zprofile`, `.bash_profile`, `.tmux.conf`, `.vimrc`, `.gitconfig` | Shell/tooling config |

Deliberately **not** tracked: anything under `.ssh/`, `.gnupg/`, browser
profiles, app auth/session state, caches, or generated plugin installs (e.g.
`nvim`'s plugin dir, `pnpm`/`npm`/`cargo` caches). See the exclude reasoning
in this repo's history if you're extending the tracked set.

## Notable custom bits

- **Quickshell Expo** (`SUPER + Space`) — a Mission Control-style overview:
  every workspace shown as a scaled mini-desktop with live window previews.
  Press a number (0-9) while it's open to jump straight to that workspace.
- **Auto-hiding dock** with macOS-style cursor-following magnification,
  right-click app menus with live window thumbnails, and pin/unpin.
- **`SUPER + SHIFT + R`** — quick-restart Quickshell (`pkill -x qs; qs`)
  without restarting Hyprland itself.

## Install

Requires: `hyprland`, `hyprland-lua` (native Lua config support), `quickshell`,
`kitty`, `mako`, `wofi`, `wlogout`, `hyprpaper`, `hypridle`, `hyprlock`,
`hyprpm`, `nvim`, `yazi`, `zathura`, `btop`, `cava`, `starship`, `zoxide`,
`fzf`, `eza`, `bat`, `tmux`, `grim`, `slurp`, `wl-clipboard`, `playerctl`,
`brightnessctl`, `wireplumber`/`wpctl`, `fastfetch`. (Double-check this list
against what you actually have installed before relying on it — assembled
from what these configs reference, not a verified package manifest.)

```bash
git clone --bare <this-repo-url> "$HOME/.dotfiles"
alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

# back up anything that would conflict, then:
dotfiles checkout

dotfiles config --local status.showUntrackedFiles no
```

Add the `dotfiles` alias to your shell rc (`.zshrc`/`.bashrc`) to keep using
it after this session.

## License

MIT — see [LICENSE](LICENSE). Note the vendored yazi flavor under
`.config/yazi/flavors/catppuccin-mocha.yazi/` carries its own license from
upstream.
