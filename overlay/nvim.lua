-- SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
-- SPDX-License-Identifier: MIT
--
-- Project-local Neovim configuration for QGIS development with the
-- qgis-dev-env sidecar (SRS group E). Symlinked into the checkout as
-- .nvim.lua and loaded via exrc. Design rules:
--   * every long task runs asynchronously (vim.system) — the editor never blocks
--   * failures land in the quickfix list with a working errorformat
--   * degrades gracefully: no plugin is required; which-key/telescope are
--     used opportunistically when present; nothing global is mutated

if vim.g.qgis_dev_env_loaded then
  return
end
vim.g.qgis_dev_env_loaded = true

local this_file = debug.getinfo(1, 'S').source:sub(2)
local static_root = vim.fs.dirname(this_file)

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = 'QGIS dev' })
end

-- The checkout the current buffer belongs to (worktree-aware, FR-W4).
local function root()
  local r = vim.fs.root(0, { '.nvim.lua', 'src' })
  return r or static_root
end

if vim.fn.executable('qgis-dev') ~= 1 then
  notify('qgis-dev not on PATH — run `direnv allow` in ' .. static_root .. ' and restart Neovim', vim.log.levels.WARN)
end

-- ---------------------------------------------------------------- task core
local last_lines = { 'No task has run yet.' }
local last_title = 'qgis-dev'

local efm_build = table.concat({
  '%f:%l:%c: %trror: %m',
  '%f:%l:%c: %tarning: %m',
  '%f:%l:%c: %tote: %m',
  '%f:%l:%c: %m',
  '%f:%l: %m',
}, ',')

local function show_output_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, last_lines)
  vim.bo[buf].modifiable = false
  pcall(vim.api.nvim_buf_set_name, buf, ('qgis-dev://%s #%d'):format(last_title, buf))
  vim.cmd.split()
  vim.api.nvim_win_set_buf(0, buf)
end

local function to_quickfix(title, lines, efm)
  vim.fn.setqflist({}, ' ', { title = title, lines = lines, efm = efm or efm_build })
  vim.cmd('copen')
  vim.cmd.wincmd('p')
end

--- Run a qgis-dev task asynchronously.
--- @param args string[]  subcommand + arguments
--- @param opts? {title?:string, efm?:string, show?:'qf'|'buffer', qf_on_success?:boolean, on_success?:fun()}
local function task(args, opts)
  opts = opts or {}
  local title = opts.title or ('qgis-dev ' .. args[1])
  notify(title .. ' …')
  local uv = vim.uv or vim.loop
  local t0 = uv.hrtime()
  vim.system(
    vim.list_extend({ 'qgis-dev' }, args),
    { cwd = root(), text = true },
    vim.schedule_wrap(function(res)
      local secs = string.format('%.1fs', (uv.hrtime() - t0) / 1e9)
      local out = (res.stdout or '') .. (res.stderr or '')
      last_lines = vim.split(out, '\n', { trimempty = true })
      if #last_lines == 0 then
        last_lines = { '(no output)' }
      end
      last_title = title
      if res.code == 0 then
        notify(('%s ✓ (%s)'):format(title, secs))
        if opts.show == 'buffer' then
          show_output_buffer()
        elseif opts.qf_on_success then
          to_quickfix(title, last_lines, opts.efm)
        end
        if opts.on_success then
          opts.on_success()
        end
      else
        if opts.show == 'buffer' then
          show_output_buffer()
        else
          to_quickfix(title, last_lines, opts.efm)
        end
        notify(('%s ✗ exit %d (%s)'):format(title, res.code, secs), vim.log.levels.ERROR)
      end
    end)
  )
end

--- Run a qgis-dev command synchronously and return its stdout lines (pickers).
local function capture(args)
  local res = vim.system(vim.list_extend({ 'qgis-dev' }, args), { cwd = root(), text = true }):wait()
  if res.code ~= 0 then
    notify('qgis-dev ' .. args[1] .. ' failed:\n' .. (res.stderr or ''), vim.log.levels.ERROR)
    return nil
  end
  return vim.split(res.stdout or '', '\n', { trimempty = true })
end

--- Launch a detached GUI task (run QGIS, profilers, docs server).
local function detached(args, msg)
  vim.system(vim.list_extend({ 'qgis-dev' }, args), { cwd = root(), detach = true })
  notify(msg)
end

local function map(lhs, fn, desc)
  vim.keymap.set('n', lhs, fn, { desc = desc, silent = true })
end

-- ------------------------------------------------------- build & configure
map('<leader>pc', function()
  task({ 'configure' })
end, 'Configure (cmake)')

map('<leader>pb', function()
  task({ 'build' }, { title = 'build' })
end, 'Build (all)')

