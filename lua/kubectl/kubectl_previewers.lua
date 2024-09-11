local utils = require("telescope.utils")
local putils = require("telescope.previewers.utils")
local defaulter = utils.make_default_callable
local previewers = require("telescope.previewers")

local k_utils = require("kubectl.utils")

local k_previewers = {}

k_previewers.resource_previewer = defaulter(function(opts)
	return previewers.new_buffer_previewer({
		title = "YAML",

		get_buffer_by_name = function(_, entry)
			return entry.id
		end,

		define_preview = function(self, entry)
			opts = {
				namespace = entry.value.metadata.namespace,
				output = "yaml",
			}

			local query = k_utils.parse_opts(opts, entry.value.kind)

			local get_svc_cmd = vim.iter({
				"kubectl",
				"get",
				entry.value.kind,
				query,
				entry.value.metadata.name,
			})
				:flatten(math.huge)
				:totable()

			putils.job_maker(get_svc_cmd, self.state.bufnr, {
				value = entry.value,
				bufname = self.state.bufname,
				cwd = opts.cwd,
				callback = function()
					entry.bufnr = self.state.bufnr

					putils.highlighter(self.state.bufnr, "yaml")
				end,
			})
		end,

		keep_last_buf = true,
	})
end, {})

return k_previewers
