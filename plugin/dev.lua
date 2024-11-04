if os.getenv 'NDI_Debug' == 'true' then
  vim.keymap.set('n', '<leader>nr', "<cmd>:lua package.loaded['ndi'] = nil<cr><cmd>:lua require 'ndi'<cr>", { desc = 'Reload NDI plugin' })
  vim.keymap.set('n', '<leader>np', "<cmd>:lua print(vim.inspect(package.loaded['ndi']))<cr>", { desc = 'Print NDI package settings' })
end
