# telescope-kubectl.nvim

An wrapper around `kubectl` for [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim).
Allowing you to interact with your kubernetes cluster from within neovim, using the power of telescope.

# Features

- [x] List Kubernetes resources, Pods, Deployments, Services, etc.
- [x] Load the YAML of a resource into a buffer, and edit it.
- [x] Delete or update resources, including scale deployments, set images, etc.
- [x] Load logs of Pod containers into a buffer, with live updates.
- [x] Port-forward to a Pod, and delete the port-forwards on exit neovim.
- [x] Exec into a Pod container.

# Requirements

- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

# Installation

Here are my own sample installation instructions, you can use your own plugin manager and adjust the configurations as needed.

```lua
return {
  {
    'nvim-telescope/telescope.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'kezhenxu94/telescope-kubectl.nvim',
    },
    config = function()
      require('telescope').setup {
        -- Your telescope configuration
      }
      require("telescope").load_extension("kubectl")

      require('which-key').register({
        ['<leader>'] = {
          k = {
            name = "+kubectl",
            c = {
              name = "+contexts, configmaps, cronjobs, etc",
              t = { require('telescope').extensions.kubectl.contexts, 'Kubernetes Contexts' },
              m = { require('telescope').extensions.kubectl.configmaps, 'Kubernetes Configmaps' },
              j = { require('telescope').extensions.kubectl.cronjobs, 'Kubernetes CronJobs' },
            },
            d = { require('telescope').extensions.kubectl.deployments, 'Kubernetes Deployments' },
            j = { require('telescope').extensions.kubectl.jobs, 'Kubernetes Jobs' },
            k = { require('telescope').extensions.kubectl.api_resources, 'Kubernetes Resources' },
            n = {
              name = "+namespaces, nodes, etc",
              s = { require('telescope').extensions.kubectl.namespaces, 'Kubernetes Namespaces' },
              o = { require('telescope').extensions.kubectl.nodes, 'Kubernetes Nodes' },
            },
            s = {
              name = "+secrets, services, statefulsets, etc",
              ec = { require('telescope').extensions.kubectl.secrets, 'Kubernetes Secrets' },
              vc = { require('telescope').extensions.kubectl.services, 'Kubernetes Services' },
              ts = { require('telescope').extensions.kubectl.statefulsets, 'Kubernetes StatefulSets' },
            },
            p = {
              name = "+pods, port-forwards",
              o = { require('telescope').extensions.kubectl.pods, 'Kubernetes Pods' },
              f = { require('telescope').extensions.kubectl.port_forwards, 'Kubernetes Port Forwards' },
            },
          },
        },
      })
    end
  },
}
```
