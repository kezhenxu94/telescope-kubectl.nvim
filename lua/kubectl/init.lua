local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local utils = require "telescope.utils"
local log = require "telescope.log"
local action_state = require "telescope.actions.state"

local k_make_entry = require "kubectl.kubectl_make_entry"
local k_previewers = require "kubectl.kubectl_previewers"
local k_actions = require "kubectl.kubectl_actions"
local k_utils = require "kubectl.utils"

_G.port_forwards = {}

vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
  callback = function()
    for _, pf in ipairs(_G.port_forwards) do
      local job = pf.job
      if job and job.pid then
        vim.loop.kill(job.pid, vim.loop.constants.SIGTERM)
      end
    end
  end,
})

local get_resource = function(opts, resource, resource_opts)
  opts = opts or {}
  opts.namespace = opts.namespace or ''
  opts.output = opts.output or 'jsonpath={range .items[*]}{@}{"\\n"}{end}'

  local opts_query = k_utils.parse_opts(opts, resource)
  local cmd = vim.tbl_flatten { "kubectl", "get", resource, opts_query }

  log.debug('Running command: ', vim.inspect(cmd))

  print("Loading " .. resource .. "...")

  local finder = function() 
    return finders.new_oneshot_job(cmd, {
    entry_maker = (k_make_entry['gen_from_' .. resource] or k_make_entry.gen_from_object)(resource),
  })
  end

  pickers.new(opts, {
    prompt_title = resource,
    results_title = require('kubectl.store').get('context'),
    finder = finder(),
    previewer = k_previewers.resource_previewer.new(opts),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(_, map)
      resource_opts = resource_opts or {}

      map("n", "<C-r>", k_actions.reload_resource(opts, finder), {
        desc = "Refresh",
      })

      if resource_opts.next then
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          if not selection then
            return
          end
          resource_opts.next(selection, opts)
        end)
      end

      if resource_opts.attach_mappings then
        return resource_opts.attach_mappings(opts, map)
      end
      return true
    end,
  }):find()
  --   end),
  --   10
  -- )
end

local map_set_image = function(opts, map)
  map("n", "m", function(prompt_bufnr)
    local selection = action_state.get_selected_entry()
    if not selection then
      return
    end
    actions.close(prompt_bufnr)

    local containers = {}
    local spec
    if selection.value.kind == 'Pod' then
      spec = selection.value.spec
    else
      spec = selection.value.spec.template.spec
    end

    if spec.containers then
      for _, container in ipairs(spec.containers) do
        table.insert(containers, container)
      end
    end
    if spec.initContainers then
      for _, container in ipairs(spec.initContainers) do
        table.insert(containers, container)
      end
    end

    pickers.new(opts, {
      prompt_title = 'Containers',
      results_title = require('kubectl.store').get('context'),
      finder = finders.new_table {
        results = containers or {},
        entry_maker = k_make_entry.gen_for_containers(opts),
      },
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(_, mapp)
        actions.select_default:replace(k_actions.set_image(opts, selection.value))

        mapp("n", "m", k_actions.set_image(opts, selection.value), {
          desc = "Set Image",
        })

        return true
      end,
    }):find()
  end, {
    desc = "Set Image",
  })
end

local map_resource_common_operations = function(opts, map, target)
  map({ "i", "n" }, "<C-e>", k_actions.edit_resource(opts), {
    desc = "Edit " .. target,
  })
  map({ "i", "n" }, "<C-d>", k_actions.delete_resource(opts), {
    desc = "Delete " .. target,
  })
  map("n", "D", k_actions.describe_resource(opts), {
    desc = "Describe " .. target,
  })
end

local B = {}

