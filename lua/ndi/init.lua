local M = {}

M.utils = require 'ndi.utils'
M.windows = require 'ndi.windows'

---A function to get configuration information for an LSP.
---@param opts { fargs: string[]; bang: boolean; }
M.get_lsp = function(opts)
  if opts.bang then
    M.utils.select_via_fzf('vim.lsp.get_clients {}', 'name', function(selected_lsp)
      if selected_lsp then
        M.windows.lsp(selected_lsp)
      end
    end)
  elseif opts.fargs[1] ~= nil then
    M.windows.lsp(opts.fargs[1])
  else
    vim.ui.input({ prompt = 'Enter LSP Client name: ' }, M.windows.lsp)
  end
end

---A function to get the configuration information for a plugin.
---@param opts { fargs: string[]; bang: boolean; }
M.get_plugin = function(opts)
  if opts.bang then
    M.utils.select_via_fzf('package.loaded', nil, function(selected_plugin)
      if selected_plugin then
        M.windows.plugin(selected_plugin)
      end
    end)
  elseif opts.fargs[1] ~= nil then
    M.windows.plugin(opts.fargs[1])
  else
    vim.ui.input({ prompt = 'Enter the plugin table: ' }, M.windows.plugin)
  end
end

return M
