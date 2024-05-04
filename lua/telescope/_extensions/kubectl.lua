return require("telescope").register_extension {
  setup = function(ext_config, config)
    require('kubectl.store').setup()
  end,
  exports = require('kubectl').exports(),
}
