-- Loaded from %USERPROFILE%\.wezterm.lua. Drop images into E:\wallpapers to get a random
-- dimmed background each time a window opens.
local wezterm = require 'wezterm'
local config = wezterm.config_builder()
-- %USERPROFILE%\.wezterm.lua only dofile()s this file, so watch it for live reload too.
wezterm.add_to_config_reload_watch_list('E:/projects/_claude-config/wezterm/wezterm.lua')

config.default_domain = 'WSL:Ubuntu'
config.wsl_domains = {
  {
    name = 'WSL:Ubuntu',
    distribution = 'Ubuntu',
    default_cwd = '/home/harry/projects',
    -- Open straight into herdr (workspace manager for coding agents; re-attaches to its server).
    default_prog = { 'bash', '-lc', 'herdr' },
  },
}

-- Maple Mono is installed per-user; this WezTerm build only scans system fonts by default.
config.font_dirs = { wezterm.home_dir .. '/AppData/Local/Microsoft/Windows/Fonts' }
config.font = wezterm.font_with_fallback { 'Maple Mono NF CN', 'Consolas' }
config.font_size = 12
config.color_scheme = 'Catppuccin Mocha'
config.window_padding = { left = 8, right = 8, top = 6, bottom = 4 }
-- No Windows title bar: window buttons live in a slim, always-visible tab bar whose empty
-- area drags the window. herdr draws its own tabs and workspace list inside.
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.integrated_title_button_style = 'Windows'
config.hide_tab_bar_if_only_one_tab = false
-- The fancy tab bar draws full-size Windows caption buttons (the retro one shrinks them to dots).
config.use_fancy_tab_bar = true
config.tab_max_width = 32
config.window_frame = {
  font = wezterm.font { family = 'Maple Mono NF CN', weight = 'Medium' },
  font_size = 10.5,
  active_titlebar_bg = '#11111b',
  inactive_titlebar_bg = '#11111b',
  button_fg = '#cdd6f4',
  button_bg = '#11111b',
  button_hover_fg = '#11111b',
  button_hover_bg = '#cba6f7',
}
-- The WSL process shows up as "wslhost.exe"; give the tab a readable name instead.
wezterm.on('format-tab-title', function(tab)
  return '  ' .. (tab.tab_index + 1) .. '  Claude Workspace  '
end)
config.colors = {
  tab_bar = {
    background = '#11111b',
    active_tab = { bg_color = '#1e1e2e', fg_color = '#cba6f7' },
    inactive_tab = { bg_color = '#11111b', fg_color = '#6c7086' },
    inactive_tab_hover = { bg_color = '#181825', fg_color = '#cdd6f4' },
    new_tab = { bg_color = '#11111b', fg_color = '#6c7086' },
    new_tab_hover = { bg_color = '#181825', fg_color = '#cdd6f4' },
  },
}
config.default_cursor_style = 'BlinkingBar'

-- Paste: Ctrl+V is passed through to the app, because Claude Code reads the Windows
-- clipboard itself and pastes both text and images (screenshots) that way.
-- Ctrl+Shift+V (WezTerm default) pastes text anywhere, e.g. in a plain shell or micro.
-- Right-click pastes only when the app isn't using the mouse; inside herdr, right-click
-- belongs to herdr's context menu (split/close panes) and Shift+right-click pastes.
config.mouse_bindings = {
  { event = { Down = { streak = 1, button = 'Right' } }, mods = 'NONE', action = wezterm.action.PasteFrom 'Clipboard' },
  { event = { Down = { streak = 1, button = 'Right' } }, mods = 'SHIFT', action = wezterm.action.PasteFrom 'Clipboard', mouse_reporting = true },
}

-- The herdr server keeps sessions alive, so closing a window never loses work: skip the prompt.
config.window_close_confirmation = 'NeverPrompt'
config.initial_cols = 200
config.initial_rows = 52

local images = {}
for _, ext in ipairs { 'png', 'jpg', 'jpeg', 'webp' } do
  for _, f in ipairs(wezterm.glob('E:/wallpapers/*.' .. ext)) do
    table.insert(images, f)
  end
end

if #images > 0 then
  config.background = {
    {
      source = { File = images[math.random(#images)] },
      hsb = { brightness = 0.18 },
      horizontal_align = 'Right',
      vertical_align = 'Bottom',
      attachment = { Parallax = 0.1 },
    },
    { source = { Color = '#1e1e2e' }, width = '100%', height = '100%', opacity = 0.55 },
  }
end
-- Fully opaque: see-through windows let other apps' text bleed into the terminal.
config.window_background_opacity = 1.0

return config
