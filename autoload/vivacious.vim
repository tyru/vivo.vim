scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

let s:LOCKFILE_VERSION = 1

function! vivacious#bundle(...)
    let vimbundle_dir = (a:0 ? a:1 : s:vimbundle_dir())
    if !isdirectory(vimbundle_dir)
        " No plugins are installed... silently ignore.
        return
    endif
    for plug_dir in s:glob(s:path_join(vimbundle_dir, '*'))
        if isdirectory(plug_dir)
            let &rtp = join([&rtp, plug_dir], ',')
        endif
    endfor
endfunction

function! vivacious#install(...)
    call s:call_with_error_handlers('s:install', a:000, 's:cmd_install_help')
endfunction

function! vivacious#remove(...) abort
    call s:call_with_error_handlers('s:remove', a:000, 's:cmd_remove_help')
endfunction

function! vivacious#__complete_remove__(arglead, cmdline, cursorpos) abort
    if a:cmdline !~# '^[A-Z]\w*\s\+.\+$' || a:arglead ==# ''
        return map(s:get_records_from_file(s:get_lockfile()), 'v:val.name')
    endif
    return s:expand_plug_name(a:arglead, s:get_lockfile())
endfunction

function! vivacious#purge(...) abort
    call s:call_with_error_handlers('s:purge', a:000, 's:cmd_purge_help')
endfunction

function! vivacious#list(...) abort
    call s:call_with_error_handlers('s:list', a:000, 's:cmd_list_help')
endfunction

function! vivacious#fetch_all(...) abort
    call s:call_with_error_handlers('s:fetch_all', a:000,
    \                               's:cmd_fetch_all_help')
endfunction



let s:is_windows = has('win16') || has('win32') || has('win64') || has('win95')
let s:is_unix = has('unix')
let s:NONE = []
let s:GIT_URL_RE  = '^\%(https\?\|git\)://'
let s:HTTP_URL_RE = '^https\?://'

function! s:call_with_error_handlers(mainfunc, args, helpfunc) abort
    try
        call {a:mainfunc}(a:args)
    catch /^vivacious:\s*fatal:/
        let e = substitute(v:exception, '^vivacious:\s*fatal:\s*', '', '')
        call s:error('Fatal error. '
        \          . 'Please report this to '
        \          . 'https://github.com/tyru/vivacious.vim/issues/new !')
        call s:error('Error: ' . e . ' at ' . v:throwpoint)
        call {a:helpfunc}()
    catch /^vivacious:/
        let e = substitute(v:exception, '^vivacious:\s*', '', '')
        call s:error(e)
        call {a:helpfunc}()
    catch
        call s:error('Internal error. '
        \          . 'Please report this to '
        \          . 'https://github.com/tyru/vivacious.vim/issues/new !')
        call s:error('Error: ' . v:exception . ' at ' . v:throwpoint)
        call {a:helpfunc}()
    endtry
endfunction

function! s:install(args) abort
    if len(a:args) ==# 0 || a:args[0] =~# '^\%(-h\|--help\)$'
        return s:cmd_install_help()
    endif
    if len(a:args) !=# 1
        throw 'vivacious: VivaInstall: too few or too many arguments.'
    endif
    if a:args[0] =~# '^[^/]\+/[^/]\+$'
        " 'tyru/vivacious.vim'
        call s:install_github_plugin(a:args[0])
    elseif a:args[0] =~# s:GIT_URL_RE
        " 'https://github.com/tyru/vivacious.vim'
        call s:install_git_plugin(a:args[0], 1, s:vimbundle_dir())
        let plug_dir = s:path_join(s:vimbundle_dir(),
        \                          s:path_basename(a:args[0]))
        call s:update_record(a:args[0], s:vimbundle_dir(), plug_dir, 1)
    else
        throw 'vivacious: VivaInstall: invalid arguments.'
    endif
endfunction

" @param arg 'tyru/vivacious.vim'
function! s:install_github_plugin(arg) abort
    let url = 'https://github.com/' . a:arg
    call s:install_git_plugin(url, 1, s:vimbundle_dir())
    let plug_dir = s:path_join(s:vimbundle_dir(),
    \                          s:path_basename(a:arg))
    call s:update_record(url, s:vimbundle_dir(), plug_dir, 1)
endfunction

