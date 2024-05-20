local store = require("kubectl.store")

local M = {}

function M.parse_opts(opts, target)
  if not opts.context and not opts.c and target ~= "contexts" and store.get('context') then
    opts.context = store.get('context')
  end

  local query = {}
  for k, v in pairs(opts) do
    if k == 'namespace' or k == 'n' then
      if not v then
        goto continue
      end
      if target == "contexts" then
        goto continue
      end
      if v == '' then
        table.insert(query, { "--all-namespaces=true" })
      else
        table.insert(query, { "-n", v })
      end
    end
    if #k == 1 then
      table.insert(query, { "-" .. k, v })
    elseif type(v) == "boolean" then
      table.insert(query, { "--" .. k .. "=" .. tostring(v) })
    else
      table.insert(query, { "--" .. k, v })
    end
    ::continue::
  end

  return query
end

function M.relative_time(time)
  if not time or time == vim.NIL or time == '' then
    return ""
  end
  local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z"
  local year, month, day, hour, min, sec = time:match(pattern)
  local offset = os.time() - os.time(os.date("!*t"))
  local t = os.time({ year = year, month = month, day = day, hour = hour, min = min, sec = sec }) + offset
  local diff = os.difftime(os.time(), t)
  if diff < 60 then
    return diff .. "s"
  elseif diff < 3600 then
    return math.floor(diff / 60) .. "m"
  elseif diff < 86400 then
    return math.floor(diff / 3600) .. "h"
  else
    return math.floor(diff / 86400) .. "d"
  end
end

function M.resource_status(resource)
  local status_hl_group = {
    Error = "Error",
    ImagePullBackOff = "Error",
    Completed = "TelescopePreviewHyphen",
  }
  if resource.kind == 'Pod' then
    local pod = resource
    local status = 'Running'

    for _, container in ipairs(pod.status.containerStatuses or {}) do
      for state, detail in pairs(container.state or {}) do
        if state == 'running' then
          goto continue
        end
        status = detail.reason or status
        ::continue::
      end
    end

    return {
      status = status,
      hl = status_hl_group[status],
    }
  end

  if resource.kind == 'Deployment' then
    local deployment = resource
    local readyReplicas = deployment.status.readyReplicas or 0
    local replicas = deployment.status.replicas or 0
    local status = string.format("%d/%d", readyReplicas, replicas)
    return {
      status = status,
      hl = readyReplicas ~= replicas and "Error",
    }
  end

  if resource.kind == 'Node' then
    local node = resource
    local statuses = {}

    for _, condition in ipairs(node.status.conditions) do
      if condition.status == 'True' then
        table.insert(statuses, condition.type)
      end
    end
    if node.spec.unschedulable then
      table.insert(statuses, 'Unschedulable')
    end

    local status = table.concat(statuses, ',')
    return {
      status = status,
      hl = status ~= 'Ready' and 'Error',
    }
  end

  return nil
end

function M.max(items, func)
  local max = 0
  for _, item in ipairs(items) do
    local value = func(item)
    if value > max then
      max = value
    end
  end
  return max
end

return M
