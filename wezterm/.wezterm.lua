local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.enable_tab_bar = false

config.keys = {
  {key="Enter", mods="SHIFT", action=wezterm.action{SendString="\x1b\r"}},
}

return config
