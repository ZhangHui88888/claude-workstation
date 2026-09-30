# claude-workstation

My Claude Code workstation on Windows 11 + WSL2: WezTerm opens straight into
[herdr](https://github.com/herdrdev/herdr) (a workspace manager for coding agents), with a file-tree
sidebar, diff review, yazi, lazygit and micro around Claude Code running in WSL.

These are dotfiles: every tool is someone else's project; this repo only holds the configuration
and small scripts that tie them together. Everything is symlinked from here, so this repo is the
single place to edit.

## Layout

| Path | Used by |
|---|---|
| `CLAUDE.md` | WSL `~/.claude/CLAUDE.md` (symlink). Imports the machine-only `~/.claude/CLAUDE.local.md` |
| `CLAUDE.local.example.md` | template for that machine-only file (paths, services, secret folders) |
| `commands/` | WSL `~/.claude/commands` (symlink) |
| `hooks/` | WSL `~/.claude/settings.json` hooks (SessionStart, Notification, Stop) |
| `herdr/config.toml` | WSL `~/.config/herdr/config.toml` (file symlink; the dir itself must stay on ext4 for the socket) |
| `wezterm/wezterm.lua` | Windows `%USERPROFILE%\.wezterm.lua` (dofile); WezTerm opens straight into herdr |
| `yazi/yazi.toml` | WSL `~/.config/yazi/yazi.toml` (symlink); yazi is the Alt+F popup. Markdown preview uses the official `piper.yazi` plugin + glow; Typora editing goes through `wslview` (Windows default app for `.md` = Typora) |
| `bin/mdread` | WSL `~/.local/bin/` (symlink): full-window Markdown reader used by yazi |
| `micro/settings.json` | WSL `~/.config/micro/settings.json` |

File tree: community plugin [herdr-sidebar](https://github.com/alexarthurs/herdr-sidebar) (auto-opens in
every workspace; Alt+S). Change review: [herdr-file-viewer](https://github.com/smarzban/herdr-file-viewer)
(Alt+V). Both installed with `herdr plugin install`; their settings live in their own UI.
Sidebar extras outside this repo: `~/.local/state/herdr/plugins/herdr-sidebar/editor-command.txt` = `micro`,
and `~/.local/bin/xdg-open` -> `/usr/bin/wslview` so "Open with Default App" reaches Windows.

`cw [dir]` in WSL opens or focuses the herdr workspace for a project.
Projects opt into the Stop-hook check with an executable `.claude/verify.sh`.
Background images: put them in `E:\wallpapers`.

## Status

Paths still assume my machine (`E:\projects\_claude-config`, WSL user `harry`). A one-shot
installer (`install.ps1` + `install.sh`) is planned; until then, set it up by hand from the table above.