function! s:install_git_plugin(url, redraw, vimbundle_dir) abort
    let plug_name = matchstr(a:url, '[^/]\+\%(\.git\)\?$')
    if plug_name ==# ''
        throw 'vivacious: Invalid URL(' . a:url . ')'
    endif
    if !isdirectory(a:vimbundle_dir)
        call s:mkdir_p(a:vimbundle_dir)
    endif
    let plug_dir = s:path_join(a:vimbundle_dir, plug_name)
    if isdirectory(plug_dir)
        throw "vivacious: You already installed '" . plug_name . "'. "
        \   . "Please uninstall it by "
        \   . ":VivaRemove or :VivaPurge."
    endif
    " Fetch & Install
    call s:info(printf("Fetching a plugin from '%s'...", a:url))
    call s:git('clone', a:url, plug_dir)
    if v:shell_error
        throw printf("vivacious: 'git clone %s %s' failed.", a:url, plug_dir)
    endif
    call s:info_msg(printf("Fetching a plugin from '%s'... Done.", a:url))
    call s:source_plugin(plug_dir)
    if a:redraw
        redraw    " before the last message
    endif
    call s:info_msg(printf("Installed a plugin '%s'.", plug_name))
endfunction

function! s:update_record(url, vimbundle_dir, plug_dir, update, ...) abort
    " Record or Lock
    let plug_name = s:path_basename(a:plug_dir)
    let vim_lockfile = s:get_lockfile()
    let old_record = s:get_record_by_name(plug_name, vim_lockfile)
    if empty(old_record)
        " If the record is not found, record the plugin info.
        let dir = s:path_join(s:path_basename(a:vimbundle_dir), plug_name)
        let ver = (a:0 ? a:1 :
        \           s:git({'work_tree': a:plug_dir,
        \                  'args': ['rev-parse', 'HEAD']}))
        let record = s:make_record(plug_name, dir, a:url, 'git', ver)
        call s:do_record(record, vim_lockfile)
        call s:info_msg(printf("Recorded the plugin info of '%s'.", plug_name))
    elseif a:update
        " Update version.
        call s:do_unrecord_by_name(plug_name, vim_lockfile)
        let dir = s:path_join(s:path_basename(a:vimbundle_dir), plug_name)
        let ver = s:git({'work_tree': a:plug_dir,
        \                'args': ['rev-parse', 'HEAD']})
        let record = s:make_record(plug_name, dir, a:url, 'git', ver)
        call s:do_record(record, vim_lockfile)
        call s:info_msg(printf("Updated the version of '%s' (%s -> %s).",
        \               plug_name, old_record.version, record.version))
    endif
    if !a:update
        " Lock the version.
        call s:lock_version(a:plug_dir,
        \                   (!empty(old_record) ? old_record : record),
        \                   plug_name)
    endif
endfunction

function! s:lock_version(plug_dir, record, plug_name) abort
    call s:git({'work_tree': a:plug_dir,
    \           'args': ['checkout', a:record.version]})
    if v:shell_error
        throw printf("vivacious: 'git checkout %s' failed.",
        \                               a:record.version)
    endif
    call s:info_msg(printf("Locked the version of '%s' (%s).",
    \                   a:plug_name, a:record.version))
endfunction

function! s:cmd_install_help() abort
    echo ' '
    echo 'Usage: VivaInstall <source>'
    echo '       VivaInstall tyru/vivacious.vim'
    echo '       VivaInstall https://github.com/tyru/vivacious.vim'
endfunction

function! s:remove(args) abort
    if len(a:args) ==# 0 || a:args[0] =~# '^\%(-h\|--help\)$'
        return s:cmd_remove_help()
    endif
    if len(a:args) !=# 1 || a:args[0] !~# '^[^/\\]\+$'
        throw 'vivacious: VivaRemove: invalid argument.'
    endif
    call s:uninstall_plugin_wildcard(a:args[0], 1, s:get_lockfile())
endfunction

function! s:purge(args) abort
    if len(a:args) ==# 0 || a:args[0] =~# '^\%(-h\|--help\)$'
        return s:cmd_purge_help()
    endif
    if len(a:args) !=# 1 || a:args[0] !~# '^[^/\\]\+$'
        throw 'vivacious: VivaPurge: invalid argument.'
    endif
    call s:uninstall_plugin_wildcard(a:args[0], 0, s:get_lockfile())
endfunction

