--- Adds variables to the command properly.
--- Transforms to a return statement so it gets returned by loadstring properly.
---@param command string Command needed to be massaged
---@param command_variables table|nil if there are any of these... replace instance of \\? with variable value
---@type fun(command, command_variables): string
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
---@type fun(tbl, path): string[]|nil, string|nil
local function get_nested_value(tbl, path)
  local keys = {}

  -- we split by path and add to keys
  for key in path:gmatch '[^%.]+' do
    table.insert(keys, key)
  end

  local current = tbl
  for _, key in ipairs(keys) do
    if current == nil then
      return nil, nil
    end
    current = current[key]
  end
  return keys, current
end

--- A helper function that determines the type of table. True for list, false for map.
---@param tbl table The table we are testing
---@type fun(tbl): boolean
local function is_list(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end

  return count == #tbl
end

--- A helper function that performs a safe deepcopy of a table.
---@param tbl table The table we are performing the copy on
---@type fun(tbl): table
local function table_safe_copy(tbl)
  local filtered_table = {}
  for key, value in pairs(tbl) do
    if type(value) == 'table' then
      local success, copied_value = pcall(vim.deepcopy, value)
      if success then
        filtered_table[key] = copied_value
      end
    else
      filtered_table[key] = type(value)
    end
  end

  return filtered_table
end

local M = {}

---Creates a window with the output of "command".
---@param name string Name of the window to be created
---@param command string Command used to get the desired information. Use \\? for variables.
---@param command_variables table|nil Variables used in reference to "command" parameter nil for non.
---@param ident_keys table Table of keys that need to be extracted from the resulting table. These can be in the format of "key.subkey.subkey..."
---@param print_all_output boolean Whether to print all output in the window.
---@type fun(name: string, command: string, command_variables: table, ident_keys: table, print_all_output: boolean): nil
function M.createWindow(name, command, command_variables, ident_keys, print_all_output)
  command = massage_command(command, command_variables)
  print(command)

  -- We deepcopy so that removing entries from the table does not break anything
  local command_output = loadstring(command)()
  print(command_output)
  if type(command_output) ~= 'table' then
    print 'Return type of command is not table'
    return
  end

  local output_table = table_safe_copy(command_output)

  if is_list(output_table) ~= true then
    output_table = { output_table }
  end

  -- Create a temporary buffer to show the command output
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_open_win(buf, true, {
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
  for i, current_output in ipairs(output_table) do
    print(current_output)
    if i > 1 then
      table.insert(lines, string.rep('-', 80))
    end

    for _, v in ipairs(ident_keys) do
      -- We loop through each ident_key and 1. Add an entry in the table with the appropriate info
      -- 2. We remove that key from its parent table.
      local current_print_section = { v:gsub('^%l', string.upper) .. ': ' }
      local keys, nested_key = get_nested_value(current_output, v)

      if nested_key == nil or keys == nil then
        print('Nested Key: ' .. v .. ' not found. Please double-check the table you want to get info from')
        return
      end

      if type(nested_key) == 'table' then
        local current_line_value = vim.split(vim.inspect(nested_key), '\n')
        vim.list_extend(current_print_section, current_line_value)
        vim.list_extend(current_print_section, { '' })
      else
        current_print_section[1] = current_print_section[1] .. nested_key
      end

      vim.list_extend(lines, current_print_section)

      local value_to_remove = current_output

      -- With this, we get to the parent table of the extracted value
      for key = 1, #keys - 1 do
        value_to_remove = value_to_remove[keys[key]]
      end
      -- ... and then remove it
      value_to_remove[keys[#keys]] = nil
    end

    -- Take the remainder of the output and print at the end if applicable
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

---A method to take some command, and fzf some key from the resulting string[].
---The callback function should look like:
---function(selected)
---  if selected_lsp then
---    call_func_to_show_window_for_resource()
---  end
---end
---@type fun(command: string, extract_key: string|nil, callback: fun(selected: string|nil)): nil
function M.select_via_fzf(command, extract_key, callback)
  --- the following is for LSPs, keeping as an example of a command that can be used for a fzf source
  -- local bufnr = vim.api.nvim_get_current_buf(); local clients = vim.lsp.get_clients { bufnr = bufnr }
  command = 'return ' .. command

  print(command)
  local command_output = loadstring(command)()
  if type(command_output) ~= 'table' then
    print 'Command did not create output of type: table. Please double-check your command'
    print(command_output)
    return
  end

  local output_table = table_safe_copy(command_output)
  local keys = {}

  if is_list(output_table) then
    if not extract_key then
      print 'extract_key is nil. Please specify the extract_key for a list type'
    end
    for index, _ in ipairs(output_table) do
      table.insert(keys, output_table[index][extract_key])
    end
  else
    for key, _ in pairs(output_table) do
      table.insert(keys, key)
    end
  end

  if #keys == 0 then
    callback(nil)
    return
  elseif #keys == 1 then
    callback(keys[1])
    return
  end

  ---@type fun(selected): nil
  local sink = function(selected)
    if #selected < 2 then
      callback(nil)
      return
    end
    callback(selected[2])
  end

  local wrapped_opts = vim.fn['fzf#wrap'] { source = keys, options = { '--prompt', 'Buffer Clients> ' } }
  wrapped_opts['sink*'] = sink
  return vim.fn['fzf#run'](wrapped_opts)
end

return M
