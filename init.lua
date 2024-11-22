-- mod-version :3
local modal = require("plugins.modal")

local DocView = require("core.docview")

local config = require("core.config")
local command = require("core.command")
local core = require("core")
local common = require("core.common")
local search = require("core.doc.search")


-- require("plugins.modal_vim.command_mode")

local modal_vim = {}

local mode = {
    NORMAL = "NORMAL",
    INSERT = "INSERT",
    VISUAL = "VISUAL",
    VISUAL_LINE = "VISUAL_LINE",
    VISUAL_BLOCK = "VISUAL_BLOCK",
}

local function move_to_start_of_next_word()
    command.perform("doc:move-to-next-word-end")
    -- wait a few seconds for the cursor to jump to next word
    command.perform("doc:move-to-start-of-word")
end


local function dv()
  return core.active_view
end

local function doc()
  return dv().doc
end


local function sort_positions(line1, col1, line2, col2)
  if line1 > line2 or line1 == line2 and col1 > col2 then
    return line2, col2, line1, col1, true
  end
  return line1, col1, line2, col2, false
end

local function doc_multiline_selections(sort)
  if dv() == nil or doc() == nil or doc().get_selections == nil then return function() return nil end end
  local iter, state, idx, line1, col1, line2, col2 = doc():get_selections(sort)
  return function()
    idx, line1, col1, line2, col2 = iter(state, idx)
    if idx and line2 > line1 and col2 == 1 then
      line2 = line2 - 1
      col2 = #doc().lines[line2]
    end
    return idx, line1, col1, line2, col2
  end
end



