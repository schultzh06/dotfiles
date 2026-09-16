vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.pack.add({
  "https://github.com/catppuccin/nvim",
  "https://github.com/ibhagwan/fzf-lua",
})

require("catppuccin").setup({
  flavour = "mocha",
  transparent_background = true,
})

vim.cmd.colorscheme "catppuccin"
vim.opt.number = true          -- absolute line numbers
vim.opt.relativenumber = true  -- relative; both on = hybrid, current line absolute

vim.opt.tabstop = 4            -- width a literal tab renders as
vim.opt.shiftwidth = 4         -- width of one indent level (>>, <<, autoindent)
vim.opt.expandtab = true       -- insert spaces instead of tab characters
vim.opt.softtabstop = 4        -- what Tab/Backspace do in insert mode

local fzf = function(fn, opts)
  return function() require("fzf-lua")[fn](opts or {}) end
end

vim.keymap.set("n", "<leader>ff", fzf("files"))        -- files in cwd
vim.keymap.set("n", "<leader>fd", function()           -- files beside this one
  require("fzf-lua").files({ cwd = vim.fn.expand("%:h") })
end)
vim.keymap.set("n", "<leader>fg", fzf("live_grep"))    -- grep the project
vim.keymap.set("n", "<leader>fb", fzf("buffers"))      -- switch buffer
vim.keymap.set("n", "<leader>fh", fzf("helptags"))     -- search :help
vim.keymap.set("n", "<leader>fr", fzf("resume"))       -- reopen last picker
vim.keymap.set("n", "<leader>fw", fzf("grep_cword"))   -- grep word under cursor

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>")           -- clear search highlight
vim.keymap.set({"n","v"}, "<leader>y", '"+y')                  -- yank to system clipboard
vim.keymap.set("v", "<", "<gv")                                -- keep selection when indenting
vim.keymap.set("v", ">", ">gv")
vim.keymap.set("v", "J", ":m '>+1<cr>gv=gv")                   -- move selection down
vim.keymap.set("v", "K", ":m '<-2<cr>gv=gv")                   -- move selection up

vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<cr>")
vim.keymap.set("n", "<S-h>", "<cmd>bprevious<cr>")
vim.keymap.set("n", "<S-l>", "<cmd>bnext<cr>")

vim.keymap.set("n", "<C-h>", "<C-w>h")   -- move between splits
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-l>", "<C-w>l")