function! s:uninstall_plugin_wildcard(wildcard, keep_record, lockfile) abort
    let plug_name_list = s:expand_plug_name(a:wildcard, a:lockfile)
    let redraw = (len(plug_name_list) >=# 2 ? 0 : 1)
    if len(plug_name_list) >=# 2
        echo join(map(copy(plug_name_list), '"* " . v:val'), "\n")
        if input('Do you want to install them?[y/N]: ') !~# '^[yY]'
            return
        endif
        echon "\n"
    endif
    for plug_name in plug_name_list
        call s:uninstall_plugin(plug_name, a:keep_record, redraw, a:lockfile)
    endfor
endfunction

function! s:expand_plug_name(wildcard, lockfile) abort
    if a:wildcard !~# '[*?]'
        return [a:wildcard]
    endif
    let records = s:get_records_from_file(a:lockfile)
    let candidates = map(records, 'v:val.name')
    " wildcard -> regexp
    let re = substitute(a:wildcard, '\*', '.*', 'g')
    let re = substitute(re, '?', '.', 'g')
    return filter(candidates, 'v:val =~# re')
endfunction

function! s:uninstall_plugin(plug_name, keep_record, redraw, lockfile) abort
    let vimbundle_dir = s:vimbundle_dir()
    let plug_dir = s:path_join(vimbundle_dir, a:plug_name)
    let exists_dir = isdirectory(plug_dir)
    let has_record = s:has_record_name_of(a:plug_name, a:lockfile)
    if !exists_dir && !has_record
        throw "vivacious: '" . a:plug_name . "' is not installed."
    endif
    " Remove the plugin info.
    if has_record && !a:keep_record
        let ver = s:git({'work_tree': plug_dir,
        \                'args': ['rev-parse', 'HEAD']})
        call s:do_unrecord_by_name(a:plug_name, a:lockfile)
        if !exists_dir && a:redraw
            redraw    " before the last message
        endif
        call s:info_msg(printf("Unrecorded the plugin info of '%s'.", a:plug_name))
    endif
    " Remove the plugin directory.
    if exists_dir
        call s:info(printf("Deleting the plugin directory '%s'...", a:plug_name))
        call s:delete_dir(plug_dir)
        if a:redraw
            redraw    " before the last message
        endif
        call s:info_msg(printf("Deleting the plugin directory '%s'... Done.", a:plug_name))
    endif
endfunction

function! s:cmd_remove_help() abort
    echo ' '
    echo 'Usage: VivaRemove <plugin name in bundle dir>'
    echo '       VivaRemove vivacious.vim'
    echo ' '
    echo ':VivaRemove removes only a plugin directory.'
    echo 'It keeps a plugin info.'
    echo 'After this command is executed, :VivaFetchAll can fetch a plugin directory again.'
endfunction

function! s:cmd_purge_help() abort
    echo ' '
    echo 'Usage: VivaPurge <plugin name in bundle dir>'
    echo '       VivaPurge vivacious.vim'
    echo ' '
    echo ':VivaPurge removes both a plugin directory and a plugin info.'
    echo ':VivaFetchAll doesn''t help, all data about specified plugin are gone.'
endfunction

function! s:list(args) abort
    let vimbundle_dir = s:vimbundle_dir()
    let records = s:get_records_from_file(s:get_lockfile())
    if empty(records)
        echomsg 'No plugins are installed.'
        return
    endif
    for record in records
        let plug_dir = s:path_join(vimbundle_dir, record.name)
        if isdirectory(plug_dir)
            echohl MoreMsg
            echomsg record.name
            echohl None
        else
            echohl WarningMsg
            echomsg record.name . " (not fetched)"
            echohl None
        endif
        echomsg "  Directory: " . s:abspath_record_dir(record.dir)
        echomsg "  Type: " . record.type
        echomsg "  URL: " . record.url
        echomsg "  Version: " . record.version
    endfor
    echomsg ' '
    echomsg 'Listed managed plugins.'
endfunction

function! s:cmd_list_help() abort
    echo ' '
    echo 'Usage: VivaList'
    echo ' '
    echo 'Lists managed plugins including plugins which have been not fetched.'
endfunction

function! s:fetch_all(args) abort
    if len(a:args) >= 1 && a:args[0] =~# '^\%(-h\|--help\)$'
        return s:cmd_fetch_all_help()
    endif
    let lockfile = (len(a:args) >= 1 ? expand(a:args[0]) : s:get_lockfile())
    if lockfile =~# s:HTTP_URL_RE
        let content = s:http_get(lockfile)
        let lockfile = tempname()
        call writefile(split(content, '\r\?\n', 1), lockfile)
    endif
    call s:fetch_all_from_lockfile(lockfile)
endfunction

function! s:fetch_all_from_lockfile(lockfile) abort
    if !filereadable(a:lockfile)
        throw "vivacious: Specified lockfile doesn't exist. "
        \   . '(' . a:lockfile . ')'
    endif
    let vimbundle_dir = s:vimbundle_dir()
    for record in s:get_records_from_file(a:lockfile)
        try
            let plug_dir = s:abspath_record_dir(record.dir)
            let vimbundle_dir = s:path_dirname(plug_dir)
            call s:install_git_plugin(record.url, 0, vimbundle_dir)
            call s:update_record(record.url, vimbundle_dir,
            \                    plug_dir, 0, record.version)
        catch /vivacious: You already installed/
            " silently skip
        endtry
    endfor
    call s:info_msg('VivaFetchAll: All plugins are installed!')
endfunction

function! s:cmd_fetch_all_help() abort
    echo ' '
    echo 'Usage: VivaFetchAll [<Vivacious.lock>]'
    echo '       VivaFetchAll /path/to/Vivacious.lock'
    echo ' '
    echo 'If no arguments are given, ~/.vim/Vivacious.lock is used.'
endfunction

function! s:http_get(url) abort
    if executable('curl')
        return system('curl -L -s -k ' . shellescape(a:url))
    elseif executable('wget')
        return system('wget -q -L -O - ' . shellescape(a:url))
    else
        throw 'vivacious: s:http_get(): '
        \   . 'you doesn''t have curl nor wget.'
    endif
endfunction

function! s:make_record(name, dir, url, type, version) abort
    return {'name': a:name, 'dir': a:dir, 'url': a:url,
    \       'type': a:type, 'version': a:version}
endfunction

function! s:do_record(record, lockfile) abort
    let lines = s:read_lockfile(a:lockfile)
    call s:write_lockfile(lines + [s:to_ltsv(a:record)], a:lockfile)
endfunction

" If lockfile doesn't exist, treat it as empty file.
function! s:do_unrecord_by_name(plug_name, lockfile) abort
    if !filereadable(a:lockfile)
        return
    endif
    " Get rid of the plugin info record which has a name of a:plug_name.
    let re = '\<name:' . a:plug_name . '\>'
    let lines = filter(s:read_lockfile(a:lockfile), 'v:val !~# re')
    call s:write_lockfile(lines, a:lockfile)
endfunction

" If lockfile doesn't exist, treat it as empty file.
function! s:read_lockfile(lockfile) abort
    if !filereadable(a:lockfile)
        return []
    endif
    return filter(readfile(a:lockfile)[1:], '!empty(v:val)')
endfunction

function! s:write_lockfile(lines, lockfile) abort
    return writefile(["version:" . s:LOCKFILE_VERSION] + a:lines, a:lockfile)
endfunction

function! s:get_record_by_name(name, lockfile) abort
    let records = filter(s:get_records_from_file(a:lockfile), 'v:val.name ==# a:name')
    return get(records, 0, {})
endfunction

function! s:has_record_name_of(name, lockfile) abort
    return !empty(s:get_record_by_name(a:name, a:lockfile))
endfunction

" If lockfile doesn't exist, treat it as empty file.
function! s:get_records_from_file(lockfile) abort
    if !filereadable(a:lockfile)
        return []
    endif
    let records = map(s:read_lockfile(a:lockfile), 's:parse_ltsv(v:val)')
    return filter(records, '!empty(v:val)')
endfunction

" http://ltsv.org/
function! s:to_ltsv(dict) abort
    return join(values(map(copy(a:dict), 'v:key . ":" . v:val')), "\t")
endfunction

function! s:parse_ltsv(line) abort
    let dict = {}
    let re = '^\([^:]\+\):\(.*\)'
    for keyval in split(a:line, '\t')
        if keyval ==# ''
            continue
        endif
        let m = matchlist(keyval, re)
        if empty(m)
            throw "vivacious: fatal: s:parse_ltsv(): Vivacious.lock file is corrupted."
        endif
        let dict[m[1]] = m[2]
    endfor
    " TODO: Validate keys/values?
    return dict
endfunction

function! s:delete_dir(dir) abort
    if !isdirectory(a:dir)
        throw 'vivacious: fatal: s:delete_dir(): '
        \   . 'given non-directory argument (' . a:dir . ').'
    endif
    call s:delete_dir_impl(a:dir, 'rf')
endfunction

" Delete a file/directory.
" from https://github.com/vim-jp/vital.vim
if s:is_unix
  function! s:delete_dir_impl(path, ...) abort
    let flags = a:0 ? a:1 : ''
    let cmd = flags =~# 'r' ? 'rm -r' : 'rmdir'
    let cmd .= flags =~# 'f' && cmd ==# 'rm -r' ? ' -f' : ''
    let ret = system(cmd . ' ' . shellescape(a:path))
    if v:shell_error
      let ret = iconv(ret, 'char', &encoding)
      throw substitute(ret, '\n', '', 'g')
    endif
  endfunction
elseif s:is_windows
  function! s:delete_dir_impl(path, ...) abort
    let flags = a:0 ? a:1 : ''
    if &shell =~? "sh$"
      let cmd = flags =~# 'r' ? 'rm -r' : 'rmdir'
      let cmd .= flags =~# 'f' && cmd ==# 'rm -r' ? ' -f' : ''
      let ret = system(cmd . ' ' . shellescape(a:path))
    else
      " 'f' flag does not make sense.
      let cmd = 'rmdir /Q'
      let cmd .= flags =~# 'r' ? ' /S' : ''
      let ret = system(cmd . ' "' . a:path . '"')
    endif
    if v:shell_error
      let ret = iconv(ret, 'char', &encoding)
      throw substitute(ret, '\n', '', 'g')
    endif
  endfunction
else
  function! s:delete_dir_impl(...) abort
      throw 'vivacious: fatal: s:delete_dir_impl(): '
      \   . 'your platform is not supported'
  endfunction
endif

" Add to runtimepath.
" And source 'plugin' directory.
" TODO: Handle error?
function! s:source_plugin(plug_dir) abort
    let &rtp .= ',' . a:plug_dir
    for file in s:glob(s:path_join(a:plug_dir, 'plugin', '**', '*.vim'))
        source `=file`
    endfor
endfunction

function! s:glob(expr) abort
    return glob(a:expr, 1, 1)
endfunction

function! s:git(...) abort
    if type(a:1) ==# type({})
        let args = copy(a:1.args)
        if has_key(a:1, 'work_tree')
            let git_dir = s:path_join(a:1.work_tree, '.git')
            let args = ['--git-dir', git_dir,
            \           '--work-tree', a:1.work_tree] + args
        endif
    else
        let args = copy(a:000)
    endif
    if !executable('git')
        " This should be checked at earlier time!
        throw "vivacious: fatal: 'git' is not installed in your PATH."
    endif
    let args = map(args, 's:shellescape(v:val)')
    let out  = system(join(['git'] + args, ' '))
    return substitute(out, '\n\+$', '', '')
endfunction

function! s:get_lockfile() abort
    return s:path_join(s:vim_dir(), 'Vivacious.lock')
endfunction

function! s:vim_dir() abort
    if exists('$HOME')
        let home = $HOME
    elseif exists('$HOMEDRIVE') && exists('$HOMEPATH')
        let home = $HOMEDRIVE . $HOMEPATH
    else
        throw 'vivacious: fatal: Could not find home directory.'
    endif
    if isdirectory(s:path_join(home, '.vim'))
        return s:path_join(home, '.vim')
    elseif isdirectory(s:path_join(home, 'vimfiles'))
        return s:path_join(home, 'vimfiles')
    else
        throw 'vivacious: Could not find .vim directory.'
    endif
endfunction

function! s:vimbundle_dir() abort
    return s:path_join(s:vim_dir(), 'bundle')
endfunction

let s:PATH_SEP = s:is_windows ? '\' : '/'
function! s:path_join(...) abort
    return join(a:000, s:PATH_SEP)
endfunction

function! s:path_basename(path) abort
    let path = substitute(a:path, '[/\\]\+$', '', '')
    return fnamemodify(path, ':t')
endfunction

function! s:path_dirname(path) abort
    let path = substitute(a:path, '[/\\]\+$', '', '')
    return fnamemodify(path, ':h')
endfunction

" If dir is relative path, concat to s:vim_dir().
function! s:abspath_record_dir(dir) abort
    return (a:dir =~# '^[/\\]' ? a:dir :
    \           s:path_join(s:vim_dir(), a:dir))
endfunction

" TODO: Support older vim
function! s:mkdir_p(path) abort
    return mkdir(a:path, 'p')
endfunction

" TODO: More appropriate highlight.
function! s:info(msg) abort
    echohl MoreMsg
    echo 'vivacious:' a:msg
    echohl None
endfunction

" TODO: More appropriate highlight.
function! s:info_msg(msg) abort
    echohl MoreMsg
    echomsg 'vivacious:' a:msg
    echohl None
endfunction

function! s:echomsg(msg) abort
    echohl ErrorMsg
    echomsg 'vivacious:' a:msg
    echohl None
endfunction

function! s:error(msg) abort
    echohl ErrorMsg
    echomsg 'vivacious:' a:msg
    echohl None
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et:
