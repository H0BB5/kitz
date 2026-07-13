-- kitz — Neovim integration.
-- Drop into your config and `require('kitz').setup()`, or paste the body into init.lua.
--
--   :Kitz  [type] [name]      open kitz in a terminal split (interactive)
--   :'<,'>KitzVisual [type] [name]   selection becomes the artifact BODY (--message-file)
--   :KitzGen [type] [name]    ghostwrite with Claude (prompts for intent)
--   :'<,'>KitzGen [type] [name]  selection becomes the generation INTENT (Claude drafts it)
--
-- The body command writes the selection to a temp file (`--message-file`);
-- the generate command passes the selection as `--intent` so Claude drafts it.

local M = {}

local function run_term(cmd)
  vim.cmd('botright 15split | terminal ' .. cmd)
  vim.cmd('startinsert')
end

-- Open kitz interactively (fzf pickers run fine inside :terminal).
local function kitz(opts)
  run_term('kitz ' .. (opts.args or ''))
end

-- Visual selection -> artifact body via a temp file.
local function kitz_visual(opts)
  local s = vim.fn.getpos("'<")[2]
  local e = vim.fn.getpos("'>")[2]
  local lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
  local tmp = vim.fn.tempname()
  vim.fn.writefile(lines, tmp)
  -- args: "<type> <name>"; default type 'command' if only a name is given.
  local args = vim.split(opts.args or '', '%s+', { trimempty = true })
  local typ, name = 'command', nil
  if #args == 2 then typ, name = args[1], args[2]
  elseif #args == 1 then name = args[1] end
  local cmd = string.format('kitz --type %s %s --message-file %s',
    typ, name and ('"' .. name .. '"') or '', vim.fn.shellescape(tmp))
  run_term(cmd)
end

-- Ghostwrite with Claude. In visual mode the selection is the intent brief.
local function kitz_gen(opts)
  local typ, name = 'command', nil
  local args = vim.split(opts.args or '', '%s+', { trimempty = true })
  if #args == 2 then typ, name = args[1], args[2]
  elseif #args == 1 then name = args[1] end
  local namearg = name and ('"' .. name .. '"') or ''
  if opts.range and opts.range > 0 then
    local s = vim.fn.getpos("'<")[2]
    local e = vim.fn.getpos("'>")[2]
    local intent = table.concat(vim.api.nvim_buf_get_lines(0, s - 1, e, false), ' ')
    run_term(string.format('kitz --type %s %s -g -i %s', typ, namearg, vim.fn.shellescape(intent)))
  else
    run_term(string.format('kitz --type %s %s -g', typ, namearg))
  end
end

function M.setup(o)
  o = o or {}
  vim.api.nvim_create_user_command('Kitz', kitz, { nargs = '*' })
  vim.api.nvim_create_user_command('KitzVisual', kitz_visual, { nargs = '*', range = true })
  vim.api.nvim_create_user_command('KitzGen', kitz_gen, { nargs = '*', range = true })
  if o.keymap ~= false then
    vim.keymap.set('n', o.keymap or '<leader>kz', ':Kitz<CR>', { desc = 'kitz: new artifact', silent = true })
    vim.keymap.set('v', o.visual_keymap or '<leader>kz', ':KitzVisual<CR>', { desc = 'kitz: selection -> body' })
    vim.keymap.set('n', o.gen_keymap or '<leader>kg', ':KitzGen<CR>', { desc = 'kitz: ghostwrite with Claude', silent = true })
    vim.keymap.set('v', o.gen_keymap or '<leader>kg', ':KitzGen<CR>', { desc = 'kitz: selection -> Claude draft' })
  end
end

return M