B.resources = {
  bindings = {},
  componentstatuses = {},
  configmaps = {
    attach_mappings = function(opts, map)
      map_resource_common_operations(opts, map, "ConfigMap")

      return true
    end
  },
  endpoints = {},
  events = {},
  limitranges = {},
  namespaces = {
    next = function(selection, opts)
      B.get_services({
        namespace = selection.value.metadata.name,
      })
    end,
    attach_mappings = function(opts, map)
      map_resource_common_operations(opts, map, "Namespace")

      return true
    end
  },
  nodes = {
    next = function(selection, opts)
      local fieldSelector = {
        "spec.nodeName=" .. selection.value.metadata.name,
      }

      opts = opts or {}
      opts.output = 'jsonpath={range .items[*]}{@}{"\\n"}{end}'
      opts.namespace = selection.value.metadata.namespace
      opts['field-selector'] = table.concat(fieldSelector, ",")

      B.get_pods(opts)
    end,
    attach_mappings = function(opts, map)
      map_resource_common_operations(opts, map, "Node")

      return true
    end
  },
  persistentvolumeclaims = {},
  persistentvolumes = {},
  podtemplates = {},
  replicationcontrollers = {},
  resourcequotas = {},
  secrets = {
    attach_mappings = function(opts, map)
      map_resource_common_operations(opts, map, "Secret")

      return true
    end
  },
  serviceaccounts = {},
  services = {
    next = function(selection, opts)
      local selector = {}
      for k, v in pairs(selection.value.spec.selector) do
        table.insert(selector, k .. "=" .. v)
      end

      opts = opts or {}
      opts.output = 'jsonpath={range .items[*]}{@}{"\\n"}{end}'
      opts.namespace = selection.value.metadata.namespace
      if selector and #selector > 0 then
        opts.selector = table.concat(selector, ",")
      end

      B.get_pods(opts)
    end,
    attach_mappings = function(opts, map)
      map_resource_common_operations(opts, map, "Service")

      return true
    end
  },
  challenges = {},
  orders = {},
  mutatingwebhookconfigurations = {},
  validatingwebhookconfigurations = {},
  customresourcedefinitions = {},
  apiservices = {},
  controllerrevisions = {},
  daemonsets = {},
  deployments = {
    next = function(selection, opts)
      local selector = {}
      for k, v in pairs(selection.value.spec.selector.matchLabels) do
        table.insert(selector, k .. "=" .. v)
      end

      opts = opts or {}
      opts.output = 'jsonpath={range .items[*]}{@}{"\\n"}{end}'
      opts.namespace = selection.value.metadata.namespace
      if selector and #selector > 0 then
        opts.selector = table.concat(selector, ",")
      end

      B.get_pods(opts)
    end,
    attach_mappings = function(opts, map)
      map({ "i", "n" }, "<C-s>", k_actions.scale_resource(opts), {
        desc = "Scale Deployment",
      })

      map_resource_common_operations(opts, map, "Deployment")

      map_set_image(opts, map)

      return true
    end
  },
  replicasets = {},
  statefulsets = {
    next = function(selection, opts)
      local selector = {}
      for k, v in pairs(selection.value.spec.selector.matchLabels) do
        table.insert(selector, k .. "=" .. v)
      end

      opts = opts or {}
      opts.output = 'jsonpath={range .items[*]}{@}{"\\n"}{end}'
      opts.namespace = selection.value.metadata.namespace
      if selector and #selector > 0 then
        opts.selector = table.concat(selector, ",")
      end

      B.get_pods(opts)
    end,
    attach_mappings = function(opts, map)
      map({ "i", "n" }, "<C-s>", k_actions.scale_resource(opts), {
        desc = "Scale StatefulSet",
      })

      map_resource_common_operations(opts, map, "StatefulSet")

      map_set_image(opts, map)

      return true
    end
  },
  tokenreviews = {},
  localsubjectaccessreviews = {},
  selfsubjectaccessreviews = {},
  selfsubjectrulesreviews = {},
  subjectaccessreviews = {},
  horizontalpodautoscalers = {},
  cronjobs = {
    next = function(selection, opts)
      opts = opts or {}
      opts.namespace = selection.value.metadata.namespace
      opts.output = string.format('jsonpath={range .items[?(.metadata.ownerReferences[0].uid==%q)]}{@}{"\\n"}{end}',
        selection.value.metadata.uid)

      B.get_jobs(opts)
    end,
    attach_mappings = function(opts, map)
      map_resource_common_operations(opts, map, "CronJob")

      return true
    end
  },
  jobs = {
    next = function(selection, opts)
      local selector = {}
      for k, v in pairs(selection.value.spec.selector.matchLabels) do
        table.insert(selector, k .. "=" .. v)
      end

      opts = opts or {}
      opts.output = 'jsonpath={range .items[*]}{@}{"\\n"}{end}'
      opts.namespace = selection.value.metadata.namespace
      if selector and #selector > 0 then
        opts.selector = table.concat(selector, ",")
      end

      B.get_pods(opts)
    end,
    attach_mappings = function(opts, map)
      map_resource_common_operations(opts, map, "Job")

      return true
    end
  },
  certificaterequests = {},
  certificates = {},
  clusterissuers = {},
  issuers = {},
  certificatesigningrequests = {},
  leases = {},
  endpointslices = {},
  wasmplugins = {},
  flowschemas = {},
  prioritylevelconfigurations = {},
  istiooperators = {},
  pods = {
    next = function(selection, opts)
      B.get_containers(selection.value, opts)
    end,
    attach_mappings = function(opts, map)
      map({ "i", "n" }, "<C-f>", k_actions.port_forward(opts), {
        desc = "Port Forward",
      })

      map_resource_common_operations(opts, map, "Pod")

      map_set_image(opts, map)

      return true
    end
  },
  alertmanagerconfigs = {},
  alertmanagers = {},
  podmonitors = {},
  probes = {},
  prometheusagents = {},
  prometheuses = {},
  prometheusrules = {},
  scrapeconfigs = {},
  servicemonitors = {},
  thanosrulers = {},
  destinationrules = {},
  envoyfilters = {},
  gateways = {},
  proxyconfigs = {},
  serviceentries = {},
  sidecars = {},
  virtualservices = {},
  workloadentries = {},
  workloadgroups = {},
  ingressclasses = {},
  ingresses = {},
  networkpolicies = {},
  runtimeclasses = {},
  poddisruptionbudgets = {},
  podsecuritypolicies = {},
  clusterrolebindings = {},
  clusterroles = {},
  rolebindings = {},
  roles = {},
  priorityclasses = {},
  authorizationpolicies = {},
  peerauthentications = {},
  requestauthentications = {},
  csidrivers = {},
  csinodes = {},
  csistoragecapacities = {},
  storageclasses = {},
  volumeattachments = {},
  telemetries = {},
  ipamds = {},
}

