scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


" autoload/vivo.vim must be runnable without other files
" in vivo repository.
if !executable('git')
    echohl ErrorMsg
    echomsg "vivo: 'git' is not installed in your PATH."
    echohl None
    finish
endif

let g:vivo#debug = get(g:, 'vivo#debug', 0)


let s:LOCKFILE_VERSION = 1

function! vivo#load_plugins(...)
    let lockfile = s:MetaInfo.get_lockfile()
    for record in s:MetaInfo.get_records_from_file(lockfile)
        let plug_dir = s:FS.abspath_record_dir(record.dir)
        if isdirectory(plug_dir) && record.active
            " Keep runtimepath short as possible.
            let path = fnamemodify(plug_dir, ':~')
            " Prepend
            let &rtp = join([path, &rtp], ',')
        endif
    endfor
endfunction

function! vivo#loaded_plugin(name) abort
    let lockfile = s:MetaInfo.get_lockfile()
    let record = s:MetaInfo.get_record_by_name(a:name, lockfile)
    return !empty(record) && record.active
endfunction

function! vivo#helptags(...)
    for dir in s:FS.globpath(&rtp, 'doc')
        if filewritable(dir)    " Get rid of $VIMRUNTIME, and so on.
            helptags `=dir`
        endif
    endfor
endfunction

function! vivo#install(...)
    call s:Vivo.call_with_error_handlers(
    \       'install', a:000, 'cmd_install_help')
endfunction

function! vivo#remove(...) abort
    call s:Vivo.call_with_error_handlers(
    \       'remove', a:000, 'cmd_remove_help')
endfunction

function! vivo#__complete_plug_name__(arglead, cmdline, ...) abort
    if a:cmdline !~# '^[A-Z]\w*\s\+.\+$'    " no args
        return map(s:MetaInfo.get_records_from_file(
        \           s:MetaInfo.get_lockfile()), 'v:val.name')
    elseif a:arglead !=# ''    " has arguments
        if a:arglead =~# '[*?]'    " it has wildcard characters
            return s:MetaInfo.expand_plug_name(
            \       a:arglead, s:MetaInfo.get_lockfile())
        endif
        " match by prefix
        let candidates = map(
        \   s:MetaInfo.get_records_from_file(s:MetaInfo.get_lockfile()),
        \   'v:val.name')
        call filter(candidates, 'v:val =~# "^" . a:arglead')
        return candidates
    endif
endfunction

function! vivo#purge(...) abort
    call s:Vivo.call_with_error_handlers(
    \       'purge', a:000, 'cmd_purge_help')
endfunction

function! vivo#list(...) abort
    call s:Vivo.call_with_error_handlers(
    \       'list', a:000, 'cmd_list_help')
endfunction

function! vivo#fetch_all(...) abort
    call s:Vivo.call_with_error_handlers(
    \   'fetch_all', a:000, 'cmd_fetch_all_help')
endfunction

function! vivo#update(...) abort
    call s:Vivo.call_with_error_handlers(
    \   'update', a:000, 'cmd_update_help')
endfunction

function! vivo#manage(...) abort
    call s:Vivo.call_with_error_handlers(
    \   'manage', a:000, 'cmd_manage_help')
endfunction

function! vivo#enable(...) abort
    call s:Vivo.call_with_error_handlers(
    \   'enable', a:000, 'cmd_enable_help')
endfunction

function! vivo#disable(...) abort
    call s:Vivo.call_with_error_handlers(
    \   'disable', a:000, 'cmd_disable_help')
endfunction


let s:Vivo = {}
let s:MetaInfo = {}
let s:FS = {}
let s:Msg = {}
" TODO: for mock object testing
function! vivo#__inject__(name, obj) abort
    if index(['Vivo', 'MetaInfo', 'FS', 'Msg'],
    \   a:name) >=# 0
        let s:[a:name] = a:obj
    else
        throw "vivo: internal error: Cannot inject '" . a:name . "'."
    endif
endfunction

function! s:localfunc(name) abort
    let sid = matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_localfunc$')
    return function(printf('<SNR>%d_%s', sid, a:name))
endfunction

function! s:method(obj, method) abort
    let s:[a:obj][a:method] = s:localfunc(a:obj . '_' . a:method)
endfunction



let s:is_windows = has('win16') || has('win32')
\               || has('win64') || has('win95')
let s:is_unix = has('unix')
let s:NONE = []
let s:GIT_URL_RE  = '^\%(https\?\|git\)://'
let s:GIT_URL_RE_PLUG_NAME = '\([^/]\+\)\%(\.git\)\?/\?$'
let s:HTTP_URL_RE = '^https\?://'


" ===================== s:Vivo =====================
" Core functions

function! vivo#get_vivo() abort
    return s:Vivo
endfunction

function! s:Vivo_call_with_error_handlers(mainfunc, args, helpfunc) abort dict
    try
        call self[a:mainfunc](a:args)
    catch /^vivo:\s*fatal:/
        let e = substitute(v:exception, '^vivo:\s*fatal:\s*', '', '')
        call s:Msg.error('Fatal error. '
        \              . 'Please report this to '
        \              . 'https://github.com/tyru/vivo.vim/issues/new !')
        call s:Msg.error('Error: ' . e . ' at ' . v:throwpoint)
        call self[a:helpfunc]()
    catch /^vivo:/
        let e = substitute(v:exception, '^vivo:\s*', '', '')
        for line in split(e, '\n')
            call s:Msg.error(line)
        endfor
        call self[a:helpfunc]()
    catch
        call s:Msg.error('Internal error. '
        \              . 'Please report this to '
        \              . 'https://github.com/tyru/vivo.vim/issues/new !')
        call s:Msg.error('Error: ' . v:exception . ' at ' . v:throwpoint)
        call self[a:helpfunc]()
    endtry
endfunction
call s:method('Vivo', 'call_with_error_handlers')

function! s:Vivo_install(args) abort dict
    if len(a:args) ==# 0 || a:args[0] =~# '^\%(-h\|--help\)$'
        return self.cmd_install_help()
    endif
    if len(a:args) !=# 1
        throw 'vivo: VivoInstall: too few or too many arguments.'
    endif
    if a:args[0] =~# '^[^/]\+/[^/]\+$'
        " 'tyru/vivo.vim'
        let url = 'https://github.com/' . a:args[0]
        call s:Vivo.install_and_record(url, 1, s:FS.vimbundle_dir())
    elseif a:args[0] =~# s:GIT_URL_RE
        " 'https://github.com/tyru/vivo.vim'
        let url = a:args[0]
        call s:Vivo.install_and_record(url, 1, s:FS.vimbundle_dir())
    else
        throw 'vivo: VivoInstall: invalid arguments.'
    endif
endfunction
call s:method('Vivo', 'install')

function! s:Vivo_install_and_record(url, redraw, vimbundle_dir) abort dict
    call s:FS.install_git_plugin(a:url, a:redraw, a:vimbundle_dir)
    let plug_name = get(matchlist(a:url, s:GIT_URL_RE_PLUG_NAME), 1, '')
    let plug_dir = s:FS.join(a:vimbundle_dir, plug_name)
    let record = s:MetaInfo.update_record(a:url, plug_dir, 1)
    call s:FS.lock_version(record, plug_name, plug_dir)
endfunction
call s:method('Vivo', 'install_and_record')

function! s:Vivo_cmd_install_help() abort dict
    echo ' '
    echo 'Usage: VivoInstall <source>'
    echo '       VivoInstall tyru/vivo.vim'
    echo '       VivoInstall https://github.com/tyru/vivo.vim'
endfunction
call s:method('Vivo', 'cmd_install_help')

function! s:Vivo_remove(args) abort dict
    if len(a:args) ==# 0 || a:args[0] =~# '^\%(-h\|--help\)$'
        return self.cmd_remove_help()
    endif
    if len(a:args) !=# 1 || a:args[0] !~# '^[^/\\]\+$'
        throw 'vivo: VivoRemove: invalid argument.'
    endif
    call s:Vivo.uninstall_plugin_wildcard(
    \       a:args[0], 1, s:MetaInfo.get_lockfile())
endfunction
call s:method('Vivo', 'remove')

function! s:Vivo_purge(args) abort dict
    if len(a:args) ==# 0 || a:args[0] =~# '^\%(-h\|--help\)$'
        return self.cmd_purge_help()
    endif
    if len(a:args) !=# 1 || a:args[0] !~# '^[^/\\]\+$'
        throw 'vivo: VivoPurge: invalid argument.'
    endif
    call s:Vivo.uninstall_plugin_wildcard(
    \           a:args[0], 0, s:MetaInfo.get_lockfile())
endfunction
call s:method('Vivo', 'purge')

