local M = {}

---@param lsp_name string Name of the LSP we want to get info for.
---@type fun(lsp_name: string): nil
function M.lsp(lsp_name)
  require('ndi.utils').createWindow {
    name = lsp_name,
    command = "vim.lsp.get_clients { name = '\\?' }",
    command_variables = { lsp_name },
    ident_keys = { 'name', 'id', 'config.filetypes', 'config.cmd', 'config' },
    print_all_output = false,
  }
end

---@param plugin_name string Name of the plugin we want to get info for.
---@type fun(plugin_name: string): nil
function M.plugin(plugin_name)
  require('ndi.utils').createWindow {
    name = plugin_name,
    command = "package.loaded['\\?']",
    command_variables = { plugin_name },
    ident_keys = nil,
    print_all_output = true,
  }
end

return M
