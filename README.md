[![Build Status](https://travis-ci.org/tyru/vivacious.vim.svg?branch=master)](https://travis-ci.org/tyru/vivacious.vim)

# What's this?

Yet yet yet another vim plugin manager.
This plugin is designed for the following policies.

1. Version locking is **MUST**.
  * Managed plugins are listed in `~/.vim/Vivacious.lock`.
  * For completely restoring your current environment at another PC,
    you can manage the file by version control systems(aka Git, Mercurial, ...).
    And just typing `:VivaciousFetchAll /path/to/Vivacious.lock` or `:call vivacious#fetch_all('/path/to/Vivacious.lock')`, everything is done like `bundle install`.
2. Of cource, Multi-platform is also **MUST**.
  * It works with: Windows, Linux
  * Maybe it works, but please tell me if it works: Mac OS X
3. Install/Uninstall a plugin from command-line. Here are the examples.
  (See `Features` for details)
  * `:VivaciousInstall tyru/open-browser.vim`
  * `:VivaciousInstall https://github.com/tyru/open-browser.vim`
  * `:VivaciousPurge open-browser.vim`
  * `:VivaciousRemove open-browser.vim`
4. I don't want to write plugins' names in .vimrc by hand!
  * Okay, leave all stuffs about plugin management to vivacious.
    You don't need to concern about them.
  * It shouldn't be there(.vimrc)!!!
5. I don't want to write plugins' configurations in .vimrc, too!
  * It is **painful** to remove the configurations by hand after you uninstall a plugin...
  * By default, a configuration file per a plugin is `~/.vim/bundleconfig/<plugin name>.vim`.
  * It also shouldn't be there! isn't it?
6. Thin wrapper plugin for external command (TODO)
  * If a vim plugin gets bigger, the code should be split into external command.
  * Because calling external command doesn't have severe impact on your vim memory usage.
  * It also keeps your vim rapid because it can avoid the problems like memory leak, memory thrashing.
  * Of cource, if the code is real-time processing, it should not be split.
7. Stable, and Well-tested (TODO)
  * Plugin manager should be tested deeply and stable.
8. Keep It Simple, Stupid
  * Vivacious doesn't slow down your vim startup, and not support any features not in this policies.


# How it works

```
:VivaciousList
No plugins are installed.

:VivaciousInstall tyru/caw.vim
vivacious: Fetching a plugin from 'https://github.com/tyru/caw.vim'... Done.
vivacious: Installed a plugin 'caw.vim'.

:VivaciousInstall tyru/open-browser.vim
vivacious: Fetching a plugin from 'https://github.com/tyru/open-browser.vim'... Done.
vivacious: Installed a plugin 'open-browser.vim'.

:VivaciousList
caw.vim
  Directory: /home/tyru/.vim/bundle/caw.vim
  Type: git
  URL: https://github.com/tyru/caw.vim
  Version: 6591ed28caef2d3175298818c5f38ce9ec692416
open-browser.vim
  Directory: /home/tyru/.vim/bundle/open-browser.vim
  Type: git
  URL: https://github.com/tyru/open-browser.vim
  Version: 61169d9c614cfead929be33b279e4e644d2c7c55

Listed managed plugins.

:VivaciousRemove open-browser.vim
vivacious: Uninstalling the plugin 'open-browser.vim'... Done.

:VivaciousList
caw.vim
  Directory: /home/tyru/.vim/bundle/caw.vim
  Type: git
  URL: https://github.com/tyru/caw.vim
  Version: 6591ed28caef2d3175298818c5f38ce9ec692416
open-browser.vim (not fetched)
  Directory: /home/tyru/.vim/bundle/open-browser.vim
  Type: git
  URL: https://github.com/tyru/open-browser.vim
  Version: 61169d9c614cfead929be33b279e4e644d2c7c55

Listed managed plugins.

:VivaciousPurge caw.vim
vivacious: Unrecording the plugin info of 'caw.vim'... Done.
vivacious: Uninstalling the plugin 'caw.vim'... Done.

:VivaciousList
open-browser.vim (not fetched)                                                                                                                      
  Directory: /home/tyru/.vim/bundle/open-browser.vim
  Type: git
  URL: https://github.com/tyru/open-browser.vim
  Version: 61169d9c614cfead929be33b279e4e644d2c7c55

Listed managed plugins.

:VivaciousFetchAll
vivacious: Fetching a plugin from 'https://github.com/tyru/open-browser.vim'... Done.
vivacious: Installed a plugin 'open-browser.vim'.
vivacious: VivaciousFetchAll: All plugins are installed!

:VivaciousList
open-browser.vim
  Directory: /home/tyru/.vim/bundle/open-browser.vim
  Type: git
  URL: https://github.com/tyru/open-browser.vim
  Version: 61169d9c614cfead929be33b279e4e644d2c7c55

Listed managed plugins.
```

# Features

## `:VivaciousInstall`

* From GitHub repository: `:VivaciousInstall tyru/open-browser.vim`
* From Git repository URL(http,https,git): `:VivaciousInstall https://github.com/tyru/open-browser.vim`

## `:VivaciousPurge`

* `:VivaciousPurge open-browser.vim` removes both a plugin directory and a plugin info.

## `:VivaciousRemove`

* `:VivaciousRemove open-browser.vim` removes only a plugin directory.
* After this command is executed, `:VivaciousFetchAll` can fetch a plugin directory again.

## `:VivaciousList`

* Lists managed plugins including which have been not fetched (See `How it works`).

## `:VivaciousFetchAll`

* Install all plugins recorded in `~/.vim/Vivacious.lock`.
* Also locks the versions to recorded commit.
  (for example, in git repository, it executes `git checkout {hash}`)


# Installation

You must install this plugin by hand at first :)

## You have 'git' command

1. `git clone https://github.com/tyru/vivacious.vim ~/.vim/bundle/vivacious.vim`
2. Add `~/.vim/bundle/vivacious.vim` to runtimepath (See `Configuration`).

## You don't have 'git' command

1. Download ZIP archive from `https://github.com/tyru/vivacious.vim/archive/master.zip`.
2. Create `~/.vim/bundle/vivacious.vim/` directory.
3. Extract archive into `~/.vim/bundle/vivacious.vim/`.

Here is the directory structure after step 3.

```
$ tree ~/.vim/bundle/vivacious.vim/
/home/tyru/.vim/bundle/vivacious.vim/
├── README.md
├── autoload
│   └── vivacious.vim
├── doc
└── plugin
    └── vivacious.vim
```


# Configuration

```viml
if has('vim_starting')
  set rtp+=~/.vim/bundle/vivacious.vim
  " If you want to fetch vivacious.vim automatically...
  " if !isdirectory(expand('~/.vim/bundle/vivacious.vim'))
  "   call system('mkdir -p ~/.vim/bundle/')
  "   call system('git clone https://github.com/tyru/vivacious.vim.git ~/.vim/bundle/vivacious.vim')
  " end
endif

" Fetch managed plugins from remote.
call vivacious#fetch_all()

" Add managed plugins to 'runtimepath'.
" (It won't load disabled plugins)
call vivacious#load_plugins()
filetype plugin indent on

" Load all bundle configs in '~/.vim/bundleconfig/*.vim' (if you prefer).
" This function loads plugin list from 'runtimepath'.
call vivacious#bundleconfig#load()

" Generate helptags for plugins in 'runtimepath'.
call vivacious#helptags()
```


# Supported protocols

* Git

