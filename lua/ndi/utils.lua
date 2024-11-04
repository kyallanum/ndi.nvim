local M = {}

--- Adds variables to the command properly.
--- Transforms to a return statement so it gets returned by loadstring properly.
---@param command string Command needed to be massaged
---@param command_variables table|nil if there are any of these... replace instance of \\? with variable value
local function massage_command(command, command_variables)
  local contains_variables = string.match(command, '%\\%?') ~= nil
  if type(command_variables) == 'table' and #command_variables > 0 and contains_variables then
    for _, v in ipairs(command_variables) do
      command = string.gsub(command, '%\\%?', v, 1)
    end
  end

  command = 'return ' .. command
  return command
end

--- A helper function that attempts to get a nested table using dot notation.
--- We return the keys later for manipulation of the table at this sub-key
---@param tbl table Our table we are searching
---@param path string our nested table path in dot notation "sub_table.sub_sub_table"
local function get_nested_value(tbl, path)
  local keys = {}

  -- we split by path and add to keys
  for key in path:gmatch '[^%.]+' do
    table.insert(keys, key)
  end

  local current = tbl
  for _, key in ipairs(keys) do
    if current == nil then
      return nil
    end
    current = current[key]
  end
  return keys, current
end

--- Creates a window with the output of "command". Usage:
---@param name string Name of the window to be created
---@param command string Command used to get the desired information. Use \\? for variables.
---@param command_variables table|nil Variables used in reference to "command" parameter nil for non.
---@param ident_keys table Table of keys that need to be extracted from the resulting table.
---@param print_all_output boolean Whether to print all output in the window.
function M.createWindow(name, command, command_variables, ident_keys, print_all_output)
  command = massage_command(command, command_variables)

  -- We deepcopy so that removing entries from the table does not break anything
  local command_output = vim.deepcopy(loadstring(command)())

  -- Create a temporary buffer to show the command output
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = math.floor(vim.o.columns * 0.75),
    height = math.floor(vim.o.lines * 0.90),
    col = math.floor(vim.o.columns * 0.125),
    row = math.floor(vim.o.lines * 0.05),
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. (name:gsub('^%l', string.upper)) .. ' ',
    title_pos = 'center',
  })

  local lines = {}
  for i, current_output in ipairs(command_output) do
    if i > 1 then
      table.insert(lines, string.rep('-', 80))
    end
    for _, v in ipairs(ident_keys) do
      -- We loop through each ident_key and 1. Add an entry in the table with the appropriate info
      -- 2. We remove that key from its parent table.
      local current_line = { v:gsub('^%l', string.upper) .. ': ' }
      local keys, resolved_value = get_nested_value(current_output, v)

      if type(resolved_value) == 'table' then
        local current_line_value = vim.split(vim.inspect(resolved_value), '\n')
        vim.list_extend(current_line, current_line_value)
        vim.list_extend(current_line, { ' ' })
      else
        current_line[1] = current_line[1] .. resolved_value
      end

      vim.list_extend(lines, current_line)

      local value_to_remove = current_output
      for key = 1, #keys - 1 do
        value_to_remove = value_to_remove[keys[key]]
      end
      value_to_remove[keys[#keys]] = nil
    end

    if print_all_output then
      table.insert(lines, 'Full output: ')
      local all_output = vim.split(vim.inspect(current_output), '\n')
      vim.list_extend(lines, all_output)
    end
  end

  -- Set the lines in buf
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Set buf options
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = 'lua'
  vim.bo[buf].bh = 'delete'

  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>:q<cr>', { noremap = true, silent = true })
end

return M
