local M = {}

M.custom = {}
M.utils = require 'ndi.utils'
M.windows = require 'ndi.windows'

---A function to get configuration information for an LSP.
---@param opts { fargs: string[]; bang: boolean; }
M.get_lsp = function(opts)
  if opts.bang then
    M.utils.select_via_fzf {
      command = 'vim.lsp.get_clients {}',
      extract_key = 'name',
      prompt = 'LSP Client > ',
      callback = function(selected_lsp)
        if selected_lsp then
          M.windows.lsp(selected_lsp)
        end
      end,
    }
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
    M.utils.select_via_fzf {
      command = 'package.loaded',
      extract_key = nil,
      prompt = 'Plugin > ',
      callback = function(selected_plugin)
        if selected_plugin then
          M.windows.plugin(selected_plugin)
        end
      end,
    }
  elseif opts.fargs[1] ~= nil then
    M.windows.plugin(opts.fargs[1])
  else
    vim.ui.input({ prompt = 'Enter the plugin table: ' }, M.windows.plugin)
  end
end

---Setup function. Takes arguments in the following form to allow for output of your own commands to be displayed.
---{
---  {
---    name = "My LSP",                                 --- Name of the window
---    command_name = "GetLSPClientInfo"                --- The command we want to type in the command bar.
---    command = "vim.lsp.get_clients { name = "\\?" }, --- Command who's output we want to print in the window
---    fzf_command = "vim.lsp.get_clients {}",          --- Name of command for fzf source.
---    fzf_key = 'name',                                --- The key that fzf will use for source.
---                                                         Nil for a table that is a list
---    ident_keys = { "id", "name", "config" ... }      --- Keys from the table that we can extract
---                                                         to make its own field in the window. Accepts
---                                                         the format: "key.sub_key.sub_sub_key".
---    print_all_output = false                         --- Whether to print all remaining output from command
---                                                     --- after extracting keys.
---  }
---}
---@param opts { name: string; command_name: string; command: string; fzf_command: string; fzf_key: string; fzf_prompt: string|nil; ident_keys: string[]; print_all_output: boolean; }[]
M.setup = function(opts)
  for i, window in ipairs(opts) do
    M.custom[i] = {}

    M.custom[i].name = window.name

    ---@param name string
    M.custom[i].create = function(name)
      require('ndi.utils').createWindow { name, window.command, { name }, window.ident_keys, window.print_all_output }
    end

    ---@param local_opts { fargs: string[]; bang: boolean; }
    M.custom[i].call_create = function(local_opts)
      if local_opts.bang then
        M.utils.select_via_fzf {
          command = window.fzf_command,
          extract_key = window.fzf_key,
          prompt = window.fzf_prompt,
          callback = function(selected)
            if selected then
              M.custom[i].create(selected)
            end
          end,
        }
      elseif local_opts.fargs[1] ~= nil then
        M.custom[i].create(local_opts.fargs[1])
      else
        vim.ui.input({ prompt = 'Enter your input: ' }, M.custom[i].create)
      end
    end

    vim.api.nvim_create_user_command(window.command_name, M.custom[i].call_create, { nargs = '?', bang = true })
  end
end

return M
