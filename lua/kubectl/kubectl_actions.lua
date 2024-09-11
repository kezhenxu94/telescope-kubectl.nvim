local Job = require("plenary.job")

local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local utils = require("telescope.utils")

local store = require("kubectl.store")
local k_utils = require("kubectl.utils")

local M = {}

function M.select_context(opts)
	opts = opts or {}

	return function(prompt_bufnr)
		local selection = action_state.get_selected_entry()
		if not selection then
			return
		end

		store.set("context", selection.value)

		print("Switched to context:", selection.value)

		actions.close(prompt_bufnr)

		opts.namespace = opts.namespace or ""

		require("kubectl").get_services(opts)
	end
end

function M.select_pod(opts)
	return function(prompt_bufnr)
		local selection = action_state.get_selected_entry()
		if not selection then
			return
		end
		actions.close(prompt_bufnr)

		require("kubectl").get_containers(selection.value, opts)
	end
end

function M.pod_container_shell(opts, pod)
	return function(prompt_bufnr)
		local selection = action_state.get_selected_entry()
		actions.close(prompt_bufnr)

		opts.namespace = pod.metadata.namespace
		opts.container = selection.value.name
		opts.stdin = true
		opts.tty = true
		opts.output = nil

		local command = vim.iter({
			"kubectl",
			"exec",
			k_utils.parse_opts(opts, "containers"),
			pod.metadata.name,
			"--",
			"bash",
		})
			:flatten(math.huge)
			:totable()

		vim.cmd.split()
		vim.cmd.terminal(table.concat(command, " "))
		vim.api.nvim_feedkeys("a", "t", false)
	end
end

function M.pod_log(pod, opts)
	return function(prompt_bufnr)
		local selection = action_state.get_selected_entry()
		if not selection then
			return
		end
		actions.close(prompt_bufnr)

		local log_output = {}
		vim.api.nvim_command(opts.wincmd or "new")
		local buf = vim.api.nvim_get_current_buf()

		local bufname = pod.metadata.name
		if selection then
			bufname = bufname .. "." .. selection.value.name
		end
		bufname = bufname .. ".log"
		vim.api.nvim_buf_set_name(0, bufname)

		vim.api.nvim_set_option_value("buftype", "nofile", { buf = 0 })
		vim.api.nvim_set_option_value("swapfile", false, { buf = 0 })
		vim.api.nvim_set_option_value("filetype", opts.filetype or "log", { buf = 0 })
		vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = 0 })
		vim.api.nvim_command("setlocal " .. (opts.wrap or "nowrap"))
		vim.api.nvim_command("setlocal cursorline")

		opts = {}
		opts.namespace = pod.metadata.namespace
		opts.output = nil
		if selection then
			opts.container = selection.value.name
		end

		local args = vim.iter({
			k_utils.parse_opts(opts, "logs"),
			"logs",
			"-f",
			pod.metadata.name,
		})
			:flatten(math.huge)
			:totable()

		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Retrieving log, please wait..." })

		local on_output = function(_, line)
			table.insert(log_output, line)

			pcall(vim.schedule_wrap(function()
				if vim.api.nvim_buf_is_valid(buf) then
					vim.api.nvim_buf_set_lines(buf, 0, -1, false, log_output)
				end
			end))
		end

		local job = Job:new({
			enable_recording = true,
			command = "kubectl",
			args = vim.iter(args):flatten(math.huge):totable(),
			on_stdout = on_output,
			on_stderr = on_output,

			on_exit = function(_, status)
				if status == 0 then
					print("Log retrieval completed!")
				end
			end,
		})
		vim.api.nvim_buf_attach(buf, false, {
			on_detach = function()
				vim.uv.kill(job.pid, vim.uv.constants.SIGTERM)
			end,
		})
		job:start()
	end
end

