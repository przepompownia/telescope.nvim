---@tag telescope.mappings

---@brief [[
---  Format is:
---  {
---    mode = { ..keys }
---  }
---
---  where {mode} is the one character letter for a mode
---  ('i' for insert, 'n' for normal).
---
---  For example:
---
---  mappings = {
---    i = {
---      ["<esc>"] = require('telescope.actions').close,
---    },
---  }
---
---
---  To disable a keymap, put [map] = false
---    So, to not map "<C-n>", just put
---
---      ...,
---      ["<C-n>"] = false,
---      ...,
---
---    Into your config.
---
---
---  otherwise, just set the mapping to the function that you want it to
---  be.
---
---      ...,
---      ["<C-i>"] = require('telescope.actions').select_default,
---      ...,
---
---  If the function you want is part of `telescope.actions`, then you can
---  simply give a string.
---    For example, the previous option is equivalent to:
---
---      ...,
---      ["<C-i>"] = "select_default",
---      ...,
---
---  You can also add other mappings using tables with `type = "command"`.
---    For example:
---
---      ...,
---      ["jj"] = { "<esc>", type = "command" },
---      ["kk"] = { "<cmd>echo \"Hello, World!\"<cr>", type = "command" },)
---      ...,
---@brief ]]

local a = vim.api

local actions = require "telescope.actions"
local config = require "telescope.config"

local mappings = {}