map('<leader>pB', function()
  local targets = capture({ 'targets' })
  if not targets then
    return
  end
  vim.ui.select(targets, { prompt = 'Ninja target' }, function(t)
    if t then
      task({ 'build', t }, { title = 'build ' .. t })
    end
  end)
end, 'Build target…')

map('<leader>pC', function()
  if vim.fn.confirm('Run ninja clean?', '&Yes\n&No', 2) == 1 then
    task({ 'clean' })
  end
end, 'Clean')

map('<leader>pk', function()
  local flags = capture({ 'flags' })
  if not flags then
    return
  end
  vim.ui.select(flags, { prompt = 'CMake cache flag' }, function(sel)
    if not sel then
      return
    end
    local name, typ, cur = sel:match('^([^:]+):([^=]+)=(.*)$')
    if not name then
      return
    end
    if typ == 'BOOL' then
      local new = (cur == 'ON' or cur == 'TRUE' or cur == '1') and 'OFF' or 'ON'
      task({ 'configure', '-D' .. name .. ':BOOL=' .. new }, { title = name .. ' → ' .. new })
    else
      vim.ui.input({ prompt = name .. ' = ', default = cur }, function(v)
        if v and v ~= cur then
          task({ 'configure', '-D' .. name .. ':' .. typ .. '=' .. v }, { title = name .. ' → ' .. v })
        end
      end)
    end
  end)
end, 'CMake flags…')

map('<leader>px', function()
  local profiles = capture({ 'profile', 'list' })
  if not profiles then
    return
  end
  vim.ui.select(profiles, { prompt = 'Build profile' }, function(p)
    if p then
      task({ 'profile', p }, { title = 'profile ' .. p })
    end
  end)
end, 'Build profile…')

-- ------------------------------------------------------------- run & test
map('<leader>pr', function()
  detached({ 'run' }, 'QGIS launched (isolated throwaway profile)')
end, 'Run QGIS')

map('<leader>pt', function()
  task({ 'test' }, { title = 'ctest' })
end, 'Test (ctest)')

map('<leader>pT', function()
  task({ 'test-file', vim.fn.expand('%:p') }, { title = 'ctest ' .. vim.fn.expand('%:t:r') })
end, 'Test this file')

-- -------------------------------------------------------------------- docs
map('<leader>pd', function()
  task({ 'docs' }, { title = 'apidoc' })
end, 'Docs (apidoc)')

map('<leader>pD', function()
  detached({ 'docs-serve' }, 'Docs served at http://localhost:8000')
end, 'Docs serve')

-- --------------------------------------------------- standards & formatting
local efm_lint = '%f:%l:%c: %m,%f:%l: %m'

map('<leader>pp', function()
  task({ 'precommit' }, { title = 'pre-commit (changed)', efm = efm_lint })
end, 'Pre-commit (changed)')

map('<leader>pP', function()
  task({ 'precommit', '--branch' }, { title = 'pre-commit (branch)', efm = efm_lint })
end, 'Pre-commit (branch)')

map('<leader>pf', function()
  vim.lsp.buf.format({ async = true })
end, 'Format buffer (LSP)')

map('<leader>pl', function()
  task({ 'tidy', vim.fn.expand('%:p') }, { title = 'clang-tidy', efm = efm_build, qf_on_success = true })
end, 'Lint file (clang-tidy)')

map('<leader>pg', function()
  task({ 'tags' })
end, 'Refresh tags')

-- ------------------------------------------------- performance & telemetry
map('<leader>ps', function()
  task({ 'ccache-stats' }, { show = 'buffer', title = 'ccache stats' })
end, 'ccache stats')

map('<leader>pS', function()
  task({ 'ccache-zero' }, { title = 'ccache zero stats' })
end, 'ccache zero stats')

map('<leader>pe', function()
  task({ 'perf', 'build-toggle' }, { title = 'perf boost toggle' })
end, 'Perf boost toggle')

map('<leader>pG', function()
  task({ 'stats' }, { show = 'buffer', title = 'build-time trends' })
end, 'Build-time trends')

map('<leader>pv', function()
  task({ 'doctor' }, { show = 'buffer', title = 'doctor' })
end, 'Doctor (health check)')

map('<leader>pq', show_output_buffer, 'Last task output')

-- --------------------------------------------------------------- worktrees
local function worktree_paths()
  local lines = capture({ 'worktree', 'porcelain' }) or {}
  local paths = {}
  for _, l in ipairs(lines) do
    local p = l:match('^worktree (.+)$')
    if p then
      table.insert(paths, p)
    end
  end
  return paths
end

