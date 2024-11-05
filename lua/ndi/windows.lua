local M = {}

---@param lsp_name string Name of the LSP we want to get info for.
---@type fun(lsp_name: string): nil
function M.lsp(lsp_name)
  require('ndi.utils').createWindow(
    lsp_name,
    "vim.lsp.get_clients { name = '\\?' }",
    { lsp_name },
    { 'name', 'id', 'config.filetypes', 'config.cmd', 'config' },
    false
  )
end

---@param plugin_name string Name of the plugin we want to get info for.
---@type fun(plugin_name: string): nil
function M.plugin(plugin_name)
  require('ndi.utils').createWindow(plugin_name, "package.loaded['\\?']", { plugin_name }, {}, true)
end

return M
