local entry_display = require "telescope.pickers.entry_display"

local store = require("kubectl.store")
local k_utils = require "kubectl.utils"

local k_make_entry = {}

function k_make_entry.gen_for_contexts(opts)
  opts = opts or {}

  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 1 },
      { remaining = true },
    },
  }

  local make_display = function(entry)
    return displayer {
      store.get('context') == entry.value and "*" or " ",
      entry.value,
    }
  end

  return function(entry)
    return {
      display = make_display,
      value = entry,
      ordinal = entry,
    }
  end
end

function k_make_entry.gen_from_object(items)
  items = items or {}

  local max_ns_len = k_utils.max(items, function(item)
    return item.metadata.namespace and #item.metadata.namespace or 0
  end)
  local max_status_len = k_utils.max(items, function(item)
    local status = (k_utils.resource_status(item) or {}).status
    return status and #status or 0
  end)

  local c = {
    { width = 4 }
  }
  if max_status_len > 0 then
    table.insert(c, { width = max_status_len })
  end
  if max_ns_len > 0 then
    table.insert(c, { width = max_ns_len })
  end
  table.insert(c, { width = 64 })

  local displayer = entry_display.create {
    separator = " ",
    items = c,
  }

  local make_display = function(entry)
    local status = entry.status
    local time = k_utils.relative_time(entry.value.metadata.creationTimestamp)
    local ns = entry.value.metadata.namespace
    local e = {
      vim.tbl_flatten { time, status and status.hl },
    }
    if status then
      table.insert(e, vim.tbl_flatten { status.status, status.hl })
    end
    if ns then
      table.insert(e, vim.tbl_flatten { ns, status and status.hl })
    end
    table.insert(e, vim.tbl_flatten { entry.value.metadata.name, status and status.hl } or entry.value.metadata.name)
    return displayer(e)
  end

  return function(entry)
    local ns = entry.metadata.namespace
    local ordinal = ns and (ns .. " ") or ""
    ordinal = ordinal .. entry.metadata.name
    local id = entry.kind .. ": " .. entry.metadata.name
    id = ns and (id .. "." .. ns) or id

    local status = k_utils.resource_status(entry)

    return {
      display = make_display,
      value = entry,
      status = status,
      ordinal = ordinal,
      id = id,
    }
  end
end

function k_make_entry.gen_for_containers(opts)
  opts = opts or {}

  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 64 },
      { remaining = true },
    },
  }

  local make_display = function(entry)
    return displayer {
      entry.value.name,
      entry.value.image,
    }
  end

  return function(entry)
    return {
      display = make_display,
      value = entry,
      ordinal = entry.name .. " " .. entry.image,
    }
  end
end

function k_make_entry.gen_for_port_forward(opts)
  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 10 },
      { width = 64 },
      { remaining = true },
    },
  }

  local make_display = function(entry)
    return displayer {
      entry.value.resource.kind,
      entry.value.resource.metadata.name,
      entry.value.ports,
    }
  end

  return function(entry)
    return {
      display = make_display,
      value = entry,
      ordinal = entry.resource.kind .. "/" .. entry.resource.metadata.name .. " " .. entry.ports,
    }
  end
end

function k_make_entry.gen_for_api_resources(opts)
  local displayer = entry_display.create {
    separator = " ",
    items = {
      { remaining = true },
    },
  }

  local make_display = function(entry)
    return displayer {
      entry.value,
    }
  end

  return function(entry)
    local parts = vim.split(entry, " ")
    local kind = parts[1]

    return {
      display = make_display,
      value = entry,
      ordinal = entry,
      kind = kind,
    }
  end
end

return k_make_entry