mappings.default_mappings = config.values.default_mappings
  or {
    i = {
      ["<C-n>"] = actions.move_selection_next,
      ["<C-p>"] = actions.move_selection_previous,

      ["<C-c>"] = actions.close,

      ["<Down>"] = actions.move_selection_next,
      ["<Up>"] = actions.move_selection_previous,

      ["<CR>"] = actions.select_default,
      ["<C-x>"] = actions.select_horizontal,
      ["<C-v>"] = actions.select_vertical,
      ["<C-t>"] = actions.select_tab,

      ["<C-u>"] = actions.preview_scrolling_up,
      ["<C-d>"] = actions.preview_scrolling_down,

      ["<PageUp>"] = actions.results_scrolling_up,
      ["<PageDown>"] = actions.results_scrolling_down,

      ["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
      ["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
      ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
      ["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
      ["<C-l>"] = actions.complete_tag,
      ["<C-_>"] = actions.which_key, -- keys from pressing <C-/>
    },

    n = {
      ["<esc>"] = actions.close,
      ["<CR>"] = actions.select_default,
      ["<C-x>"] = actions.select_horizontal,
      ["<C-v>"] = actions.select_vertical,
      ["<C-t>"] = actions.select_tab,

      ["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
      ["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
      ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
      ["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,

      -- TODO: This would be weird if we switch the ordering.
      ["j"] = actions.move_selection_next,
      ["k"] = actions.move_selection_previous,
      ["H"] = actions.move_to_top,
      ["M"] = actions.move_to_middle,
      ["L"] = actions.move_to_bottom,

      ["<Down>"] = actions.move_selection_next,
      ["<Up>"] = actions.move_selection_previous,
      ["gg"] = actions.move_to_top,
      ["G"] = actions.move_to_bottom,

      ["<C-u>"] = actions.preview_scrolling_up,
      ["<C-d>"] = actions.preview_scrolling_down,

      ["<PageUp>"] = actions.results_scrolling_up,
      ["<PageDown>"] = actions.results_scrolling_down,

      ["?"] = actions.which_key,
    },
  }

__TelescopeKeymapStore = __TelescopeKeymapStore
  or setmetatable({}, {
    __index = function(t, k)
      rawset(t, k, {})

      return rawget(t, k)
    end,
  })
local keymap_store = __TelescopeKeymapStore

local _mapping_key_id = 0
local get_next_id = function()
  _mapping_key_id = _mapping_key_id + 1
  return _mapping_key_id
end

local assign_function = function(prompt_bufnr, func)
  local func_id = get_next_id()

  keymap_store[prompt_bufnr][func_id] = func

  return func_id
end

--[[
Usage:

mappings.apply_keymap(42, <function>, {
  n = {
    ["<leader>x"] = "just do this string",

    ["<CR>"] = function(picker, prompt_bufnr)
      actions.close_prompt()

      local filename = ...
      vim.cmd(string.format(":e %s", filename))
    end,
  },

  i = {
  }
})
--]]
local telescope_map = function(prompt_bufnr, mode, key_bind, key_func, opts)
  if not key_func then
    return
  end

  key_bind = a.nvim_replace_termcodes(key_bind, true, true, true)

  opts = opts or {}
  if opts.noremap == nil then
    opts.noremap = true
  end
  if opts.silent == nil then
    opts.silent = true
  end

  if type(key_func) == "string" then
    key_func = actions[key_func]
  elseif type(key_func) == "table" then
    if key_func.type == "command" then
      a.nvim_buf_set_keymap(prompt_bufnr, mode, key_bind, key_func[1], opts or {
        silent = true,
      })
      return
    elseif key_func.type == "action_key" then
      key_func = actions[key_func[1]]
    elseif key_func.type == "action" then
      key_func = key_func[1]
    end
  end

  local key_id = assign_function(prompt_bufnr, key_func)
  local prefix

  local map_string
  if opts.expr then
    map_string = string.format(
      [[luaeval("require('telescope.mappings').execute_keymap(%s, %s)")]],
      prompt_bufnr,
      key_id
    )
  else
    if mode == "i" and not opts.expr then
      prefix = "<cmd>"
    elseif mode == "n" then
      prefix = ":<C-U>"
    else
      prefix = ":"
    end

    map_string = string.format(
      "%slua require('telescope.mappings').execute_keymap(%s, %s)<CR>",
      prefix,
      prompt_bufnr,
      key_id
    )
  end

  a.nvim_buf_set_keymap(prompt_bufnr, mode, key_bind, map_string, opts)
end

local termcode_mt = {
  __index = function(t, k)
    return rawget(t, a.nvim_replace_termcodes(k, true, true, true))
  end,

  __newindex = function(t, k, v)
    rawset(t, a.nvim_replace_termcodes(k, true, true, true), v)
  end,
}

local mode_mt = {
  __index = function(t, k)
    k = string.lower(k)
    if rawget(t, k) then
      return rawget(t, k)
    end

    local val = setmetatable({}, termcode_mt)
    rawset(t, k, val)
    return val
  end,
}

mappings.apply_keymap = function(prompt_bufnr, attach_mappings, ...)
  local mappings_applied = setmetatable({}, mode_mt)
  local mappings_config = setmetatable(vim.tbl_deep_extend("force", mappings.default_mappings or {}, ...), mode_mt)

  local map = function(mode, key_bind, key_func, opts)
    -- Skip maps that are disabled by the user
    if mappings_config[mode][key_bind] == false then
      return
    end

    mappings_applied[mode][key_bind] = true
    telescope_map(prompt_bufnr, mode, key_bind, key_func, opts)
  end

  if attach_mappings then
    local attach_results = attach_mappings(prompt_bufnr, map)

    if attach_results == nil then
      error(
        "Attach mappings must always return a value. `true` means use default mappings, "
          .. "`false` means only use attached mappings"
      )
    end

    if not attach_results then
      return
    end
  end

  for mode, mode_map in pairs(mappings_config) do
    mode = string.lower(mode)

    for key_bind, key_func in pairs(mode_map) do
      if not mappings_applied[mode][key_bind] then
        mappings_applied[mode][key_bind] = true
        telescope_map(prompt_bufnr, mode, key_bind, key_func)
      end
    end
  end

  vim.cmd(
    string.format([[autocmd BufDelete %s :lua require('telescope.mappings').clear(%s)]], prompt_bufnr, prompt_bufnr)
  )
end

mappings.execute_keymap = function(prompt_bufnr, keymap_identifier)
  local key_func = keymap_store[prompt_bufnr][keymap_identifier]

  assert(key_func, string.format("Unsure of how we got this failure: %s %s", prompt_bufnr, keymap_identifier))

  key_func(prompt_bufnr)
  vim.cmd [[ doautocmd User TelescopeKeymap ]]
end

mappings.clear = function(prompt_bufnr)
  keymap_store[prompt_bufnr] = nil
end

return mappings
