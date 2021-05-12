# Setup

* Install ansible locally
* Add community.general `ansible-galaxy collection install community.general`

# Mac Specific things
I always have a heck of a time getting ansible working right on MacOS.

I tend to just make a python venv in this project folder..

```
$ python3 -m venv venv 
$ source venv/bin/activate   
$ python -m pip install ansible
```
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
