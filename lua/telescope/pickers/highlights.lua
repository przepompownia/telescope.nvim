local a = vim.api
local log = require "telescope.log"
local conf = require("telescope.config").values

local highlights = {}

local ns_telescope_matching = a.nvim_create_namespace "telescope_matching"
local ns_telescope_selection = a.nvim_create_namespace "telescope_selection"
local ns_telescope_multiselection = a.nvim_create_namespace "telescope_multiselection"
local ns_telescope_entry = a.nvim_create_namespace "telescope_entry"

local Highlighter = {}
Highlighter.__index = Highlighter

function Highlighter:new(picker)
  return setmetatable({
    picker = picker,
  }, self)
end

local SELECTION_HIGHLIGHTS_PRIORITY = 105
local DISPLAY_HIGHLIGHTS_PRIORITY = 110
local SORTER_HIGHLIGHTS_PRIORITY = 120

function Highlighter:hi_display(row, prefix, display_highlights)
  -- This is the bug that made my highlight fixes not work.
  -- We will leave the solution commented, so the test fails.
  if not display_highlights or vim.tbl_isempty(display_highlights) then
    return
  end

  local results_bufnr = assert(self.picker.results_bufnr, "Must have a results bufnr")

  a.nvim_buf_clear_namespace(results_bufnr, ns_telescope_entry, row, row + 1)
  local len_prefix = #prefix

  for _, hl_block in ipairs(display_highlights) do
    a.nvim_buf_set_extmark(results_bufnr, ns_telescope_entry, row, len_prefix + hl_block[1][1], {
      end_col = len_prefix + hl_block[1][2],
      hl_group = hl_block[2],
      priority = DISPLAY_HIGHLIGHTS_PRIORITY,
      strict = true,
    })
  end
end

function Highlighter:clear()
  if
    not self
    or not self.picker
    or not self.picker.results_bufnr
    or not vim.api.nvim_buf_is_valid(self.picker.results_bufnr)
  then
    return
  end

  a.nvim_buf_clear_namespace(self.picker.results_bufnr, ns_telescope_entry, 0, -1)
  a.nvim_buf_clear_namespace(self.picker.results_bufnr, ns_telescope_matching, 0, -1)
end

function Highlighter:hi_sorter(row, prompt, display)
  local picker = self.picker
  local sorter = picker.sorter
  if not picker.sorter or not picker.sorter.highlighter then
    return
  end

  local results_bufnr = assert(self.picker.results_bufnr, "Must have a results bufnr")
  local sorter_highlights = sorter:highlighter(prompt, display)

  if sorter_highlights then
    for _, hl in ipairs(sorter_highlights) do
      local highlight, start, finish
      if type(hl) == "table" then
        highlight = hl.highlight or "TelescopeMatching"
        start = hl.start
        finish = hl.finish or hl.start
      elseif type(hl) == "number" then
        highlight = "TelescopeMatching"
        start = hl
        finish = hl
      else
        error "Invalid higlighter fn"
      end

      picker:_increment "highlights"

      a.nvim_buf_set_extmark(results_bufnr, ns_telescope_matching, row, start - 1, {
        end_col = finish,
        hl_group = highlight,
        priority = SORTER_HIGHLIGHTS_PRIORITY,
        strict = true,
      })
    end
  end
end

function Highlighter:hi_selection(row, caret)
  caret = vim.F.if_nil(caret, "")
  local results_bufnr = assert(self.picker.results_bufnr, "Must have a results bufnr")

  a.nvim_buf_clear_namespace(results_bufnr, ns_telescope_selection, 0, -1)

  a.nvim_buf_set_extmark(results_bufnr, ns_telescope_selection, row, 0, {
    end_col = #caret,
    hl_group = "TelescopeSelectionCaret",
    priority = SELECTION_HIGHLIGHTS_PRIORITY,
    strict = true,
  })

  a.nvim_buf_set_extmark(results_bufnr, ns_telescope_selection, row, #caret, {
    end_line = row + 1,
    hl_eol = conf.hl_result_eol,
    hl_group = "TelescopeSelection",
    priority = SELECTION_HIGHLIGHTS_PRIORITY,
  })
end

function Highlighter:hi_multiselect(row, is_selected)
  local results_bufnr = assert(self.picker.results_bufnr, "Must have a results bufnr")

  if is_selected then
    vim.api.nvim_buf_add_highlight(results_bufnr, ns_telescope_multiselection, "TelescopeMultiSelection", row, 0, -1)
    if self.picker.multi_icon then
      local line = vim.api.nvim_buf_get_lines(results_bufnr, row, row + 1, false)[1]
      local pos = line:find(self.picker.multi_icon)
      if pos and pos <= math.max(#self.picker.selection_caret, #self.picker.entry_prefix) then
        vim.api.nvim_buf_add_highlight(
          results_bufnr,
          ns_telescope_multiselection,
          "TelescopeMultiIcon",
          row,
          pos - 1,
          pos - 1 + #self.picker.multi_icon
        )
      end
    end
  else
    local existing_marks = vim.api.nvim_buf_get_extmarks(
      results_bufnr,
      ns_telescope_multiselection,
      { row, 0 },
      { row, -1 },
      {}
    )

    -- This is still kind of weird to me, since it seems like I'm erasing stuff
    -- when I shouldn't... Perhaps it's about the gravity of the extmark?
    if #existing_marks > 0 then
      log.trace("Clearing highlight multi select row: ", row)

      vim.api.nvim_buf_clear_namespace(results_bufnr, ns_telescope_multiselection, row, row + 1)
    end
  end
end

highlights.new = function(...)
  return Highlighter:new(...)
end

return highlights
