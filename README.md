# Setup

* Install ansible locally
* Add community.general `ansible-galaxy collection install community.general`

# Playbooks

### `editorconfig.yml`

Sets up my text editors.

#### Post Run Steps:
* Set a default node via nvm, I use LTS versions
* Boot up nvim, it will probably complain about an invalid config.
* Run `:PluginInstall`
* Run `source %`
* nvim "should" be happy now. Enjoy having a kickass text editor


#### Resources

* https://marioyepes.com/vim-setup-for-modern-web-development/
