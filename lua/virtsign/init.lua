local module = {}

---@class UserConfig Plugin configuration
---@field margin_right? number Margin to the right of the virtual signs
---@field margin_left? number Margin to the left of the virtual signs
---@field ignored_namespaces? string[] Namespaces to ignore when displaying signs
---@field position? string | number Position of the virtual signs. Can be "right", "colorcolumn", or a set column number

---Define optional user options. It is not necessary to call this function.
---Example:
---```lua
---require("virtsign").setup({
---	offset = 1,
---	ignored_namespaces = {"gitsigns_signs_"},
---})
---```
---@param opts UserConfig
function module.setup(opts)
	vim.g.virtsign_config = vim.tbl_deep_extend("force", vim.g.virtsign_config or {}, opts)
end

---Toggle the plugin on and off globally
function module.toggle()
	vim.g.virtsign_enabled = not vim.g.virtsign_enabled
end

---Toggle the plugin on and off for a specific buffer (or the current one if no buffer is provided)
---@param buf? number
function module.toggle_buffer(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	local buffer = vim.b[buf]
	buffer.virtsign_enabled = not buffer.virtsign_enabled
end

return module
