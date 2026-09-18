vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.pack.add({
  "https://github.com/catppuccin/nvim",
  "https://github.com/ibhagwan/fzf-lua",
  "https://github.com/nvim-treesitter/nvim-treesitter",
  "https://github.com/MeanderingProgrammer/render-markdown.nvim",
  "https://github.com/neovim/nvim-lspconfig",
  "https://github.com/lewis6991/gitsigns.nvim",
  "https://github.com/folke/which-key.nvim",
})

require("catppuccin").setup({
  flavour = "mocha",
  transparent_background = true,
})

-- nvim-treesitter's main branch (required for Neovim 0.12+, which is what
-- render-markdown.nvim needs to parse markdown) dropped the old :TSInstall
-- command entirely in favor of this Lua API -- ":TSInstall" erroring as
-- "not an editor command" is expected on this branch, not a sign anything
-- installed wrong.
require("nvim-treesitter").install({
  "markdown", "markdown_inline", "lua", "vim", "vimdoc", "bash", "query",
}):wait(300000) -- no-op (near-instant) once already installed; only blocks on first run

-- Also unlike the old plugin, highlighting isn't automatic -- it's a core
-- Neovim feature (:h treesitter-highlight) this plugin just supplies
-- parsers/queries for. pcall guards filetypes with no parser installed.
vim.api.nvim_create_autocmd("FileType", {
  callback = function() pcall(vim.treesitter.start) end,
})

require("render-markdown").setup({})

-- ---- LSP + completion ----
-- nvim-lspconfig here isn't "configured" via setup() -- as of Nvim 0.11+ it
-- just ships server definitions under lsp/*.lua that vim.lsp.config/enable
-- discover automatically once the plugin is on runtimepath (which
-- vim.pack.add already did above). Add a server's name below once its
-- binary is installed (e.g. `pacman -S lua-language-server` for lua_ls) --
-- vim.lsp.enable() for one that isn't on $PATH just never attaches, no
-- error either way. `:checkhealth vim.lsp` shows what's actually active.
vim.lsp.enable({
  "lua_ls",       -- lua-language-server (pacman)
  "bashls",       -- bash-language-server (pacman)
  "pyright",      -- pyright (pacman)
  "clangd",       -- clang (pacman) -- C/C++
  "ts_ls",        -- typescript-language-server (pacman) -- JS/TS
  "html",         -- vscode-langservers-extracted (AUR)
  "cssls",        -- vscode-langservers-extracted (AUR)
  "jsonls",       -- vscode-langservers-extracted (AUR)
  "yamlls",       -- yaml-language-server (pacman)
  -- Java: works for basic completion/diagnostics/goto out of the box (it
  -- auto-manages its own per-project workspace dir), but nvim-jdtls is the
  -- recommended plugin if you want debugging/refactoring on top later --
  -- not added here, this is just the base LSP.
  "jdtls",        -- jdtls (AUR) -- also needs a JVM: jdk-openjdk (pacman)
})

-- "menuone" so the menu still shows with only one candidate (without it, a
-- single match is silently the only option and nothing visibly happens --
-- easy to mistake for "completion isn't working"); "noselect"+"popup" per
-- :h lsp-completion's own recommended settings.
vim.opt.completeopt = { "menu", "menuone", "noselect", "popup" }

-- Diagnostics, hover (K), goto-definition (grd), rename (grn), code action
-- (gra), references (grr) etc. are all built-in default LSP keymaps as of
-- Nvim 0.11+ (:h lsp-defaults) -- not redefined here on purpose.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
      -- autotrigger alone only fires on the server's declared
      -- triggerCharacters (mostly punctuation/whitespace for lua_ls, per
      -- :h lsp-autocompletion) -- not plain letters, so typing a fresh
      -- identifier from scratch wouldn't show anything. This is the
      -- documented way to get suggestions on every keystroke instead.
      vim.api.nvim_create_autocmd("InsertCharPre", {
        buffer = args.buf,
        callback = function() vim.lsp.completion.get() end,
      })
    end
  end,
})
vim.keymap.set("i", "<C-Space>", function() vim.lsp.completion.get() end)

-- ---- git ----
require("gitsigns").setup({
  on_attach = function(bufnr)
    local function map(mode, l, r) vim.keymap.set(mode, l, r, { buffer = bufnr }) end
    map("n", "]h", require("gitsigns").next_hunk)
    map("n", "[h", require("gitsigns").prev_hunk)
    map("n", "<leader>hs", require("gitsigns").stage_hunk)
    map("n", "<leader>hr", require("gitsigns").reset_hunk)
    map("n", "<leader>hp", require("gitsigns").preview_hunk)
    map("n", "<leader>hb", require("gitsigns").blame_line)
  end,
})

-- ---- which-key ----
require("which-key").setup({})
require("which-key").add({
  { "<leader>f", group = "find" },
  { "<leader>h", group = "git hunk" },
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
