local namespace = vim.api.nvim_create_namespace("virtsign")
local augroup = vim.api.nvim_create_augroup("virtsign", {})

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

---@class BufferSign
---@field hl string
---@field text string

---@class Virtsigns
---@field buffers DefaultList<DefaultList<BufferSign[]>>
local Virtsigns = {}

function Virtsigns:clear()
	self.buffers = DefaultList.new(DefaultList.new({}))
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	end
end

---@return Virtsigns
function Virtsigns.new()
	local obj = setmetatable({ buffers = nil }, Virtsigns)
	obj:clear()
	return obj
end

function Virtsigns:draw()
	for buf, rows in pairs(self.buffers) do
		for row, signs in pairs(rows) do
			local virt_text = {}
			for _, sign in ipairs(signs) do
				table.insert(virt_text, { sign.text, sign.hl })
			end
			vim.api.nvim_buf_set_extmark(buf, namespace, row, 0, {
				virt_text = virt_text,
				virt_text_pos = "right_align",
			})
		end
	end
end

Virtsigns.__index = Virtsigns

local virtsigns = Virtsigns.new()

---@param buf number
local update_virtsigns_for_buffer = function(buf)
	local extmarks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })

	for _, extmark in ipairs(extmarks) do
		local _, row, _, details = unpack(extmark)

		if details.sign_text then
			table.insert(virtsigns.buffers[buf][row], {
				hl = details.sign_hl_group,
				text = details.sign_text,
			})
		end
	end
end

local update_virtsigns_for_all_buffers = debounce(function()
	virtsigns:clear()

	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		update_virtsigns_for_buffer(buf)
	end

	virtsigns:draw()
end)

vim.api.nvim_create_autocmd(
	{ "CursorHold", "CursorHoldI", "CursorMoved", "CursorMovedI", "TextChanged", "DiagnosticChanged", "User" },
	{ callback = update_virtsigns_for_all_buffers, group = augroup }
)