B.get_contexts = function(opts)
  local cmd = vim.tbl_flatten { "kubectl", "config", "get-contexts", "-o", "name", }

  print("Loading contexts...")

  vim.defer_fn(
    vim.schedule_wrap(function()
      local results = utils.get_os_command_output(cmd)

      pickers.new(opts, {
        prompt_title = "Contexts",
        finder = finders.new_table {
          results = results,
          entry_maker = k_make_entry.gen_for_contexts(opts),
        },
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(_, _)
          actions.select_default:replace(k_actions.select_context(opts))
          return true
        end,
      }):find()
    end),
    10
  )
end

B.get_api_resources = function(opts)
  local cmd = vim.tbl_flatten { "kubectl", "api-resources", "--no-headers=true" }

  print("Loading API resources...")

  vim.defer_fn(
    vim.schedule_wrap(function()
      local results = utils.get_os_command_output(cmd)

      pickers.new(opts, {
        prompt_title = "Resources",
        results_title = require('kubectl.store').get('context'),
        finder = finders.new_table {
          results = results,
          entry_maker = k_make_entry.gen_for_api_resources(opts),
        },
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(_, _)
          actions.select_default:replace(function()
            local selection = action_state.get_selected_entry()
            if not selection then
              return
            end

            get_resource(opts, selection.kind, B.resources[selection.kind:lower()] or {})
          end)
          return true
        end,
      }):find()
    end),
    10
  )
end

for resource, value in pairs(B.resources) do
  B["get_" .. string.lower(resource)] = function(opts)
    get_resource(opts, resource, value)
  end
end

B.get_containers = function(pod, opts)
  local containers = {}
  if pod.spec.containers then
    for _, container in ipairs(pod.spec.containers) do
      table.insert(containers, container)
    end
  end
  if pod.spec.initContainers then
    for _, container in ipairs(pod.spec.initContainers) do
      table.insert(containers, container)
    end
  end

  pickers.new(opts, {
    prompt_title = 'Containers',
    results_title = require('kubectl.store').get('context'),
    finder = finders.new_table {
      results = containers or {},
      entry_maker = k_make_entry.gen_for_containers(opts),
    },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(_, map)
      actions.select_default:replace(k_actions.pod_log(pod, opts))

      map({ "i", "n" }, "<C-s>", k_actions.pod_container_shell(opts, pod), {
        desc = "Open a shell in the container",
      })

      map("n", "m", k_actions.set_image(opts, pod), {
        desc = "Set Image",
      })

      return true
    end,
  }):find()
end

B.get_port_forwards = function(opts)
  pickers.new(opts, {
    prompt_title = 'Port Forwards',
    results_title = require('kubectl.store').get('context'),
    finder = finders.new_table {
      results = _G.port_forwards,
      entry_maker = k_make_entry.gen_for_port_forward(opts),
    },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      map({ "i", "n" }, "<C-d>", function()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end

        local confirm = vim.fn.input("Delete port forward? (y/n): ")
        if confirm ~= "y" then
          return
        end

        print("Deleting port forward: ", selection.value.resource.metadata.name)

        local pf = table.remove(_G.port_forwards, selection.index)
        vim.loop.kill(pf.job.pid, vim.loop.constants.SIGTERM)

        actions.close(prompt_bufnr)
      end, {
        desc = "Delete Port Forward",
      })

      return true
    end,
  }):find()
end

B.exports = function()
  local exports = {}

  for resource, _ in pairs(B.resources) do
    exports[resource] = B["get_" .. string.lower(resource)]
  end

  exports.contexts = B.get_contexts
  exports.api_resources = B.get_api_resources
  exports.port_forwards = B.get_port_forwards

  return exports
end

return B
