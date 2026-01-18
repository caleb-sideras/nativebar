# Native SourceKit-LSP Setup

Uses Build Server Protocol (BSP) for proper Xcode integration.

## Setup

```bash
# Install xcode-build-server
brew install xcode-build-server

# Generate buildServer.json
./lsp.sh

# Configure editor to use buildServer workspace type
```

The build server queries Xcode for real compiler flags and file lists.

## Editor Configuration

### Neovim
```lua
require('lspconfig').sourcekit.setup({
  cmd = {'sourcekit-lsp', '--default-workspace-type', 'buildServer'},
  root_dir = require('lspconfig.util').root_pattern('buildServer.json', '.git'),
})
```

### VS Code
Install Swift extension - auto-detects buildServer.json

### Emacs
```elisp
(setq lsp-sourcekit-executable (string-trim (shell-command-to-string "xcrun --find sourcekit-lsp")))
```
