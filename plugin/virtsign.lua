local namespace = vim.api.nvim_create_namespace("virtsign")
local augroup = vim.api.nvim_create_augroup("virtsign", {})

if vim.g.virtsign_enabled == nil then
	vim.g.virtsign_enabled = true
end

if vim.g.virtsign_config == nil then
	vim.g.virtsign_config = {
		position = "right_align",
		ignored_namespaces = { "gitsigns_.*" },
		margin_right = 0,
		margin_left = 1,
	}
end

---@generic F: fun(...)
---@param func F
---@param delay? number
---@return F
local function debounce(func, delay)
	delay = delay or 50
	---@diagnostic disable-next-line: undefined-field
	local timer = vim.uv.new_timer()

	local wrapped_fn = function(...)
		local argv = { ... }
		local argc = select("#", ...)

		timer:start(delay, 0, function()
			pcall(vim.schedule_wrap(func), unpack(argv, 1, argc))
		end)
	end

	return wrapped_fn
end

---@generic V
---@class DefaultList<V>: table<V>
DefaultList = {}

---@generic V
---@param default V
---@return DefaultList<V>
function DefaultList.new(default)
	local obj = setmetatable({}, {
		__index = function(table, key)
			local value = rawget(table, key)
			if value then
				return value
			end

			rawset(table, key, vim.deepcopy(default))
			return rawget(table, key)
		end,
	})

	return obj
end

---@alias BufferSign string[]

---@class Virtsigns
---@field buffers DefaultList<DefaultList<BufferSign[]>>
---@field ignored_namespaces number[]
local Virtsigns = {}

function Virtsigns:clear()
	self.buffers = DefaultList.new(DefaultList.new({}))

	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	end

	self.ignored_namespaces = {}
	local config_ignored_namespaces = vim.g.virtsign_config.ignored_namespaces
	if config_ignored_namespaces then
		for name, id in pairs(vim.api.nvim_get_namespaces()) do
			for _, ns in ipairs(config_ignored_namespaces) do
				if string.match(name, ns) then
					table.insert(self.ignored_namespaces, id)
				end
			end
		end
	end
end

---@return Virtsigns
function Virtsigns.new()
	local obj = setmetatable({
		buffers = nil,
		ignored_namespaces = {},
	}, Virtsigns)
	obj:clear()
	return obj
end

function Virtsigns:draw()
	---@type UserConfig
	local config = vim.g.virtsign_config
	local margin = string.rep(" ", config.margin_right)
	local virt_text_pos = nil
	local virt_text_win_col = nil

	if config.position == "colorcolumn" then
		virt_text_win_col = tonumber(vim.o.colorcolumn) + config.margin_left
	elseif type(config.position) == "number" then
		virt_text_win_col = tonumber(config.position)
	elseif config.position == "right_align" then
		virt_text_pos = "right_align"
	end

	for buf, rows in pairs(self.buffers) do
		for row, signs in pairs(rows) do
			table.insert(signs, { margin, "VirtsignMargin" })
			vim.api.nvim_buf_set_extmark(buf, namespace, row, 0, {
				virt_text = signs,
				virt_text_pos = virt_text_pos,
				virt_text_win_col = virt_text_win_col,
				hl_mode = "combine",
			})
		end
	end
end

Virtsigns.__index = Virtsigns

local virtsigns = Virtsigns.new()

---@param buf number
local update_virtsigns_for_buffer = function(buf)
	local enabled = vim.b[buf].virtsign_enabled
	if enabled ~= nil and not enabled then
		return
	end

	local extmarks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })

	for _, extmark in ipairs(extmarks) do
		local _, row, _, details = unpack(extmark)

		if details.sign_text and not vim.tbl_contains(virtsigns.ignored_namespaces, details.ns_id) then
			table.insert(virtsigns.buffers[buf][row], {
				details.sign_text,
				details.sign_hl_group,
			})
		end
	end
end

local update_virtsigns_for_all_visible_buffers = debounce(function()
	virtsigns:clear()

	if not vim.g.virtsign_enabled then
		return
	end

	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		update_virtsigns_for_buffer(vim.api.nvim_win_get_buf(win))
	end

	virtsigns:draw()
end)

vim.api.nvim_create_autocmd(
	{ "CursorMoved", "CursorMovedI", "TextChanged", "DiagnosticChanged", "CmdlineEnter", "CmdlineLeave", "User" },
	{ callback = update_virtsigns_for_all_visible_buffers, group = augroup }
)

vim.api.nvim_create_user_command("Virtsign", function(args)
	local cmd = args.fargs[1]
	if cmd == "toggle" then
		require("virtsign").toggle()
	elseif cmd == "toggle_buffer" then
		require("virtsign").toggle_buffer()
	elseif cmd == "disable" then
		vim.g.virtsign_enabled = false
	elseif cmd == "enable" then
		vim.g.virtsign_enabled = true
	end
end, {
	nargs = 1,
	desc = "Enable or disable the Virtsign plugin",
	complete = function()
		return { "toggle", "toggle_buffer", "disable", "enable" }
	end,
})

vim.api.nvim_set_hl(0, "VirtsignMargin", { link = "Normal" })
