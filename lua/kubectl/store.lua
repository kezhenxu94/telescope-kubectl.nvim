local S = {}

S._store = {}

function S.setup()
  local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')
  local filepath = vim.fn.stdpath('data') .. '/telescope-kubectl/' .. cwd
  local datafile = io.open(filepath .. '/data.json', 'r')
  if datafile then
    S._store = vim.fn.json_decode(datafile:read('*all'))
    datafile:close()
  end
end

function S.get(key)
  return S._store[key]
end

function S.set(key, value)
  S._store[key] = value

  S.save()
end

function S.save()
  local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')
  local filepath = vim.fn.stdpath('data') .. '/telescope-kubectl/' .. cwd

  vim.fn.mkdir(filepath, 'p')

  local datafile = io.open(filepath .. '/data.json', 'w')
  if not datafile then
    print('Could not open file for writing:', filepath .. '/data.json')
    return
  end

  datafile:write(vim.fn.json_encode(S._store))
  datafile:close()
end

return S
