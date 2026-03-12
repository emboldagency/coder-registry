# Link Dotfiles module

A comprehensive Coder module that clones a dotfiles repository and applies them using GNU Stow or custom symlinking strategies.

**Note:** This module replaces the standard Coder dotfiles module. It handles the full lifecycle (Clone -> Clean -> Link) to prevent race conditions common when using separate clone and link steps.

## Inputs

- `agent_id` (string) - The ID of the Coder agent.
- `dotfiles_uri` (string) - The URL of the dotfiles repository.
- `user` (string, optional) - The user to apply dotfiles to. Defaults to the current user. If set to a different user, `sudo` will be used.
- `mode` (string, optional) - One of `symlink`, `copy`, or `none`.
  - If unset, the module will create a workspace parameter named `Dotfiles Mode` so end-users can choose behavior at runtime.
- `packages` (string, optional) - Space-separated list of package specifiers for `stow` or manual handling.
  - Each item may be `origin` (e.g. `dotfiles`) or `origin:target` (e.g. `home:dotfiles` or `dotfiles:/etc/skel`).
  - If omitted, the module will auto-detect `dotfiles/` and/or `home/` subdirs in the repo.
  - If omitted, the module also exposes a workspace parameter named `Dotfiles Packages`.
- `stow_preserve_changes` (bool, optional) - If `true` (default), changes created by stow are stashed to preserve local edits.
- `manual_update` (bool, optional) - If `true`, adds a "Refresh Dotfiles" button to the workspace page for on-demand updates. Default: `false`.

## Usage

Do **not** use the standard `coder/dotfiles` module. Use this module directly.

```terraform
module "link_dotfiles" {
  source       = "git::https://github.com/emboldagency/coder-registry.git//modules/dotfiles?ref=main"
  agent_id     = coder_agent.main.id
  dotfiles_uri = data.coder_parameter.dotfiles_uri.value

  # Optional overrides
  # user                  = "root"
  # packages              = "dotfiles home:dotfiles"
  # stow_preserve_changes = true
  # manual_update         = true  # Adds "Refresh Dotfiles" button to workspace
}
```

## Behavior & Notes

- **Lifecycle**:
  1. **Clean**: Checks the local repo for "dirty" states (modified files). If found, it stashes them to ensure `git pull` does not fail.
  2. **Clone/Update**: Clones the repo if missing, or pulls/rebases if it exists.
  3. **Link**: Applies the files using the selected `mode`.
- **User Context**: If the `user` input is provided (and differs from the current user), the script utilizes `sudo` to execute the entire clone and link process as that target user.
- **Stow Strategy**:
  - When `MODE=symlink` and GNU `stow` is available, it uses `stow` to create symlinks.
  - **Conflict Handling**: Before stow runs, the script removes any existing files/symlinks that would be managed by the new packages. This allows seamless upgrades from older setups where dotfiles were installed using different methods.
  - If `stow_preserve_changes` is true, any changes created during the process are stashed to preserve local edits.
- **Auto-Detection**: When `packages` is not provided, the module prefers `dotfiles/` or `home/` subdirectories inside the repo before falling back to the repo root.
- **Manual Update Button**: When `manual_update = true`, a "Refresh Dotfiles" button appears in the workspace UI. Clicking it re-runs the entire dotfiles process (git pull + stow). The command runs once and exits cleanly—the output window will close automatically when complete.
- **Security**: The dotfiles URI is validated to prevent command injection attacks. Only valid git repository URLs are accepted.

## Troubleshooting

### Stow Conflicts During Upgrade

**Issue**: Stow fails with messages like "existing target is not owned by stow" or "Absolute/relative mismatch"

**Cause**: This typically occurs when upgrading from an older Coder version where dotfiles were installed using a different method.

**Solution**:
1. Check the dotfiles log: `cat $HOME/.dotfiles.log`
2. Identify which files are conflicting (listed in the stow error)
3. Manually remove them:
   ```bash
   rm -f ~/.zshrc ~/.zshenv ~/.vimrc ~/.config/antidote/embold_plugins.zsh
   rm -f ~/.local/share/code-server/User/settings.json
   ```
4. Re-run the dotfiles link step:
   - Via Coder: Go to workspace creation and re-enable the dotfiles module
   - Or manually (if symlink mode): `cd ~/.config/coderv2/dotfiles && stow -t $HOME dotfiles`

The pre-stow cleanup should prevent this on fresh setups, but manual intervention may be needed if conflicts arise due to local edits.

## Publishing

Tag releases with Calendar Versioning (e.g. `v2026.02.23.0`) and reference them with `?ref=` in the `git::` source string.