function M.describe_resource(opts)
	return function(prompt_bufnr)
		local selection = action_state.get_selected_entry()
		if not selection then
			return
		end

		actions.close(prompt_bufnr)

		local log_output = {}
		vim.api.nvim_command(opts.wincmd or "new")
		local buf = vim.api.nvim_get_current_buf()

		local bufname = selection.value.metadata.name .. ".txt"
		vim.api.nvim_buf_set_name(0, bufname)
		vim.api.nvim_set_option_value("buftype", "nofile", { buf = 0 })
		vim.api.nvim_set_option_value("swapfile", false, { buf = 0 })
		vim.api.nvim_set_option_value("filetype", "txt", { buf = 0 })
		vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = 0 })
		vim.api.nvim_command("setlocal nowrap")
		vim.api.nvim_command("setlocal cursorline")

		opts = {}
		opts.namespace = selection.value.metadata.namespace
		opts.output = nil

		local args = vim.iter({
			k_utils.parse_opts(opts, "description"),
			"describe",
			selection.value.kind,
			selection.value.metadata.name,
		})
			:flatten(math.huge)
			:totable()

		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Describing the resource, please wait..." })

		local on_output = function(_, line)
			table.insert(log_output, line)

			pcall(vim.schedule_wrap(function()
				if vim.api.nvim_buf_is_valid(buf) then
					vim.api.nvim_buf_set_lines(buf, 0, -1, false, log_output)
				end
			end))
		end

		local job = Job:new({
			enable_recording = true,
			command = "kubectl",
			args = vim.iter(args):flatten(math.huge):totable(),
			on_stdout = on_output,
			on_stderr = on_output,

			on_exit = function(_, status)
				if status == 0 then
					print("Describe resource completed!")
				else
					print("Error describing resource")
				end
			end,
		})
		vim.api.nvim_buf_attach(buf, false, {
			on_detach = function()
				vim.loop.kill(job.pid, vim.loop.constants.SIGTERM)
			end,
		})
		job:start()
	end
end

function M.edit_resource(opts)
	return function(prompt_bufnr)
		local selection = action_state.get_selected_entry()
		if not selection then
			return
		end
		actions.close(prompt_bufnr)

		local obj = selection.value

		opts.namespace = obj.metadata.namespace
		opts.output = nil

		local command = vim.iter({
			"kubectl",
			"edit",
			k_utils.parse_opts(opts, obj.kind),
			obj.kind .. "/" .. obj.metadata.name,
		})
			:flatten(math.huge)
			:totable()

		vim.cmd.split()
		vim.cmd.terminal(table.concat(command, " "))
		vim.api.nvim_feedkeys("a", "t", false)
	end
end

function M.scale_resource(opts)
	return function(prompt_bufnr)
		local selection = action_state.get_selected_entry()
		if not selection then
			return
		end

		local replicas = tonumber(vim.fn.input("Replicas: ", selection.value.spec.replicas))
		if not replicas then
			return
		elseif replicas < 0 then
			print("Invalid number of replicas")
			return
		end

		actions.close(prompt_bufnr)

		opts.namespace = selection.value.metadata.namespace
		opts.replicas = replicas

		local args = vim.iter({
			"scale",
			k_utils.parse_opts(opts, selection.value.kind),
			selection.value.kind,
			selection.value.metadata.name,
		})
			:flatten(math.huge)
			:totable()

		Job:new({
			enable_recording = true,
			command = "kubectl",
			args = vim.iter(args):flatten(math.huge):totable(),

			on_start = function()
				print("Scaling " .. selection.value.kind .. "...")
			end,

			on_exit = function(_, code)
				if code == 0 then
					print(selection.value.kind .. " scaled successfully!")
				else
					print("Error scaling deployment")
				end
			end,
		}):start()
	end
end

