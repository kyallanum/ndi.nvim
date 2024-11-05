-- Load commands
vim.api.nvim_create_user_command('GetLSPClientInfo', require('ndi').get_lsp, { nargs = '?', bang = true })
vim.api.nvim_create_user_command('GetPluginInfo', require('ndi').get_plugin, { nargs = '?', bang = true })