map('<leader>pwn', function()
  vim.ui.input({ prompt = 'New worktree branch: ' }, function(branch)
    if not branch or branch == '' then
      return
    end
    vim.ui.input({ prompt = 'Base ref: ', default = 'master' }, function(base)
      task({ 'worktree', 'add', branch, base or 'master' }, { title = 'worktree add ' .. branch })
    end)
  end)
end, 'New worktree…')

map('<leader>pwl', function()
  vim.ui.select(worktree_paths(), { prompt = 'Switch to worktree' }, function(p)
    if p then
      vim.cmd.tcd(vim.fn.fnameescape(p))
      notify('tab-local cwd → ' .. p .. ' (tasks and LSP follow)')
    end
  end)
end, 'List/switch worktree…')

map('<leader>pws', function()
  task({ 'worktree', 'status' }, { show = 'buffer', title = 'worktree status' })
end, 'Worktree dashboard')

map('<leader>pwD', function()
  vim.ui.select(worktree_paths(), { prompt = 'Remove worktree' }, function(p)
    if not p then
      return
    end
    if vim.fn.confirm('Remove worktree ' .. p .. '?', '&Yes\n&No', 2) == 1 then
      task({ 'worktree', 'remove', p }, { title = 'worktree remove' })
    end
  end)
end, 'Remove worktree…')

map('<leader>pwp', function()
  task({ 'worktree', 'prune' })
end, 'Prune stale worktrees')

-- ------------------------------------------------------------ QA / analyse
map('<leader>pam', function()
  task({ 'qa', 'memcheck' }, { title = 'valgrind memcheck', efm = efm_lint, qf_on_success = true })
end, 'Valgrind memcheck')

map('<leader>pas', function()
  task({ 'qa', 'asan' }, { title = 'ASan/UBSan run', efm = efm_build })
end, 'Sanitizer run')

map('<leader>pah', function()
  detached({ 'qa', 'heaptrack' }, 'heaptrack running — GUI opens when QGIS exits')
end, 'Heap profile (heaptrack)')

map('<leader>pac', function()
  detached({ 'qa', 'perf' }, 'perf recording — hotspot opens when QGIS exits')
end, 'CPU profile (perf)')

map('<leader>pag', function()
  detached({ 'qa', 'gammaray' }, 'GammaRay attaching to running QGIS')
end, 'GammaRay attach')

map('<leader>paa', function()
  task({ 'qa', 'cppcheck', vim.fn.expand('%:p') }, { title = 'cppcheck', efm = efm_lint, qf_on_success = true })
end, 'Cppcheck file')

map('<leader>pal', function()
  task({ 'qa', 'list' }, { show = 'buffer', title = 'QA reports' })
end, 'Past QA reports')

-- ------------------------------------------------------ which-key labels
pcall(function()
  require('which-key').add({
    { '<leader>p', group = 'project (QGIS)' },
    { '<leader>pw', group = 'worktrees' },
    { '<leader>pa', group = 'analyse (QA)' },
  })
end)

-- ---------------------------------------------------------------- LSP wiring
-- Native LSP config (Neovim ≥0.11): attach the devshell's servers with
-- QGIS-appropriate settings. pcall-guarded so a user's own config wins.
vim.opt.tags:append(static_root .. '/.dev-env/tags')

local function enable_lsp(name, cfg)
  if vim.fn.executable(cfg.cmd[1]) ~= 1 then
    return
  end
  pcall(function()
    vim.lsp.config(name, cfg)
    vim.lsp.enable(name)
  end)
end

if vim.lsp.config and vim.lsp.enable then
  enable_lsp('clangd', {
    cmd = {
      'clangd',
      '--background-index',
      '--completion-style=detailed',
      '--header-insertion=iwyu',
      -- Nix-provided GCC: glob whitelist, no committed store paths (SRS C6)
      '--query-driver=/nix/store/*/bin/*',
    },
    filetypes = { 'c', 'cpp' },
    root_markers = { '.clangd', 'CMakeLists.txt' },
  })
  enable_lsp('basedpyright', {
    cmd = { 'basedpyright-langserver', '--stdio' },
    filetypes = { 'python' },
    root_markers = { 'pyrightconfig.json' },
  })
  enable_lsp('neocmakelsp', {
    cmd = { 'neocmakelsp', '--stdio' },
    filetypes = { 'cmake' },
    root_markers = { 'CMakeLists.txt' },
  })
  enable_lsp('nixd', {
    cmd = { 'nixd' },
    filetypes = { 'nix' },
    root_markers = { 'flake.nix' },
  })
  enable_lsp('bashls', {
    cmd = { 'bash-language-server', 'start' },
    filetypes = { 'sh', 'bash' },
    root_markers = { '.git' },
  })
end
