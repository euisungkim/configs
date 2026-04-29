local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.font = wezterm.font('Comic Shanns', { weight = 'Regular' })
config.font_size = 16.0
config.freetype_load_target = 'Light'
config.freetype_render_target = 'HorizontalLcd'

config.enable_tab_bar = false

config.keys = {
  {key="Enter", mods="SHIFT", action=wezterm.action{SendString="\x1b\r"}},
}

return config
