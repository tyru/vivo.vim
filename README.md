
# What's this?

Yet yet yet another vim plugin manager.
This plugin is designed for the following policies.

* Version locking is **MUST**.
  * Managed plugins are listed in `~/.vim/Vivacious.lock`.
  * For completely restoring your current environment at another PC,
    you can manage the file by version control systems(aka Git, Mercurial, ...).
    And just typing `:VivaFetchAll /path/to/Vivacious.lock` or `:call vivacious#fetch_all('/path/to/Vivacious.lock')`, everything is done like `bundle install`.
* Install plugin from command-line.
  * From GitHub: `:VivaInstall tyru/open-browser.vim`
  * From git URL(http,https,git): `:VivaInstall https://github.com/tyru/open-browser.vim`
* Uninstall plugin from command-line.
  * `:VivaUninstall open-browser.vim`
* I don't want to write plugins' names in .vimrc by hand!
  * Okay, vivacious manages all stuffs about plugins.
    You don't need to concern about them.
  * It shouldn't be there(.vimrc)!!!
* I don't want to write plugins' configurations in .vimrc, too!
  * It is **painful** to remove the configurations by hand if you uninstall a plugin...
  * By default, a configuration file per a plugin is `~/.vim/bundleconfig/<plugin name>.vim`.
  * It also shouldn't be there! isn't it?

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
  "   call system('mkdir -p ~/.vim/bundle/vivacious.vim')
  "   call system('git clone https://github.com/tyru/vivacious.vim.git ~/.vim/bundle/vivacious.vim')
  " end
endif
filetype plugin indent on

" Load plugins under '~/.vim/bundle/'.
call vivacious#bundle()
```

# Supported protocols

* Git

