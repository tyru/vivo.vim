scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

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
        throw 'vivacious: VivaInstall: invalid argument.'
    endif
    if a:args[0] =~# '^[^/]\+/[^/]\+$'
        " 'tyru/vivacious.vim'
        call s:install_github_plugin(a:args[0])
    elseif a:args[0] =~# '^\%(http\s\?\|git\)://'
        " 'https://github.com/tyru/vivacious.vim'
        call s:install_git_plugin(a:args[0], 1)
    else
        throw 'vivacious: VivaInstall: invalid argument.'
    endif
endfunction

" @param arg 'tyru/vivacious.vim'
function! s:install_github_plugin(arg) abort
    return s:install_git_plugin('https://github.com/' . a:arg, 1)
endfunction

function! s:install_git_plugin(url, redraw) abort
    let vimbundle_dir = s:vimbundle_dir()
    if !isdirectory(vimbundle_dir)
        call s:mkdir_p(vimbundle_dir)
    endif
    let plug_name = matchstr(a:url, '[^/]\+\%(\.git\)\?$')
    if plug_name ==# ''
        throw 'vivacious: Invalid URL(' . a:url . ')'
    endif
    let plug_dir = s:path_join(vimbundle_dir, plug_name)
    if isdirectory(plug_dir)
        throw "vivacious: You already installed '" . plug_name . "'. "
        \   . "Please uninstall it by "
        \   . ":VivaRemove or :VivaPurge."
    endif
    " Fetch & Install
    call s:info(printf("Fetching a plugin from '%s'...", a:url))
    call s:git('clone', a:url, plug_dir)
    call s:info_msg(printf("Fetching a plugin from '%s'... Done.", a:url))
    call s:source_plugin(plug_dir)
    if a:redraw
        redraw    " before the last message
    endif
    call s:info_msg(printf("Installed a plugin '%s'.", plug_name))
    " Record or Lock
    let old_record = s:get_record_by_name(plug_name)
    let git_dir = s:path_join(plug_dir, '.git')
    if empty(old_record)
        " If the record is not found, record the plugin info.
        let ver = s:git('--git-dir', git_dir, 'rev-parse', 'HEAD')
        let record = s:make_record(plug_name, plug_dir, a:url, 'git', ver)
        call s:record_version(record)
    else
        " If the record is found, lock the version.
        call s:git('--git-dir', git_dir, 'checkout', old_record.version)
    endif
endfunction

function! s:cmd_install_help() abort
    echo ''
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
    call s:uninstall_plugin(a:args[0], 1)
endfunction

function! s:purge(args) abort
    if len(a:args) ==# 0 || a:args[0] =~# '^\%(-h\|--help\)$'
        return s:cmd_purge_help()
    endif
    if len(a:args) !=# 1 || a:args[0] !~# '^[^/\\]\+$'
        throw 'vivacious: VivaPurge: invalid argument.'
    endif
    call s:uninstall_plugin(a:args[0], 0)
endfunction

function! s:uninstall_plugin(plug_name, keep_record) abort
    let vimbundle_dir = s:vimbundle_dir()
    let plug_dir = s:path_join(vimbundle_dir, a:plug_name)
    let exists_dir = isdirectory(plug_dir)
    let has_record = s:has_record_name_of(a:plug_name)
    if !exists_dir && !has_record
        throw "vivacious: '" . a:plug_name . "' is not installed."
    endif
    " Remove the plugin info.
    if has_record && !a:keep_record
        call s:info(printf("Unrecording the plugin info of '%s'...", a:plug_name))
        let git_dir = s:path_join(plug_dir, '.git')
        let ver = s:git('--git-dir', git_dir, 'rev-parse', 'HEAD')
        call s:unrecord_version_by_name(a:plug_name)
        if !exists_dir
            redraw    " before the last message
        endif
        call s:info_msg(printf("Unrecording the plugin info of '%s'... Done.", a:plug_name))
    endif
    " Remove the plugin directory.
    if exists_dir
        call s:info(printf("Uninstalling the plugin '%s'...", a:plug_name))
        call s:delete_dir(plug_dir)
        redraw    " before the last message
        call s:info_msg(printf("Uninstalling the plugin '%s'... Done.", a:plug_name))
    endif
endfunction

function! s:cmd_remove_help() abort
    echo ''
    echo 'Usage: VivaRemove <plugin name in bundle dir>'
    echo '       VivaRemove vivacious.vim'
    echo ''
    echo ':VivaRemove removes only a plugin directory.'
    echo 'It keeps a plugin info.'
    echo 'After this command is executed, :VivaFetchAll can fetch a plugin directory again.'
endfunction

function! s:cmd_purge_help() abort
    echo ''
    echo 'Usage: VivaPurge <plugin name in bundle dir>'
    echo '       VivaPurge vivacious.vim'
    echo ''
    echo ':VivaPurge removes both a plugin directory and a plugin info.'
    echo ':VivaFetchAll doesn''t help, all data about specified plugin are gone.'
endfunction

function! s:list(args) abort
    let lockfile = s:get_lockfile()
    let vimbundle_dir = s:vimbundle_dir()
    let records = filereadable(lockfile) ?
    \               s:get_records_from_file(lockfile) : []
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
        echomsg "  Directory: " . record.dir
        echomsg "  Type: " . record.type
        echomsg "  URL: " . record.url
        echomsg "  Version: " . record.version
    endfor
    echomsg ' '
    echomsg 'Listed managed plugins.'
endfunction

function! s:cmd_list_help() abort
    echo ''
    echo 'Usage: VivaList'
    echo ''
    echo 'Lists managed plugins including plugins which have been not fetched.'
endfunction

function! s:fetch_all(args) abort
    if len(a:args) >= 1 && a:args[0] =~# '^\%(-h\|--help\)$'
        return s:cmd_fetch_all_help()
    endif
    let lockfile = (a:0 ? a:1 : s:get_lockfile())
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
            " XXX: Need to clone into record.plug_dir
            " if bundle dir was changed?
            call s:install_git_plugin(record.url, 0)
        catch /vivacious: You already installed/
            " silently skip
        endtry
    endfor
    call s:info_msg('VivaFetchAll: All plugins are installed!')
endfunction

function! s:cmd_fetch_all_help() abort
    echo ''
    echo 'Usage: VivaFetchAll [<Vivacious.lock>]'
    echo '       VivaFetchAll /path/to/Vivacious.lock'
    echo ''
    echo 'If no arguments are given, ~/.vim/Vivacious.lock is used.'
endfunction

function! s:make_record(plug_name, plug_dir, url, type, version) abort
    return {'name': a:plug_name,
    \       'dir': a:plug_dir,
    \       'url': a:url,
    \       'type': a:type,
    \       'version': a:version}
endfunction

function! s:record_version(record) abort
    let lockfile = s:get_lockfile()
    let lines = (filereadable(lockfile) ? readfile(lockfile) : [])
    call writefile(lines + [s:to_ltsv(a:record)], lockfile)
endfunction

function! s:unrecord_version_by_name(plug_name) abort
    let lockfile = s:get_lockfile()
    if !filereadable(lockfile)
        throw "vivacious: Specified lockfile doesn't exist. "
        \   . '(' . lockfile . ')'
    endif
    " Get rid of the plugin info record which has a name of a:plug_name.
    let re = '\<name:' . a:plug_name . '\>'
    let lines = filter(readfile(lockfile), 'v:val !~# re')
    call writefile(lines, lockfile)
endfunction

function! s:get_record_by_name(name) abort
    let lockfile = s:get_lockfile()
    let records = filter(s:get_records_from_file(lockfile), 'v:val.name ==# a:name')
    return get(records, 0, {})
endfunction

function! s:has_record_name_of(name) abort
    return !empty(s:get_record_by_name(a:name))
endfunction

function! s:get_records_from_file(lockfile) abort
    if !filereadable(a:lockfile)
        " This should be checked at earlier time!
        throw "vivacious: fatal: s:get_records_from_file(): "
        \   . "Specified lockfile doesn't exist. "
        \   . '(' . a:lockfile . ')'
    endif
    return map(readfile(a:lockfile), 's:parse_ltsv(v:val)')
endfunction

" http://ltsv.org/
function! s:to_ltsv(dict) abort
    return join(values(map(a:dict, 'v:key . ":" . v:val')), "\t")
endfunction

function! s:parse_ltsv(line) abort
    let dict = {}
    let re = '^\([^:]\+\):\(.*\)'
    for line in split(a:line, '\t')
        if line ==# ''
            continue
        endif
        let m = matchlist(line, re)
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
    if !executable('git')
        " This should be checked at earlier time!
        throw "vivacious: fatal: 'git' is not installed in your PATH."
    endif
    let args = map(copy(a:000), 'shellescape(v:val)')
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