function! s:Vivo_uninstall_plugin_wildcard(wildcard, keep_record, metafile) abort dict
    let plug_name_list = s:MetaInfo.expand_plug_name(a:wildcard, a:metafile)
    if empty(plug_name_list)
        echo 'No matching plugins.'
        return
    endif
    let redraw = (len(plug_name_list) >=# 2 ? 0 : 1)
    " Ask if a user really uninstalls them.
    " TODO: highlight
    echo join(map(copy(plug_name_list), '"* " . v:val'), "\n")
    if input('Do you want to uninstall them?[y/N]: ') !~# '^[yY]'
        return
    endif
    echon "\n"
    " Uninstall all.
    for plug_name in plug_name_list
        call s:Vivo.uninstall_plugin(
        \       plug_name, a:keep_record, redraw, a:metafile)
    endfor
endfunction
call s:method('Vivo', 'uninstall_plugin_wildcard')

function! s:Vivo_uninstall_plugin(plug_name, keep_record, redraw, metafile) abort dict
    let vimbundle_dir = s:FS.vimbundle_dir()
    let plug_dir = s:FS.join(vimbundle_dir, a:plug_name)
    let exists_dir = isdirectory(plug_dir)
    let has_record = s:MetaInfo.has_record_name_of(a:plug_name, a:metafile)
    if !exists_dir && !has_record
        throw "vivo: '" . a:plug_name . "' is not installed."
    endif
    let bundleconfig = s:FS.join(s:FS.vimbundleconfig_dir(),
    \                            a:plug_name . '.vim')
    let has_bundleconfig = filereadable(bundleconfig)
    " Remove the plugin info.
    if has_record && !a:keep_record
        call s:MetaInfo.do_unrecord_by_name(a:plug_name, a:metafile)
        if !exists_dir && !has_bundleconfig && a:redraw
            redraw    " before the last message
        endif
        call s:Msg.info(printf(
        \       "Unrecorded the plugin info of '%s'.", a:plug_name))
    endif
    " Remove the plugin directory.
    if exists_dir
        call s:Msg.info_nohist(printf("Deleting the plugin directory '%s'...", a:plug_name))
        call s:FS.delete_dir(plug_dir)
        if !has_bundleconfig && a:redraw
            redraw    " before the last message
        endif
        call s:Msg.info(printf(
        \       "Deleting the plugin directory '%s'... Done.", a:plug_name))
    endif
    if has_bundleconfig
        call s:Msg.info_nohist(printf(
        \       "Deleting the bundleconfig file of '%s'...", a:plug_name))
        call delete(bundleconfig)
        if a:redraw
            redraw    " before the last message
        endif
        call s:Msg.info(printf(
        \       "Deleting the bundleconfig file of '%s'... Done.", a:plug_name))
    endif
endfunction
call s:method('Vivo', 'uninstall_plugin')

function! s:Vivo_cmd_remove_help() abort dict
    echo ' '
    echo 'Usage: VivoRemove <plugin name in bundle dir>'
    echo '       VivoRemove vivo.vim'
    echo '       VivoRemove *'
    echo ' '
    echo ':VivoRemove removes only a plugin directory.'
    echo 'It keeps a plugin info.'
    echo 'After this command is executed, :VivoFetchAll can fetch a plugin directory again.'
endfunction
call s:method('Vivo', 'cmd_remove_help')

function! s:Vivo_cmd_purge_help() abort dict
    echo ' '
    echo 'Usage: VivoPurge <plugin name in bundle dir>'
    echo '       VivoPurge vivo.vim'
    echo '       VivoPurge *'
    echo ' '
    echo ':VivoPurge removes both a plugin directory and a plugin info.'
    echo ':VivoFetchAll doesn''t help, all data about specified plugin are gone.'
endfunction
call s:method('Vivo', 'cmd_purge_help')

function! s:Vivo_list(...) abort dict
    let vimbundle_dir = s:FS.vimbundle_dir()
    let records = s:MetaInfo.get_records_from_file(s:MetaInfo.get_lockfile())
    if empty(records)
        echomsg 'No plugins are installed.'
        return
    endif
    for record in records
        let plug_dir = s:FS.join(vimbundle_dir, record.name)
        if isdirectory(plug_dir)
            if record.active
                echohl MoreMsg
                echomsg record.name
                echohl None
            else
                echohl WarningMsg
                echomsg record.name . ' (inactive)'
                echohl None
            endif
        else
            echohl WarningMsg
            echomsg record.name . " (not fetched)"
            echohl None
        endif
        echomsg "  Directory: " . s:FS.abspath_record_dir(record.dir)
        echomsg "  Type: " . record.type
        echomsg "  URL: " . record.url
        echomsg "  Version: " . record.version
    endfor
    echomsg ' '
    echomsg 'Listed managed plugins.'
endfunction
call s:method('Vivo', 'list')

function! s:Vivo_cmd_list_help() abort dict
    echo ' '
    echo 'Usage: VivoList'
    echo ' '
    echo 'Lists managed plugins including plugins which have been not fetched.'
endfunction
call s:method('Vivo', 'cmd_list_help')

function! s:Vivo_fetch_all(args) abort dict
    if len(a:args) >= 1 && a:args[0] =~# '^\%(-h\|--help\)$'
        return self.cmd_fetch_all_help()
    endif
    let metafile = (len(a:args) >= 1 ? expand(a:args[0]) : s:MetaInfo.get_lockfile())
    if metafile =~# s:HTTP_URL_RE
        let content = s:Vivo.http_get(metafile)
        let metafile = tempname()
        call writefile(split(content, '\r\?\n', 1), metafile)
    endif
    try
        call s:Vivo.fetch_all_from_metafile(metafile)
    finally
        if metafile =~# s:HTTP_URL_RE
            call delete(metafile)
        endif
    endtry
endfunction
call s:method('Vivo', 'fetch_all')

function! s:Vivo_fetch_all_from_metafile(metafile) abort dict
    if !filereadable(a:metafile)
        throw "vivo: Specified metafile doesn't exist. "
        \   . '(' . a:metafile . ')'
    endif
    let vimbundle_dir = s:FS.vimbundle_dir()
    for record in s:MetaInfo.get_records_from_file(a:metafile)
        let plug_dir = s:FS.abspath_record_dir(record.dir)
        if isdirectory(plug_dir)
            continue    " already installed, skip
        endif
        let vimbundle_dir = s:FS.dirname(plug_dir)
        let plug_name = s:FS.basename(plug_dir)
        try
            call s:FS.install_git_plugin(record.url, 0, vimbundle_dir)
            call s:MetaInfo.update_record(
            \       record.url, plug_dir, 0, {'version': record.version})
            call s:FS.lock_version(record, plug_name, plug_dir)
        catch /vivo: You already installed/
            call s:Msg.info("You already installed '" . plug_name . "'.")
        endtry
    endfor
    let s:Msg.silent = has('vim_starting')
    call s:Msg.info('VivoFetchAll: All plugins are installed!')
    let s:Msg.silent = 0
endfunction
call s:method('Vivo', 'fetch_all_from_metafile')

function! s:Vivo_cmd_fetch_all_help() abort dict
    echo ' '
    echo 'Usage: VivoFetchAll [<Vivo.lock>]'
    echo '       VivoFetchAll /path/to/Vivo.lock'
    echo ' '
    echo 'If no arguments are given, ~/.vim/Vivo.lock is used.'
endfunction
call s:method('Vivo', 'cmd_fetch_all_help')

function! s:Vivo_update(...) abort dict
    " Pre-check and build git update commands.
    let update_cmd_list = []
    for record in s:MetaInfo.get_records_from_file(s:MetaInfo.get_lockfile())
        let plug_dir = s:FS.abspath_record_dir(record.dir)
        if !isdirectory(plug_dir)
            call add(update_cmd_list,
            \   {'msg': printf("'%s' is not installed...skip.", record.name),
            \    'highlight': 'MoreMsg'})
        endif
        let pullinfo = s:FS.get_pullinfo(
        \                   plug_dir, record.remote, record.branch)
        if !empty(pullinfo)
            call add(update_cmd_list,
            \   {'name': record.name,
            \    'work_tree': plug_dir,
            \    'args': ['pull', pullinfo.remote, pullinfo.branch]})
        else
            " If the branch does not have a upstream, shows an error.
            call add(update_cmd_list,
            \   {'msg': printf("vivo: couldn't find a way to "
            \                . "update plugin '%s'.", record.name),
            \    'highlight': 'WarningMsg'})
            call s:Msg.debug(printf("vivo: couldn't find a way to "
            \                . "update plugin '%s'.", record.name))
        endif
    endfor
    " Update all plugins.
    for cmd in update_cmd_list
        if has_key(cmd, 'msg')
            call s:Msg.info(cmd.msg, cmd.highlight)
        else
            let name = remove(cmd, 'name')
            call s:Msg.info_nohist(printf('%s: Updating...', name), 'Normal')
            let oldver = s:FS.git({'work_tree': cmd.work_tree,
            \                      'args': ['rev-parse', '--short', 'HEAD']})
            let start = reltime()
            call s:FS.git(cmd)
            let time  = str2float(reltimestr(reltime(start)))
            let ver = s:FS.git({'work_tree': cmd.work_tree,
            \                   'args': ['rev-parse', '--short', 'HEAD']})
            if oldver !=# ver
                call s:Msg.info(printf('%s: Updated (%.1fs, %s -> %s)',
                \                       name, time, oldver, ver))
            else
                call s:Msg.info(printf('%s: Unchanged (%.1fs, %s)',
                \                       name, time, ver), 'Normal')
            endif
        endif
    endfor
    call s:Msg.info(' ')
    call s:Msg.info('Updated all plugins!')
endfunction
call s:method('Vivo', 'update')

function! s:Vivo_cmd_update_help() abort dict
    echo ' '
    echo 'Usage: VivoUpdate'
    echo ' '
    echo 'Updates all installed plugins.'
endfunction
call s:method('Vivo', 'cmd_update_help')

function! s:Vivo_manage(args) abort dict
    for plug_dir in s:FS.glob(a:args[0])
        " Supported only Git repository.
        if getftype(s:FS.join(plug_dir, '.git')) !=# ''
            let pullinfo = s:FS.get_pullinfo(plug_dir)
            if empty(pullinfo)
                throw 'vivo: Could not get upstream info '
                \   . "from '" . plug_dir . "'."
            endif
            let remote_list = split(s:FS.git({
            \   'work_tree': plug_dir, 'args': ['remote', '-v']}), '\n')
            let re = '^' . pullinfo.remote . '\s\+\(\S\+\)'
            let idx = match(remote_list, re)
            let url = (idx >=# 0 ? get(matchlist(remote_list[idx], re), 1, '')
            \                    : '')
            if idx <# 0 || url ==# ''
                throw 'vivo: Could not get URL from upstream '
                \   . '(' . pullinfo.remote . ').'
            endif
            call s:MetaInfo.update_record(url, plug_dir, 1)
        endif
    endfor
endfunction
call s:method('Vivo', 'manage')

function! s:Vivo_cmd_manage_help() abort dict
    echo ' '
    echo 'Usage: VivoManage {wildcard filepath}'
    echo '       VivoManage ~/.vim/bundle/*'
    echo ' '
    echo 'Add existing installed plugins to lockfile.'
endfunction
call s:method('Vivo', 'cmd_manage_help')

function! s:Vivo_enable(args) abort
    let vim_lockfile = s:MetaInfo.get_lockfile()
    let wildcard = a:args[0]
    for plug_name in s:MetaInfo.expand_plug_name(wildcard, vim_lockfile)
        let record = s:MetaInfo.get_record_by_name(plug_name, vim_lockfile)
        if empty(record)
            call s:Msg.warn("'" . plug_name . "' is ignored because "
            \   . "it is not a managed plugin name.")
            continue
        endif
        if record.active
            call s:Msg.warn("'" . plug_name . "' is already active.")
            continue
        endif
        let s:Msg.silent = 1
        try
            call s:MetaInfo.update_record(
            \       record.url, s:FS.abspath_record_dir(record.dir), 1,
            \       {'active': 1})
        finally
            let s:Msg.silent = 0
        endtry
        call s:Msg.info(printf("Enabled plugin '%s'.", plug_name))
    endfor
endfunction
call s:method('Vivo', 'enable')

function! s:Vivo_cmd_enable_help() abort dict
    echo ' '
    echo 'Usage: VivoEnable <plugin name in bundle dir>'
    echo '       VivoEnable vivo.vim'
    echo '       VivoEnable *'
    echo ' '
    echo 'Enable managed plugins.'
endfunction
call s:method('Vivo', 'cmd_enable_help')

function! s:Vivo_disable(args) abort
    let vim_lockfile = s:MetaInfo.get_lockfile()
    let wildcard = a:args[0]
    for plug_name in s:MetaInfo.expand_plug_name(wildcard, vim_lockfile)
        let record = s:MetaInfo.get_record_by_name(plug_name, vim_lockfile)
        if empty(record)
            call s:Msg.warn("'" . plug_name . "' is ignored because "
            \   . "it is not a managed plugin name.")
            continue
        endif
        if !record.active
            call s:Msg.warn("'" . plug_name . "' is already inactive.")
            continue
        endif
        let s:Msg.silent = 1
        try
            call s:MetaInfo.update_record(
            \       record.url, s:FS.abspath_record_dir(record.dir), 1,
            \       {'active': 0})
        finally
            let s:Msg.silent = 0
        endtry
        call s:Msg.info(printf("Disabled plugin '%s'.", plug_name))
    endfor
endfunction
call s:method('Vivo', 'disable')

function! s:Vivo_cmd_disable_help() abort dict
    echo ' '
    echo 'Usage: VivoDisable <plugin name in bundle dir>'
    echo '       VivoDisable vivo.vim'
    echo '       VivoDisable *'
    echo ' '
    echo 'Disable managed plugins.'
endfunction
call s:method('Vivo', 'cmd_disable_help')

function! s:Vivo_http_get(url) abort dict
    if executable('curl')
        return system('curl -L -s -k ' . s:FS.shellescape(a:url))
    elseif executable('wget')
        return system('wget -q -L -O - ' . s:FS.shellescape(a:url))
    else
        throw 'vivo: s:Vivo.http_get(): '
        \   . 'you doesn''t have curl nor wget.'
    endif
endfunction
call s:method('Vivo', 'http_get')


" ===================== s:MetaInfo =====================
" Functions to manipulate metafile.
" lockfile is one of metafile saved in `s:MetaInfo.get_lockfile()`.

function! vivo#get_metainfo() abort
    return s:MetaInfo
endfunction

function! s:MetaInfo_get_lockfile() abort dict
    return s:FS.join(s:FS.vim_dir(), 'Vivo.lock')
endfunction
call s:method('MetaInfo', 'get_lockfile')

" @return updated record
" @param update_existing (Boolean)
"   non-zero (:VivoInstall)
"   * Update a record even if the plugin is already recorded.
"   zero (:VivoFetchAll)
"   * Don't update a record.
function! s:MetaInfo_update_record(url, plug_dir, update_existing, ...) abort dict
    let opt_record = (a:0 && type(a:1) ==# type({}) ? a:1 : {})
    let vimbundle_dir = s:FS.dirname(a:plug_dir)
    let plug_name = s:FS.basename(a:plug_dir)
    let vim_lockfile = s:MetaInfo.get_lockfile()
    let old_record = s:MetaInfo.get_record_by_name(plug_name, vim_lockfile)
    " Record or Lock
    if empty(old_record)
        " If the record is not found, record the plugin info.
        let dir = s:FS.join(s:FS.basename(vimbundle_dir), plug_name)
        let ver = (has_key(opt_record, 'version') ? opt_record.version :
        \           s:FS.git({'work_tree': a:plug_dir,
        \                     'args': ['rev-parse', 'HEAD']}))
        let branch = s:FS.git_current_branch(a:plug_dir)
        let remote = s:FS.git_upstream_of(branch, a:plug_dir)
        let record = s:MetaInfo.make_record(plug_name, dir, a:url, 'git',
        \                                   ver, branch, remote, 1)
        if !empty(opt_record)
            call extend(record, opt_record, 'force')
        endif
        call s:MetaInfo.do_record(record, vim_lockfile)
        call s:Msg.info(printf("Recorded the plugin info of '%s'.", plug_name))
        return record
    elseif a:update_existing
        " Bump version.
        let dir = s:FS.join(s:FS.basename(vimbundle_dir), plug_name)
        let ver = s:FS.git({'work_tree': a:plug_dir,
        \                   'args': ['rev-parse', 'HEAD']})
        let record = s:MetaInfo.make_record(
        \               plug_name, dir, a:url, 'git', ver,
        \               old_record.branch, old_record.remote, 1)
        if !empty(opt_record)
            call extend(record, opt_record, 'force')
        endif
        call s:MetaInfo.do_unrecord_by_name(plug_name, vim_lockfile)
        call s:MetaInfo.do_record(record, vim_lockfile)
        if old_record.version ==# record.version
            call s:Msg.info(printf("The version of '%s' was unchanged (%s).",
            \                       plug_name, record.version))
        else
            call s:Msg.info(printf("Updated the version of '%s' (%s -> %s).",
            \               plug_name, old_record.version, record.version))
        endif
        return record
    else
        return old_record
    endif
endfunction
call s:method('MetaInfo', 'update_record')

" * 'skk.vim' doesn't match 'eskk.vim'
" * If 'skk.vim' is not installed, return empty list.
function! s:MetaInfo_expand_plug_name(wildcard, metafile) abort dict
    if a:wildcard !~# '[*?]'
        let records = s:MetaInfo.get_records_from_file(a:metafile)
        return map(filter(records, 'v:val.name ==# a:wildcard'), 'v:val.name')
    endif
    let records = s:MetaInfo.get_records_from_file(a:metafile)
    let candidates = map(records, 'v:val.name')
    " wildcard -> regexp
    let re = substitute(a:wildcard, '\*', '.*', 'g')
    let re = substitute(re, '?', '.', 'g')
    return filter(candidates, 'v:val =~# re')
endfunction
call s:method('MetaInfo', 'expand_plug_name')

function! s:MetaInfo_make_record(name, dir, url, type, version, branch, remote, active) abort dict
    return {'name': a:name, 'dir': a:dir, 'url': a:url,
    \       'type': a:type, 'version': a:version, 'branch': a:branch,
    \       'remote': a:remote, 'active': a:active}
endfunction
call s:method('MetaInfo', 'make_record')

function! s:MetaInfo_do_record(record, metafile) abort dict
    let lines = s:MetaInfo.readfile(a:metafile)
    call s:MetaInfo.writefile(
    \       lines + [s:MetaInfo.to_ltsv(a:record)], a:metafile)
endfunction
call s:method('MetaInfo', 'do_record')

" If metafile doesn't exist, treat it as empty file.
function! s:MetaInfo_do_unrecord_by_name(plug_name, metafile) abort dict
    if !filereadable(a:metafile)
        return
    endif
    " Get rid of the plugin info record which has a name of a:plug_name.
    let records = filter(s:MetaInfo.get_records_from_file(a:metafile),
    \                 'v:val.name !=# a:plug_name')
    let lines = map(records, 's:MetaInfo.to_ltsv(v:val)')
    call s:MetaInfo.writefile(lines, a:metafile)
endfunction
call s:method('MetaInfo', 'do_unrecord_by_name')

" If metafile doesn't exist, treat it as empty file.
function! s:MetaInfo_readfile(metafile) abort dict
    if !filereadable(a:metafile)
        return []
    endif
    let [ver; lines] = readfile(a:metafile)
    let result = s:MetaInfo.parse_ltsv(ver)
    if !has_key(result, 'version')
        throw 'vivo: fatal: s:MetaInfo.readfile(): '
        \   . 'Vivo.lock file is corrupted.'
    endif
    if result.version > s:LOCKFILE_VERSION
        throw 'vivo: Too old vivo.vim for parsing metafile. '
        \   . 'Please update the plugin.'
    endif
    return filter(lines, '!empty(v:val)')
endfunction
call s:method('MetaInfo', 'readfile')

function! s:MetaInfo_writefile(lines, metafile) abort dict
    return writefile(["version:" . s:LOCKFILE_VERSION] + a:lines, a:metafile)
endfunction
call s:method('MetaInfo', 'writefile')

function! s:MetaInfo_get_record_by_name(name, metafile) abort dict
    let records = s:MetaInfo.get_records_from_file(a:metafile)
    call filter(records, 'v:val.name ==# a:name')
    return get(records, 0, {})
endfunction
call s:method('MetaInfo', 'get_record_by_name')

function! s:MetaInfo_has_record_name_of(name, metafile) abort dict
    return !empty(s:MetaInfo.get_record_by_name(a:name, a:metafile))
endfunction
call s:method('MetaInfo', 'has_record_name_of')

" If metafile doesn't exist, treat it as empty file.
function! s:MetaInfo_get_records_from_file(metafile) abort dict
    if !filereadable(a:metafile)
        return []
    endif
    let records = map(s:MetaInfo.readfile(a:metafile),
    \                's:MetaInfo.parse_ltsv(v:val)')
    return filter(records, '!empty(v:val)')
endfunction
call s:method('MetaInfo', 'get_records_from_file')

" http://ltsv.org/
function! s:MetaInfo_to_ltsv(dict) abort dict
    return join(values(map(copy(a:dict), 'v:key . ":" . v:val')), "\t")
endfunction
call s:method('MetaInfo', 'to_ltsv')

function! s:MetaInfo_parse_ltsv(line) abort dict
    let dict = {}
    let re = '^\([^:]\+\):\(.*\)'
    for keyval in split(a:line, '\t')
        if keyval ==# ''
            continue
        endif
        let m = matchlist(keyval, re)
        if empty(m)
            throw 'vivo: fatal: s:MetaInfo.parse_ltsv(): '
            \   . 'Vivo.lock file is corrupted.'
        endif
        let dict[m[1]] = m[2]
    endfor
    " TODO: Validate keys/values?
    return dict
endfunction
call s:method('MetaInfo', 'parse_ltsv')


" ===================== s:FS =====================
" Functions about filesystem.

function! vivo#get_filesystem() abort
    return s:FS
endfunction

function! s:FS_install_git_plugin(url, redraw, vimbundle_dir) abort dict
    let plug_name = get(matchlist(a:url, s:GIT_URL_RE_PLUG_NAME), 1, '')
    if plug_name ==# ''
        throw 'vivo: Invalid URL(' . a:url . ')'
    endif
    if !isdirectory(a:vimbundle_dir)
        call s:FS.mkdir_p(a:vimbundle_dir)
    endif
    let plug_dir = s:FS.join(a:vimbundle_dir, plug_name)
    if isdirectory(plug_dir)
        throw "vivo: You already installed '" . plug_name . "'. "
        \   . "Please uninstall it by "
        \   . ":VivoRemove or :VivoPurge."
    endif

    " Fetch & Install
    call s:Msg.info_nohist(printf("Fetching a plugin from '%s'...", a:url))
    call s:FS.git('clone', a:url, plug_dir)
    if v:shell_error
        throw printf("vivo: 'git clone %s %s' failed.", a:url, plug_dir)
    endif
    call s:Msg.info(printf("Fetching a plugin from '%s'... Done.", a:url))
    " :source
    call s:FS.source_plugin(plug_dir)
    " :helptags
    let doc_dir = s:FS.join(plug_dir, 'doc')
    if filewritable(doc_dir)
        helptags `=doc_dir`
    endif

    if a:redraw
        redraw    " before the last message
    endif
    call s:Msg.info(printf("Installed a plugin '%s'.", plug_name))
endfunction
call s:method('FS', 'install_git_plugin')

function! s:FS_lock_version(record, plug_name, plug_dir) abort dict
    call s:FS.git({'work_tree': a:plug_dir,
    \              'args': ['checkout', a:record.version]})
    if v:shell_error
        throw printf("vivo: 'git checkout %s' failed.",
        \                               a:record.version)
    endif
    call s:Msg.info(printf("Locked the version of '%s' (%s).",
    \                   a:plug_name, a:record.version))
endfunction
call s:method('FS', 'lock_version')

function! s:FS_delete_dir(dir) abort dict
    if !isdirectory(a:dir)
        throw 'vivo: fatal: s:FS.delete_dir(): '
        \   . 'given non-directory argument (' . a:dir . ').'
    endif
    call s:FS.delete_dir_impl(a:dir, 'rf')
endfunction
call s:method('FS', 'delete_dir')

" Delete a file/directory.
" from https://github.com/vim-jp/vital.vim
if s:is_unix
  function! s:FS_delete_dir_impl(path, ...) abort dict
    let flags = a:0 ? a:1 : ''
    let cmd = flags =~# 'r' ? 'rm -r' : 'rmdir'
    let cmd .= flags =~# 'f' && cmd ==# 'rm -r' ? ' -f' : ''
    let ret = system(cmd . ' ' . s:FS.shellescape(a:path))
    if v:shell_error
      let ret = iconv(ret, 'char', &encoding)
      throw substitute(ret, '\n', '', 'g')
    endif
  endfunction
elseif s:is_windows
  function! s:FS_delete_dir_impl(path, ...) abort dict
    let flags = a:0 ? a:1 : ''
    if &shell =~? "sh$"
      let cmd = flags =~# 'r' ? 'rm -r' : 'rmdir'
      let cmd .= flags =~# 'f' && cmd ==# 'rm -r' ? ' -f' : ''
      let ret = system(cmd . ' ' . s:FS.shellescape(a:path))
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
  function! s:FS_delete_dir_impl(...) abort dict
      throw 'vivo: fatal: s:FS.delete_dir_impl(): '
      \   . 'your platform is not supported'
  endfunction
endif
call s:method('FS', 'delete_dir_impl')

" Add to runtimepath.
" And source 'plugin' directory.
" TODO: Handle error?
function! s:FS_source_plugin(plug_dir) abort dict
    let &rtp .= ',' . a:plug_dir
    for file in s:FS.glob(s:FS.join(a:plug_dir, 'plugin', '**', '*.vim'))
        source `=file`
    endfor
endfunction
call s:method('FS', 'source_plugin')

" TODO: Support older vim
function! s:FS_glob(expr) abort dict
    return glob(a:expr, 1, 1)
endfunction
call s:method('FS', 'glob')

" TODO: Support older vim
function! s:FS_globpath(path, expr) abort dict
    return globpath(a:path, a:expr, 1, 1)
endfunction
call s:method('FS', 'globpath')

function! s:FS_shellescape(str) abort dict
    let quote = (&shellxquote ==# '"' ? "'" : '"')
    return quote . a:str . quote
endfunction
call s:method('FS', 'shellescape')

function! s:FS_git(...) abort dict
    if type(a:1) ==# type({})
        let args = copy(a:1.args)
        if has_key(a:1, 'work_tree')
            let git_dir = s:FS.join(a:1.work_tree, '.git')
            let args = ['--git-dir', git_dir,
            \           '--work-tree', a:1.work_tree] + args
        endif
    else
        let args = copy(a:000)
    endif
    if !executable('git')
        " This should be checked at earlier time!
        throw "vivo: fatal: 'git' is not installed in your PATH."
    endif
    let args = map(args, 's:FS.shellescape(v:val)')
    let out  = system(join(['git'] + args, ' '))
    return substitute(out, '\n\+$', '', '')
endfunction
call s:method('FS', 'git')

function! s:FS_git_current_branch(work_tree) abort dict
    let lines = split(s:FS.git({'args': ['branch'],
    \                           'work_tree': a:work_tree}), '\n')
    let re = '^\* '
    call filter(lines, 'v:val =~# re')
    if empty(lines)
        throw "vivo: fatal: Could not find current branch "
        \   . "from 'git branch' output."
    endif
    return substitute(lines[0], re, '', '')
endfunction
call s:method('FS', 'git_current_branch')

" Get an upstream of remote tracking branch 'a:branch'.
function! s:FS_git_upstream_of(branch, work_tree) abort dict
    let config = 'branch.' . a:branch . '.remote'
    return s:FS.git({'args': ['config', '--get', config],
    \                'work_tree': a:work_tree})
endfunction
call s:method('FS', 'git_upstream_of')

function! s:FS_get_pullinfo(plug_dir, ...) abort
    " If the branch is detached state,
    " See branch when git clone and recorded in Vivo.lock.
    let plug_name = s:FS.basename(a:plug_dir)
    let branch = s:FS.git_current_branch(a:plug_dir)
    if branch =~# '^([^)]\+)$'
        if a:0 ==# 2
            let [remote, branch] = a:000
        else
            let record = s:MetaInfo.get_record_by_name(
            \               plug_name, s:MetaInfo.get_lockfile())
            if empty(record)
                throw "vivo: fatal: s:FS.get_pullinfo(): "
                \   . "Could not find record for '" . plug_name . "'."
            endif
            let [remote, branch] = [record.remote, record.branch]
        endif
        call s:Msg.debug(printf('%s: detached state (%s)',
        \                       plug_name, branch))
        return {'remote': remote, 'branch': branch}

    " If the branch has a remote tracking branch
    else
        let remote = s:FS.git_upstream_of(branch, a:plug_dir)
        if remote !~# '^\s*$'
            if g:vivo#debug
                call s:Msg.debug(printf('%s: upstream is set (%s)',
                \   plug_name, s:FS.git_upstream_of(branch, a:plug_dir)))
            endif
            return {'remote': remote, 'branch': branch}
        else
            " Error
            return {}
        endif
    endif
endfunction
call s:method('FS', 'get_pullinfo')

function! s:FS_vim_dir() abort dict
    if exists('$HOME')
        let home = $HOME
    elseif exists('$HOMEDRIVE') && exists('$HOMEPATH')
        let home = $HOMEDRIVE . $HOMEPATH
    else
        throw 'vivo: fatal: Could not find home directory.'
    endif
    if isdirectory(s:FS.join(home, '.vim'))
        return s:FS.join(home, '.vim')
    elseif isdirectory(s:FS.join(home, 'vimfiles'))
        return s:FS.join(home, 'vimfiles')
    else
        throw 'vivo: Could not find .vim directory.'
    endif
endfunction
call s:method('FS', 'vim_dir')

function! s:FS_vimbundle_dir() abort dict
    return s:FS.join(s:FS.vim_dir(), 'bundle')
endfunction
call s:method('FS', 'vimbundle_dir')

function! s:FS_vimbundleconfig_dir() abort dict
    return s:FS.join(s:FS.vim_dir(), 'bundle')
endfunction
call s:method('FS', 'vimbundleconfig_dir')

let s:PATH_SEP = s:is_windows ? '\' : '/'
function! s:FS_join(...) abort dict
    return join(a:000, s:PATH_SEP)
endfunction
call s:method('FS', 'join')

function! s:FS_basename(path) abort dict
    let path = substitute(a:path, '[/\\]\+$', '', '')
    return fnamemodify(path, ':t')
endfunction
call s:method('FS', 'basename')

function! s:FS_dirname(path) abort dict
    let path = substitute(a:path, '[/\\]\+$', '', '')
    return fnamemodify(path, ':h')
endfunction
call s:method('FS', 'dirname')

" If dir is relative path, concat to s:FS.vim_dir().
function! s:FS_abspath_record_dir(dir) abort dict
    return (a:dir =~# '^[/\\]' ? a:dir :
    \           s:FS.join(s:FS.vim_dir(), a:dir))
endfunction
call s:method('FS', 'abspath_record_dir')

" TODO: Support older vim
function! s:FS_mkdir_p(path) abort dict
    return mkdir(a:path, 'p')
endfunction
call s:method('FS', 'mkdir_p')


" ===================== s:Msg =====================
" Functions about messages.

function! vivo#get_msg() abort
    return s:Msg
endfunction

" If this flag is non-zero, all message functions do not echo at all.
let s:Msg.silent = 0

" TODO: More better highlight.
function! s:Msg_info_nohist(msg, ...) abort dict
    if s:Msg.silent | return | endif
    execute 'echohl' (a:0 ? a:1 : 'MoreMsg')
    if g:vivo#debug
        echomsg 'vivo:' a:msg
    else
        echo 'vivo:' a:msg
    endif
    echohl None
endfunction
call s:method('Msg', 'info_nohist')

" TODO: More better highlight.
function! s:Msg_info(msg, ...) abort dict
    if s:Msg.silent | return | endif
    execute 'echohl' (a:0 ? a:1 : 'MoreMsg')
    echomsg 'vivo:' a:msg
    echohl None
endfunction
call s:method('Msg', 'info')

function! s:Msg_warn(msg, ...) abort dict
    if s:Msg.silent | return | endif
    execute 'echohl' (a:0 ? a:1 : 'WarningMsg')
    echomsg 'vivo:' a:msg
    echohl None
endfunction
call s:method('Msg', 'warn')

function! s:Msg_error(msg, ...) abort dict
    if s:Msg.silent | return | endif
    execute 'echohl' (a:0 ? a:1 : 'ErrorMsg')
    echomsg 'vivo:' a:msg
    echohl None
endfunction
call s:method('Msg', 'error')

function! s:Msg_debug(msg, ...) abort dict
    if s:Msg.silent | return | endif
    if !g:vivo#debug | return | endif
    execute 'echohl' (a:0 ? a:1 : 'WarningMsg')
    echomsg 'vivo(DEBUG):' a:msg
    echohl None
endfunction
call s:method('Msg', 'debug')


let &cpo = s:save_cpo
unlet s:save_cpo
" vim:set et:
