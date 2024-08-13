local module = {}

---@class UserConfig
---@field right_margin? number Margin to the right of the virtual signs
---@field ignored_namespaces? string[] Namespaces to ignore when displaying signs

---@type UserConfig
module.config = {}

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
	vim.tbl_deep_extend("force", module.config, opts)
end

---Toggle the plugin on and off globally
function module.toggle()
	vim.g.virtsign_enabled = not vim.g.virtsign_enabled
end

---Toggle the plugin on and off for a specific buffer (or the current one if no buffer is provided)
---@param buf? number
function module.toggle_buffer(buf)
	buf = buf or 0
	local enabled = vim.api.nvim_buf_get_var(buf, "virtsign_enabled")
	vim.api.nvim_buf_set_var(buf, "virtsign_enabled", not enabled)
end

return module
