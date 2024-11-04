local M = {}

M.setup = function(opts)
  print('Options:', opts)
end

---A function to get configuration information for an LSP.
---@param opts { fargs: string[]; bang: boolean; }
M.lsp = function(opts)
  -- if opts.bang then
  --   select_lsp_via_fzf()
  -- elseif opts.fargs[1] ~= nil then
  --   require
end

print 'NDI Loaded'

return M
