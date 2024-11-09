--- Adds variables to the command properly.
--- Transforms to a return statement so it gets returned by loadstring properly.
---@param command string Command needed to be massaged
---@param command_variables table|nil if there are any of these... replace instance of \\? with variable value
---@return string command
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
---@return string[]|nil keys
---@return string|nil last_key
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
---@return boolean
local function is_list(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end

  return count == #tbl
end

--- A helper function that performs a safe deepcopy of a table.
---@param tbl table The table we are performing the copy on
---@return table|nil filtered_table
local function table_safe_copy(tbl)
  if type(tbl) ~= 'table' then
    return
  end

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

---A helper function to safely execute a command who's output should be printed in our new window
---@param command string Command to execute
---@return table|nil result
---@return string? error
local function safe_execute_command(command)
  local fn, load_err = loadstring(command)
  if not fn then
    return nil, string.format('Failed to load command: %s\n\t%s', command, load_err)
  end

  local success, result = pcall(fn)
  if not success then
    return nil, string.format('Failed to execute command: %s\n\t%s', command, result)
  end

  if type(result) ~= 'table' then
    return nil, string.format('Command must return a table, got %s', type(result))
  end

  return result, nil
end

local M = {}

---@class WindowParams
---@field name string Window name
---@field command string Lua command string
---@field command_variables string[]|nil Command variables (optional)
---@field ident_keys string[]|nil Keys to extract from resulting table
---@field print_all_output boolean Whether to print remaining output after extraction

---Validates window creation parameters
---@param params WindowParams Parameters to validate
---@return boolean is_valid
---@return string? error_message
local function validate_window_params(params)
  -- Validate required fields and their types.
  if not params.name or type(params.name) ~= 'string' then
    return false, '"name" is required and must be of type string.'
  end

  if not params.command or type(params.command) ~= 'string' then
    return false, '"command" is required and must be of type string.'
  end

  if params.print_all_output == nil or type(params.print_all_output) ~= 'boolean' then
    return false, '"print_all_output" is required and must be of type boolean.'
  end

  -- Validate optional field types.
  if params.command_variables and type(params.command_variables) ~= 'table' then
    return false, '"command_variables" must be a table when provided'
  end

  if params.ident_keys and type(params.ident_keys) ~= 'table' then
    return false, '"ident_keys" must be a table when provided'
  end

  local _, count = params.command:gsub("%\\%?", "")
  if count ~= #params.command_variables then
    return false, '"command must have the same number of instances as the length of command_variables'
  end

  -- Validate command string
  local command_string = massage_command(params.command, params.command_variables)
  local command_valid, command_error = pcall(loadstring, command_string)
  if not command_valid then
    return false, string.format('Invalid Lua command passed to window: %s\n\t%s', command_string, command_error)
  end

  -- Validate ident_keys format and structure
  if params.ident_keys then
    if #params.ident_keys == 0 then
      return false, '"ident_keys" table cannot be empty'
    end

    for _, key in ipairs(params.ident_keys) do
      if type(key) ~= 'string' then
        return false, 'All entried in "ident_keys" must be strings'
      end
      -- Validate format
      if not key:match '^[%w_]+[.]?[%w_]*[.]?[%w_]*[.]?[%w_]*$' then
        return false, string.format('Invalid ident key format: "%s": must be in the format, "key.subkey.subkey"', key)
      end
    end
  end


  return true, nil
end

---Creates a window with the output of "command".
---@param opts WindowParams Parameters for the window
---@return nil
function M.createWindow(opts)
  --Let's validate parameters first
  local is_valid, error_msg = validate_window_params {
    name = opts.name,
    command = opts.command,
    command_variables = opts.command_variables,
    ident_keys = opts.ident_keys,
    print_all_output = opts.print_all_output,
  }

  if not is_valid then
    vim.notify(string.format('Window creation failed: %s', error_msg), vim.log.levels.ERROR)
    return
  end

  -- We massage the command first, then run it.
  opts.command = massage_command(opts.command, opts.command_variables)

  -- We deepcopy so that removing entries from the table does not break anything
  local command_output, exec_error = safe_execute_command(opts.command)
  if not command_output then
    vim.notify(exec_error, vim.log.levels.ERROR) ---@diagnostic disable-line: param-type-mismatch
    return
  end

  local output_table = table_safe_copy(command_output)
  if not output_table then
    vim.notify('Failed to create safe copy of command output', vim.log.levels.ERROR)
    return
  end

  if not is_list(output_table) then
    output_table = { output_table }
  end

  -- Create a temporary buffer to show the command output, and do a little error handling
  local buf = vim.api.nvim_create_buf(false, true)
  if not buf then
    vim.notify('Failed to create buffer', vim.log.levels.ERROR)
    return
  end

  local win_ok, win = pcall(vim.api.nvim_open_win, buf, true, {
    relative = 'editor',
    width = math.floor(vim.o.columns * 0.75),
    height = math.floor(vim.o.lines * 0.90),
    col = math.floor(vim.o.columns * 0.125),
    row = math.floor(vim.o.lines * 0.05),
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. (opts.name:gsub('^%l', string.upper)) .. ' ',
    title_pos = 'center',
  })

  if not win_ok then
    vim.notify('Failed to create window: ' .. tostring(win), vim.log.levels.ERROR)
    vim.api.nvim_buf_delete(buf, { force = true })
    return
  end

  local lines = {}
  for i, current_output in ipairs(output_table) do
    if i > 1 then
      table.insert(lines, string.rep('-', 80))
    end

    if opts.ident_keys then
      for _, v in ipairs(opts.ident_keys) do
        -- We loop through each ident_key and 1. Add an entry in the table with the appropriate info
        -- 2. We remove that key from its parent table.
        local current_print_section = { v:gsub('^%l', string.upper) .. ': ' }
        local keys, nested_key = get_nested_value(current_output, v)

        if not nested_key or not keys then
          vim.notify(string.format("Nested key '%s' not found in output", v), vim.log.levels.WARN)
          goto continue
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

        ::continue::
      end
    end

    -- Take the remainder of the output and print at the end if applicable
    if opts.print_all_output then
      table.insert(lines, 'Full output: ')
      local all_output = vim.split(vim.inspect(current_output), '\n')
      vim.list_extend(lines, all_output)
    end
  end

  -- Set the lines in buf
  local set_lines_ok = pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines)
  if not set_lines_ok then
    vim.notify("Setting lines in buffer did not work.", vim.log.levels.ERROR)
    return
  end

  -- Set buf options
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = 'lua'
  vim.bo[buf].bh = 'delete'

  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>:q<cr>', { noremap = true, silent = true })
end

---@class FZFParams
---@field command string Command to run to get source for fzf
---@field extract_key string|nil The key inside the resulting table to extract for fzf source.
---@field prompt string|nil Custom prompt text for fzf
---@field callback fun(selected: string|nil) Callback function for selection

---Validates parameters  sent to the select_via_fzf function
---@param params FZFParams
---@return boolean is_valid
---@return string? error_message
local function validate_fzf_params(params)
  if not params.command or type(params.command) ~= 'string' then
    return false, '"command" is required and must be of type string.'
  end

  if params.extract_key and type(params.extract_key) ~= 'string' then
    return false, '"extract_key" must be of type string when specified.'
  end

  if not params.callback or type(params.callback) ~= "function" then
    return false, '"callback" is required and must be of type function.'
  end

  if params.prompt and type(params.prompt) ~= 'string' then
    return false, '"prompt" must be of type string when specified.'
  end

  return true, nil
end

---A method to take some command, and fzf some key from the resulting string[].
---The callback function should look like:
---function(selected)
---  if selected_lsp then
---    call_func_to_show_window_for_resource()
---  end
---end
---@param opts FZFParams Params for fzf window
function M.select_via_fzf(opts)

  local is_valid, error_msg = validate_fzf_params({
    command = opts.command,
    extract_key = opts.extract_key,
    prompt = opts.prompt,
    callback = opts.callback,
  })

  if not is_valid then
    vim.notify(string.format('Fzf failed: %s', error_msg), vim.log.levels.ERROR)
    return
  end

  --- the following is for LSPs, keeping as an example of a command that can be used for a fzf source
  -- local bufnr = vim.api.nvim_get_current_buf(); local clients = vim.lsp.get_clients { bufnr = bufnr }
  opts.command = opts.command:match('^return%s+') and opts.command or string.format('return %s', opts.command)

  local command_output, exec_error = safe_execute_command(opts.command)
  if not command_output then
    vim.notify(string.format("Command execution failed: %s", exec_error), vim.log.levels.ERROR) ---@diagnostic disable-line: param-type-mismatch
    return
  end

  if type(command_output) ~= 'table' then
    vim.notify(string.format('Command did not return a table: %s', opts.command), vim.log.levels.ERROR)
    return
  end

  local output_table = table_safe_copy(command_output)
  if not output_table then
    vim.notify('Failed to create safe copy of output.', vim.log.levels.ERROR)
    return
  end

  local keys = {}

  if is_list(output_table) then
    if not opts.extract_key then
      vim.notify('"extract_key" is nil. Please specify the extract_key for a list type', vim.log.levels.ERROR)
      return
    end

    for index, _ in ipairs(output_table) do
      table.insert(keys, output_table[index][opts.extract_key])
    end

  else
    for key, _ in pairs(output_table) do
      table.insert(keys, key)
    end
  end

  if #keys == 0 then
    opts.callback(nil)
    return
  elseif #keys == 1 then
    opts.callback(keys[1])
    return
  end

  local sink = function(selected)
    if #selected < 2 then
      opts.callback(nil)
      return
    end
    opts.callback(selected[2])
  end

  local fzf_prompt = opts.prompt or 'Fzf Input > '
  local wrapped_opts = vim.fn['fzf#wrap'] { source = keys, options = { '--prompt', fzf_prompt } }
  wrapped_opts['sink*'] = sink
  return vim.fn['fzf#run'](wrapped_opts)
end

return M