local function get_last_key()
  local view = core.active_view
  if view.modal then
    local seq = modal.split_command(view.modal.current_command.seq)
    local last = seq[#seq]
    if #last > 1 then
      last = modal.reverse_key_mapping[last]
    end
    if last then
      return last
    end
  end
  return nil
end


local function move_on_next_char()
  local view = core.active_view
  local last = get_last_key()
  if last then
    for idx, line1, col1, line2, col2 in doc_multiline_selections(false) do
      local _, _, l2, c2 = sort_positions(line1, col1, line2, col2)
      local ok, _, _, lnn, cnn = pcall(search.find, view.doc, l2, c2 + 1, last,
        { wrap = false, regex = false, no_case = false, reverse = false })
      if ok and lnn then
        view.doc:set_selections(idx, lnn, cnn, l2, c2)
      end
    end
  end
end

local function move_on_prev_char()
  local view = dv()
  local last = get_last_key()
  if last then
    for idx, line1, col1, line2, col2 in doc_multiline_selections(false) do
      local l1, c1, _, _ = sort_positions(line1, col1, line2, col2)
      local ok, lnn, cnn, _, _ = pcall(search.find, view.doc, l1, c1, last,
        { wrap = false, regex = false, no_case = false, reverse = true })
      if ok and lnn then
        view.doc:set_selections(idx, lnn, cnn, l1, c1)
      end
    end
  end
end


-- implement keymap.set function similar to neovim (use lite-xl's function as reference)
-- example
-- config.plugins.modal_vim.keymap.set("normal", "U", "doc:undo")
--                                    ^^^  ^^^  ^^^^^^^^^^
--                                    mode key  action 
-- TODO: implement in such a way that you can add keybinds from init.lua (or any other file), similarly to vibe
config.plugins.modal_vim = common.merge({
    user_keymap_normal = {},
    user_keymap_insert = {},
    user_keymap_visual = {},
    user_keymap_visual_line = {},
    user_keymap_visual_block = {},
    mouse_interactions = false
})

-- Serves to replicate the functionality of the C-i keybinding when in insert mode in vim
local function indent_at_cursor()
    local dv = core.active_view
    local indent_type, indent_size = dv.doc:get_indent_info()
    local indent_char = ""

    if indent_type == "hard" then
        indent_char = "\t" -- tab
    else
        indent_char = " " -- spaces
    end

    DocView.on_text_input(dv, string.rep(indent_char, indent_size))
end

config.plugins.modal.base_mode = mode.NORMAL
config.plugins.modal.modes = { mode.NORMAL, mode.INSERT, mode.VISUAL, mode.VISUAL_LINE, mode.VISUAL_BLOCK }

config.plugins.modal.keymaps = {
  NORMAL = {
    ["."] = modal.redo_command,

    -- INSERT mode
    ["i"] = { modal.go_to_mode(mode.INSERT) }, -- add function to not send cursor back a line if at first column
    ["I"] = { "doc:move-to-start-of-indentation", modal.go_to_mode(mode.INSERT) },
    ["o"] = { "doc:newline-below", modal.go_to_mode(mode.INSERT) },
    ["O"] = { "doc:newline_above", modal.go_to_mode(mode.INSERT) },
    ["a"] = { "doc:move-to-next-char", modal.go_to_mode(mode.INSERT) },
    ["A"] = { "doc:move-to-end-of-line", modal.go_to_mode(mode.INSERT) },

    -- VISUAL Mode
    ["v"] = { modal.go_to_mode(mode.VISUAL) },
    ["V"] = { "doc:move-to-start-of-line", "doc:select-to-next-line", "doc:select-to-previous-char", modal.go_to_mode(mode.VISUAL_LINE) },
    -- ["V"] = { "doc:move-to-end-of-line", "doc:select-to-start-of-line", modal.go_to_mode(mode.VISUAL_LINE) },
    ["C-v"] = { modal.go_to_mode(mode.VISUAL_BLOCK) }, -- BLOCK visual mode, use multi cursor to simulate or try to get selection functions working

    ["viw"] = { "doc:move-to-start-of-word", "doc:select-to-next-word-end" },
    ["vi'"] = { move_on_next_char, "v", move_on_next_char },
    ['vi<.>'] = { move_on_next_char, "doc:select-none", "v", move_on_next_char },


    [":"] = "core:find-command",
    [";:"] = "doc:go-to-line", -- temporary solution, solution: loop over amount of lines, make them commands, jump

    ["/"] = "find-replace:find",
    ["n"] = "find-replace:repeat-find",
    ["N"] = "find-replace:previous-find",

    ["dd"] = "doc:delete-lines",

    ["x"] = "doc:delete-to-next-char",
    ["X"] = "doc:delete-to-previous-char",

    ["diw"] = { "doc:move-to-start-of-word", "doc:delete-to-next-word-end" },
    ["dw"] = { "doc:delete-to-next-word-end" },
    ["dW"] = { "doc:delete-to-next-WORD-end" },
    ["db"] = { "doc:delete-to-previous-word-start" },
    ["dB"] = { "doc:delete-to-previous-WORD-start" },
    ["d_"] = { "doc:delete-to-start-of-line" },
    ["d^"] = { "doc:delete-to-start-of-line" },
    ["d$"] = { "doc:delete-to-end-of-line" },
    ["dgg"] = "doc:delete-to-start-of-doc",
    ["dG"] = "doc:delete-to-end-of-doc",

    ["ciw"] = { "doc:move-to-start-of-word", "doc:delete-to-next-word-end", modal.go_to_mode(mode.INSERT) },
    ["cip"] = { "doc:delete-to-next-block-end", modal.go_to_mode(mode.INSERT) },

    ["cw"] = { "doc:delete-to-next-word-end", modal.go_to_mode(mode.INSERT) },
    ["cW"] = { "doc:delete-to-next-WORD-end", modal.go_to_mode(mode.INSERT) },
    ["cb"] = { "doc:delete-to-previous-word-start", modal.go_to_mode(mode.INSERT) },
    ["cB"] = { "doc:delete-to-previous-WORD-start", modal.go_to_mode(mode.INSERT) },
    ["c0"] = { "doc:delete-to-start-of-line", modal.go_to_mode(mode.INSERT) },
    ["c$"] = { "doc:delete-to-end-of-line", modal.go_to_mode(mode.INSERT) },
    ["ce"] = { "doc:delete-to-end-of-word", modal.go_to_mode(mode.INSERT) },
    ["cgg"] = { "doc:delete-to-start-of-doc", modal.go_to_mode(mode.INSERT) },
    ["cG"] = { "doc:delete-to-end-of-doc", modal.go_to_mode(mode.INSERT) },

    -- Basic movements
    ["<right>"] = { "doc:move-to-next-char" },
    ["<left>"] =  { "doc:move-to-previous-char" },
    ["<up>"] =    { "doc:move-to-previous-line" },
    ["<down>"] =  { "doc:move-to-next-line" },

    ["<tab>"] =     { "doc:move-to-next-char" },
    ["<bkspc>"] =   { "doc:move-to-previous-char" },
    ["C-<bkspc>"] = { "doc:move-to-previous-word" },

    ["l"] = { "doc:move-to-next-char" },
    ["h"] = { "doc:move-to-previous-char" },
    ["k"] = { "doc:move-to-previous-line" },
    ["j"] = { "doc:move-to-next-line" },

    -- ["w"] = move_to_start_of_next_word,
    ["w"] = "doc:move-to-next-word-end",
    ["W"] = "doc:move-to-next-WORD-end",
    ["b"] = "doc:move-to-previous-word-start",
    ["B"] = "doc:move-to-previous-WORD-start",
    ["e"] = "doc:move-to-next-word-end",

    ["C-<right>"] = { "doc:move-to-next-word-end" },
    ["C-<left>"] = { "doc:move-to-previous-word-start" },

    ["f<.>"] = { move_on_next_char, "doc:select-none", "doc:move-to-previous-char" }, -- hacked together as hell LMAOOOOOO
    ["F<.>"] = { move_on_prev_char, "doc:select-none" }, -- hacked together as hell LMAOOOOOO

    -- ["F<.>"] = move_on_prev_char,
    --
    -- ["t<.>"] = move_after_next_char,
    -- ["T<.>"] = move_after_prev_char,


    ["yy"] = { "doc:move-to-start-of-line", "doc:select-to-end-of-line", "doc:copy", "doc:select-none" },
    ["p"] = "doc:paste",

    ["u"] = "doc:undo",
    -- ["<C-r>"] = "doc:redo",
    ["U"] = "doc:redo", -- personal preference

    ["C-u"] = "doc:move-to-previous-page",
    ["C-d"] = "doc:move-to-next-page",

    ["gg"] = "doc:move-to-start-of-doc",
    ["G"] = "doc:move-to-end-of-doc",

    ["_"] = "doc:move-to-start-of-indentation",
    ["^"] = "doc:move-to-start-of-indentation",
    ["$"] = "doc:move-to-end-of-line",
    ["0"] = "doc:move-to-start-of-line", -- still doesnt work due to limitation of the modal plugin

    ["C-wv"] = { "doc:split-left", "root:switch-to-left" },
    ["C-ws"] = { "doc:split-up", "root:switch-to-top" },

    ["<space>wv"] = { "root:split-right", "root:switch-to-right" },
    ["<space>ws"] = { "root:split-down", "root:switch-to-down" },

    -- ["~"] = { "doc:move-to-next-char", "doc:select-to-previous-char", "doc:upper-case", "doc:select-none" },
  },
  INSERT = {
    ["<ESC>"] = { modal.go_to_mode(mode.NORMAL) },
    ["C-c"] = { modal.go_to_mode(mode.NORMAL) },

    ["<bkspc>"] =   { "doc:delete-to-previous-char" },
    ["C-<bkspc>"] = { "doc:delete-to-previous-word-start" },

    ["C-V"] = { "doc:paste" },

    ["C-h"] = { "doc:delete-to-previous-char" },
    ["C-H"] = { "doc:delete-to-previous-char" },
    ["C-a"] = { "doc:delete-to-previous-char" },
    ["C-A"] = { "doc:delete-to-previous-char" },

    ["C-w"] = { "doc:delete-to-previous-word" },
    ["C-W"] = { "doc:delete-to-previous-word" },

    ["C-u"] = { "doc:delete-to-previous-line" },

    ["C-r"] = {}, -- paste from registers
    ["C-o"] = {}, -- move to previously opened file

    ["C-j"] = { "doc:newline-below" },
    ["C-m"] = { "doc:newline-below" },

    ["C-i"] = indent_at_cursor, -- put indentation infront of cursor

  },
  VISUAL = {
    ["<ESC>"] = { modal.go_to_mode(mode.NORMAL), "doc:select-none" },
    ["C-c"] = { modal.go_to_mode(mode.NORMAL), "doc:select-none" },
    ["y"] = { "doc:copy", "doc:select-none", modal.go_to_mode(mode.NORMAL) }, -- TODO: registers

    ["<right>"] = { "doc:select-to-next-char" },
    ["<left>"] =  { "doc:select-to-previous-char" },
    ["<up>"] =    { "doc:select-to-previous-line" },
    ["<down>"] =  { "doc:select-to-next-line" },
    
    ["l"] =  { "doc:select-to-next-char" },
    ["h"] =  { "doc:select-to-previous-char" },
    ["k"] =  { "doc:select-to-previous-line" },
    ["j"] =  { "doc:select-to-next-line" },
    ["gg"] = { "doc:select-to-end-of-doc" },
    ["G"] =  { "doc:select-to-start-of-doc" },

    ["0"] = { "doc:select-to-start-of-line" },
    ["e"] = { "doc:select-to-end-of-word" },
    ["B"] = { "doc:select-to-previous-WORD-start" },
    ["W"] = { "doc:select-to-next-WORD-end" },
    ["w"] = "doc:select-to-next-word-end",
    ["b"] = "doc:select-to-previous-word-start",

    ["f<.>"] = { move_on_next_char, "doc:select-to-previous-char" }, -- hacked together as hell LMAOOOOOO
    ["F<.>"] = { move_on_prev_char }, -- hacked together as hell LMAOOOOOO

    ["ip"] = { "doc:select-to-next-block-end" },




    ["d"] = { "doc:copy", "doc:delete", "doc:select-none", modal.go_to_mode(mode.NORMAL) },
    ["x"] = { "doc:copy", "doc:delete", "doc:select-none", modal.go_to_mode(mode.NORMAL) },

    ["p"] = { "doc:paste", "doc:select-none", modal.go_to_mode(mode.NORMAL) },

    ["_"] = "doc:select-to-start-of-indentation",
    ["^"] = "doc:select-to-start-of-indentation",
    ["$"] = "doc:select-to-end-of-line",
    ["0"] = "doc:select-to-start-of-line",

    ["u"] = { "doc:lower-case", "doc:select-none", modal.go_to_mode(mode.NORMAL) },
    ["U"] = { "doc:upper-case", "doc:select-none", modal.go_to_mode(mode.NORMAL) },

    [":"] = "core:find-command",
    },

  VISUAL_LINE = {
    ["<ESC>"] = { modal.go_to_mode(mode.NORMAL), "doc:select-none" },
    ["C-c"] =   { modal.go_to_mode(mode.NORMAL), "doc:select-none" },
    
    ["y"] = { "doc:copy", "doc:select-none", modal.go_to_mode(mode.NORMAL) }, -- TODO: registers
    ["p"] = { "doc:paste", "doc:select-none", modal.go_to_mode(mode.NORMAL) },

    ["u"] = { "doc:lower-case", "doc:select-none", modal.go_to_mode(mode.NORMAL) },
    ["U"] = { "doc:upper-case", "doc:select-none", modal.go_to_mode(mode.NORMAL) },

    ["d"] = { "doc:copy", "doc:delete", "doc:select-none", modal.go_to_mode(mode.NORMAL) },
    ["x"] = { "doc:copy", "doc:delete", "doc:select-none", modal.go_to_mode(mode.NORMAL) },

    ["<down>"] = { "doc:select-to-next-line", "doc:select-to-end-of-line" },
    -- ["<up>"] = { "doc:move-to-previous-line", "doc:move-to-start-of-line", "doc:select-to-previous-line", "doc:select-to-start-of-line" },
    ["<up>"] =   { "doc:select-to-previous-line", "doc:select-to-start-of-line" },

    -- ["<right>"] = { "doc:select-to-next-char" },
    -- ["<left>"] = { "doc:select-to-previous-char" },

    ["k"] =  { "doc:select-to-previous-line" },
    ["j"] =  { "doc:select-to-next-line" },
    
    ["gg"] = { "doc:select-to-end-of-doc" },
    ["G"] = { "doc:select-to-start-of-doc" },

    ["C-u"] = { "doc:select-to-previous-page" },
    ["C-d"] = { "doc:select-to-next-page" },

    [">"] =   { "doc:indent" },
    ["\\<"] = { "doc:unindent" },

    [":"] = "core:find-command",
  },

  VISUAL_BLOCK = {
    ["<ESC>"] = { modal.go_to_mode(mode.NORMAL), "doc:select-none" },
    ["C-c"] = { modal.go_to_mode(mode.NORMAL), "doc:select-none" },
    ["y"] = { "doc:copy", "doc:select-none", modal.go_to_mode(mode.NORMAL) }, -- TODO: registers

    ["<up>"] = { "doc:create-cursor-previous-line" },
    ["<down>"] = { "doc:create-cursor-next-line" },
    ["<left>"] = { "doc:select-to-previous-char" },
    ["<right>"] = { "doc:select-to-next-char" },
  },
}

local helpers = {
    ["C-w"] = {
        { "v", "doc:split-left" },
        { "s", "doc:split-up" },
    },

    ["c"] = {
        { "w", "Next word" },
        { "W", "Next WORD" },
        { "0", "Start of line" },
        { "b", "prev word" },
        { "B", "prev WORD" },
        { "e", "Next end of word" },
        { "$", "End of line" },
        { "^", "Start of line (non whitespace)" },
        { "gg", "First line" },
        { "G", "Last line" },
    },

    ["ci"] = {
        { "w", "inner word" },
        { "p", "inner paragraph" },
    },

    ["d"] = {
        { "d", "Delete line" },
        { "w", "Next word" },
        { "W", "Next WORD" },
        { "b", "Prev word" },
        { "B", "Prev WORD" },
        { "_", "Start of line (non whitespace)" },
        { "^", "Start of line (non whitespace)" },
        { "$", "End of line" },
        { "gg", "First line" },
        { "G", "Last line" },

    },

    ["di"] = {
        { "w", "inner word" },
    },

    -- Some movements are implemented manually as they do not seem to work normally
    ["v"] = {
        { "w", "Next word" },
        { "W", "Next WORD" },
        { "0", "Start of line" },
        { "b", "prev word" },
        { "B", "prev WORD" },
        { "e", "Next end of word" },
        { "$", "End of line" },
        { "^", "Start of line (non whitespace)" },
        { "_", "Start of line (non whitespace)" },
        { "gg", "First line" },
        { "G", "Last line" },
    },

    ["vi"] = {
      { "w", "inner word" },
      { "p", "inner paragraph" },
    },
}

config.plugins.modal.helpers.NORMAL = helpers
config.plugins.modal.helpers.VISUAL = helpers
config.plugins.modal.helpers.VISUAL_LINE = helpers
config.plugins.modal.helpers.VISUAL_BLOCK = helpers

config.plugins.modal.carets.NORMAL = modal.caret_style.BAR
config.plugins.modal.carets.INSERT = modal.caret_style.NORMAL
config.plugins.modal.carets.VISUAL = modal.caret_style.BAR
config.plugins.modal.carets.VISUAL_LINE = modal.caret_style.BAR
config.plugins.modal.carets.VISUAL_BLOCK = modal.caret_style.BAR

config.plugins.modal.on_key_callbacks.NORMAL = modal.on_key_command_only
config.plugins.modal.on_key_callbacks.VISUAL = modal.on_key_command_only
config.plugins.modal.on_key_callbacks.INSERT = modal.on_key_passtrought
config.plugins.modal.on_key_callbacks.VISUAL_LINE = modal.on_key_command_only
config.plugins.modal.on_key_callbacks.VISUAL_BLOCK = modal.on_key_command_only

command.add(nil, {
  ["w"] = function() command.perform("doc:save") end,
  ["q"] = function() command.perform("doc:quit") end,
  ["wq"] = function()
    command.perform("doc:save")
    command.perform("doc:quit")
  end,
  ["e"] = function() command.perform("core:open-file") end,
})

-- commands that are only available in docview
command.add("core.docview", {
    ["q"] = function() command.perform("root:close") end
})

return modal_vim