function M.delete_resource(opts)
	return function(prompt_bufnr)
		local selection = action_state.get_selected_entry()
		if not selection then
			return
		end

		local confirm =
			vim.fn.input("Delete " .. selection.value.kind .. "/" .. selection.value.metadata.name .. "? [y/N] ")
		if confirm ~= "y" then
			return
		end

		actions.close(prompt_bufnr)

		opts = {
			namespace = selection.value.metadata.namespace,
		}

		local args = vim.iter({
			"delete",
			selection.value.kind,
			k_utils.parse_opts(opts, selection.value.kind),
			selection.value.metadata.name,
		})
			:flatten(math.huge)
			:totable()

		Job:new({
			enable_recording = true,
			command = "kubectl",
			args = vim.iter(args):flatten(math.huge):totable(),

			on_start = function()
				print("Deleting " .. selection.value.kind .. "/" .. selection.value.metadata.name .. "...")
			end,

			on_exit = function(_, code)
				if code == 0 then
					print("Resource deleted successfully!")
				else
					utils.notify("kubectl", {
						msg = "Error deleting resource",
						level = "ERROR",
					})
				end
			end,
		}):start()
	end
end

function M.port_forward(opts)
	opts = opts or {}

	return function(prompt_bufnr)
		local selection = action_state.get_selected_entry()
		if not selection then
			return
		end

		local available_ports = {}
		if selection.value.kind == "Pod" then
			for _, container in ipairs(selection.value.spec.containers) do
				if not container.ports then
					print("No ports available for port forwarding")
					goto continue
				end
				for _, port in ipairs(container.ports) do
					table.insert(available_ports, port.containerPort)
				end
				::continue::
			end
		end

		local ports

		if #available_ports > 0 then
			local p = table.concat(available_ports, ",")
			ports = vim.fn.input("Ports: ", p)
		end
		if not ports or ports == "" then
			return
		end

		ports = vim.split(ports, ",")
		for i, port in ipairs(ports) do
			if not string.match(port, "^[0-9]+:[0-9]+$") then
				ports[i] = port .. ":" .. port
			end
		end
		ports = table.concat(ports, ",")

		actions.close(prompt_bufnr)

		opts = {
			namespace = selection.value.metadata.namespace,
		}

		local args = vim.iter({
			"port-forward",
			k_utils.parse_opts(opts, "pods"),
			selection.value.kind .. "/" .. selection.value.metadata.name,
			ports,
		})
			:flatten(math.huge)
			:totable()

		local job = Job:new({
			enable_recording = true,
			command = "kubectl",
			args = vim.iter(args):flatten(math.huge):totable(),

			on_start = function()
				print("Forwarding ports...")
			end,

			on_exit = function(_, code)
				for i, v in ipairs(_G.port_forwards) do
					if v.resource == selection.value then
						table.remove(_G.port_forwards, i)
						break
					end
				end

				if code ~= 0 then
					print("Error forwarding ports")
				end
			end,

			on_stderr = function(error, data)
				require("telescope.log").error(error, data)
			end,
		})

		table.insert(_G.port_forwards, {
			job = job,
			opts = opts,
			resource = selection.value,
			ports = ports,
		})

		job:start()
	end
end

function M.set_image(opts, parent)
	return function(prompt_bufnr)
		local selection = action_state.get_selected_entry()
		if not selection then
			return
		end

		local image = vim.fn.input("Image: ", selection.value.image)
		if not image or image == "" then
			return
		end

		actions.close(prompt_bufnr)

		opts.namespace = parent.metadata.namespace

		local args = vim.iter({
			"set",
			"image",
			k_utils.parse_opts(opts, parent.kind:lower() .. "s"),
			parent.kind:lower() .. "/" .. parent.metadata.name,
			selection.value.name .. "=" .. image,
		})
			:flatten(math.huge)
			:totable()

		Job:new({
			enable_recording = true,
			command = "kubectl",
			args = vim.iter(args):flatten(math.huge):totable(),

			on_start = function()
				print("Setting image...")
			end,

			on_exit = function(_, code)
				if code == 0 then
					print("Image set successfully!")
				else
					utils.notify("kubectl", {
						msg = "Error setting image",
						level = "ERROR",
					})
				end
			end,
		}):start()
	end
end

function M.reload_resource(_, finder)
	return function(prompt_bufnr)
		local current_picker = action_state.get_current_picker(prompt_bufnr)
		current_picker:refresh(finder(), { reset_prompt = false })
	end
end

return M
