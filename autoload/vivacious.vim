scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


let g:vivacious#debug = get(g:, 'vivacious#debug', 0)


let s:LOCKFILE_VERSION = 1

function! vivacious#load_plugins(...)
    let lockfile = s:MetaInfo.get_lockfile()
    for record in s:MetaInfo.get_records_from_file(lockfile)
        if isdirectory(record.path)
            " Keep runtimepath short as possible.
            let path = fnamemodify(record.path, ':~')
            let &rtp = join([&rtp, path], ',')
        endif
    endfor
endfunction

function! vivacious#helptags(...)
    for dir in s:FS.globpath(&rtp, 'doc')
        if filewritable(dir)    " Get rid of $VIMRUNTIME, and so on.
            helptags `=dir`
        endif
    endfor
endfunction

function! vivacious#install(...)
    call s:Vivacious.call_with_error_handlers(
    \       'install', a:000, 'cmd_install_help')
endfunction

function! vivacious#remove(...) abort
    call s:Vivacious.call_with_error_handlers(
    \       'remove', a:000, 'cmd_remove_help')
endfunction

function! vivacious#__complete_remove__(arglead, cmdline, cursorpos) abort
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

function! vivacious#purge(...) abort
    call s:Vivacious.call_with_error_handlers(
    \       'purge', a:000, 'cmd_purge_help')
endfunction

function! vivacious#list(...) abort
    call s:Vivacious.call_with_error_handlers(
    \       'list', a:000, 'cmd_list_help')
endfunction

function! vivacious#fetch_all(...) abort
    call s:Vivacious.call_with_error_handlers(
    \   'fetch_all', a:000, 'cmd_fetch_all_help')
endfunction

function! vivacious#update(...) abort
    call s:Vivacious.call_with_error_handlers(
    \   'update', a:000, 'cmd_update_help')
endfunction

let s:Vivacious = {}
let s:MetaInfo = {}
let s:FS = {}
let s:Msg = {}
" For mock object testing
function! vivacious#__inject__(name, obj) abort
    if index(['Vivacious', 'MetaInfo', 'FS', 'Msg'],
    \   a:name) >=# 0
        let s:[a:name] = a:obj
    else
        throw "vivacious: internal error: Cannot inject '" . a:name . "'."
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
let s:HTTP_URL_RE = '^https\?://'


" ===================== s:Vivacious =====================
" Core functions

function! vivacious#get_vivacious() abort
    return s:Vivacious
endfunction

function! s:Vivacious_call_with_error_handlers(mainfunc, args, helpfunc) abort dict
    try
        call self[a:mainfunc](a:args)
    catch /^vivacious:\s*fatal:/
        let e = substitute(v:exception, '^vivacious:\s*fatal:\s*', '', '')
        call s:Msg.error('Fatal error. '
        \              . 'Please report this to '
        \              . 'https://github.com/tyru/vivacious.vim/issues/new !')
        call s:Msg.error('Error: ' . e . ' at ' . v:throwpoint)
        call self[a:helpfunc]()
    catch /^vivacious:/
        let e = substitute(v:exception, '^vivacious:\s*', '', '')
        call s:Msg.error(e)
        call self[a:helpfunc]()
    catch
        call s:Msg.error('Internal error. '
        \              . 'Please report this to '
        \              . 'https://github.com/tyru/vivacious.vim/issues/new !')
        call s:Msg.error('Error: ' . v:exception . ' at ' . v:throwpoint)
        call self[a:helpfunc]()
    endtry
endfunction
call s:method('Vivacious', 'call_with_error_handlers')

function! s:Vivacious_install(args) abort dict
    if len(a:args) ==# 0 || a:args[0] =~# '^\%(-h\|--help\)$'
        return self.cmd_install_help()
    endif
    if len(a:args) !=# 1
        throw 'vivacious: VivaInstall: too few or too many arguments.'
    endif
    if a:args[0] =~# '^[^/]\+/[^/]\+$'
        " 'tyru/vivacious.vim'
        let url = 'https://github.com/' . a:args[0]
        call s:Vivacious.install_and_record(url, 1, s:FS.vimbundle_dir())
    elseif a:args[0] =~# s:GIT_URL_RE
        " 'https://github.com/tyru/vivacious.vim'
        let url = a:args[0]
        call s:Vivacious.install_and_record(url, 1, s:FS.vimbundle_dir())
    else
        throw 'vivacious: VivaInstall: invalid arguments.'
    endif
endfunction
call s:method('Vivacious', 'install')

function! s:Vivacious_install_and_record(url, redraw, vimbundle_dir) abort dict
    call s:FS.install_git_plugin(a:url, a:redraw, a:vimbundle_dir)
    let plug_name = matchstr(a:url, '[^/]\+\%(\.git\)\?$')
    let plug_dir = s:FS.join(a:vimbundle_dir, plug_name)
    let record = s:MetaInfo.update_record(
    \               a:url, a:vimbundle_dir, plug_dir, 1)
    call s:FS.lock_version(record, plug_name, plug_dir)
endfunction
call s:method('Vivacious', 'install_and_record')

function! s:Vivacious_cmd_install_help() abort dict
    echo ' '
    echo 'Usage: VivaInstall <source>'
    echo '       VivaInstall tyru/vivacious.vim'
    echo '       VivaInstall https://github.com/tyru/vivacious.vim'
endfunction
call s:method('Vivacious', 'cmd_install_help')

function! s:Vivacious_remove(args) abort dict
    if len(a:args) ==# 0 || a:args[0] =~# '^\%(-h\|--help\)$'
        return self.cmd_remove_help()
    endif
    if len(a:args) !=# 1 || a:args[0] !~# '^[^/\\]\+$'
        throw 'vivacious: VivaRemove: invalid argument.'
    endif
    call s:Vivacious.uninstall_plugin_wildcard(
    \       a:args[0], 1, s:MetaInfo.get_lockfile())
endfunction
call s:method('Vivacious', 'remove')

function! s:Vivacious_purge(args) abort dict
    if len(a:args) ==# 0 || a:args[0] =~# '^\%(-h\|--help\)$'
        return self.cmd_purge_help()
    endif
    if len(a:args) !=# 1 || a:args[0] !~# '^[^/\\]\+$'
        throw 'vivacious: VivaPurge: invalid argument.'
    endif
    call s:Vivacious.uninstall_plugin_wildcard(
    \           a:args[0], 0, s:MetaInfo.get_lockfile())
endfunction
call s:method('Vivacious', 'purge')

function! s:Vivacious_uninstall_plugin_wildcard(wildcard, keep_record, metafile) abort dict
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
        call s:Vivacious.uninstall_plugin(
        \       plug_name, a:keep_record, redraw, a:metafile)
    endfor
endfunction
call s:method('Vivacious', 'uninstall_plugin_wildcard')

function! s:Vivacious_uninstall_plugin(plug_name, keep_record, redraw, metafile) abort dict
    let vimbundle_dir = s:FS.vimbundle_dir()
    let plug_dir = s:FS.join(vimbundle_dir, a:plug_name)
    let exists_dir = isdirectory(plug_dir)
    let has_record = s:MetaInfo.has_record_name_of(a:plug_name, a:metafile)
    if !exists_dir && !has_record
        throw "vivacious: '" . a:plug_name . "' is not installed."
    endif
    " Remove the plugin info.
    if has_record && !a:keep_record
        let ver = s:FS.git({'work_tree': plug_dir,
        \                   'args': ['rev-parse', 'HEAD']})
        call s:MetaInfo.do_unrecord_by_name(a:plug_name, a:metafile)
        if !exists_dir && a:redraw
            redraw    " before the last message
        endif
        call s:Msg.info(printf(
        \       "Unrecorded the plugin info of '%s'.", a:plug_name))
    endif
    " Remove the plugin directory.
    if exists_dir
        call s:Msg.info_nohist(printf("Deleting the plugin directory '%s'...", a:plug_name))
        call s:FS.delete_dir(plug_dir)
        if a:redraw
            redraw    " before the last message
        endif
        call s:Msg.info(printf(
        \       "Deleting the plugin directory '%s'... Done.", a:plug_name))
    endif
endfunction
call s:method('Vivacious', 'uninstall_plugin')

function! s:Vivacious_cmd_remove_help() abort dict
    echo ' '
    echo 'Usage: VivaRemove <plugin name in bundle dir>'
    echo '       VivaRemove vivacious.vim'
    echo ' '
    echo ':VivaRemove removes only a plugin directory.'
    echo 'It keeps a plugin info.'
    echo 'After this command is executed, :VivaFetchAll can fetch a plugin directory again.'
endfunction
call s:method('Vivacious', 'cmd_remove_help')

function! s:Vivacious_cmd_purge_help() abort dict
    echo ' '
    echo 'Usage: VivaPurge <plugin name in bundle dir>'
    echo '       VivaPurge vivacious.vim'
    echo ' '
    echo ':VivaPurge removes both a plugin directory and a plugin info.'
    echo ':VivaFetchAll doesn''t help, all data about specified plugin are gone.'
endfunction
call s:method('Vivacious', 'cmd_purge_help')

function! s:Vivacious_list(args) abort dict
    let vimbundle_dir = s:FS.vimbundle_dir()
    let records = s:MetaInfo.get_records_from_file(s:MetaInfo.get_lockfile())
    if empty(records)
        echomsg 'No plugins are installed.'
        return
    endif
    for record in records
        let plug_dir = s:FS.join(vimbundle_dir, record.name)
        if isdirectory(plug_dir)
            echohl MoreMsg
            echomsg record.name
            echohl None
        else
            echohl WarningMsg
            echomsg record.name . " (not fetched)"
            echohl None
        endif
        echomsg "  Directory: " . record.path
        echomsg "  Type: " . record.type
        echomsg "  URL: " . record.url
        echomsg "  Version: " . record.version
    endfor
    echomsg ' '
    echomsg 'Listed managed plugins.'
endfunction
call s:method('Vivacious', 'list')

function! s:Vivacious_cmd_list_help() abort dict
    echo ' '
    echo 'Usage: VivaList'
    echo ' '
    echo 'Lists managed plugins including plugins which have been not fetched.'
endfunction
call s:method('Vivacious', 'cmd_list_help')

function! s:Vivacious_fetch_all(args) abort dict
    if len(a:args) >= 1 && a:args[0] =~# '^\%(-h\|--help\)$'
        return self.cmd_fetch_all_help()
    endif
    let metafile = (len(a:args) >= 1 ? expand(a:args[0]) : s:MetaInfo.get_lockfile())
    if metafile =~# s:HTTP_URL_RE
        let content = s:Vivacious.http_get(metafile)
        let metafile = tempname()
        call writefile(split(content, '\r\?\n', 1), metafile)
    endif
    try
        call s:Vivacious.fetch_all_from_metafile(metafile)
    finally
        if metafile =~# s:HTTP_URL_RE
            call delete(metafile)
        endif
    endtry
endfunction
call s:method('Vivacious', 'fetch_all')

function! s:Vivacious_fetch_all_from_metafile(metafile) abort dict
    if !filereadable(a:metafile)
        throw "vivacious: Specified metafile doesn't exist. "
        \   . '(' . a:metafile . ')'
    endif
    let vimbundle_dir = s:FS.vimbundle_dir()
    for record in s:MetaInfo.get_records_from_file(a:metafile)
        let plug_dir = record.path
        let vimbundle_dir = s:FS.dirname(plug_dir)
        let plug_name = s:FS.basename(plug_dir)
        try
            call s:FS.install_git_plugin(record.url, 0, vimbundle_dir)
            call s:MetaInfo.update_record(record.url, vimbundle_dir,
            \                             plug_dir, 0, record.version)
            call s:FS.lock_version(record, plug_name, plug_dir)
        catch /vivacious: You already installed/
            call s:Msg.info("You already installed '" . plug_name . "'.")
        endtry
    endfor
    call s:Msg.info('VivaFetchAll: All plugins are installed!')
endfunction
call s:method('Vivacious', 'fetch_all_from_metafile')

function! s:Vivacious_cmd_fetch_all_help() abort dict
    echo ' '
    echo 'Usage: VivaFetchAll [<Vivacious.lock>]'
    echo '       VivaFetchAll /path/to/Vivacious.lock'
    echo ' '
    echo 'If no arguments are given, ~/.vim/Vivacious.lock is used.'
endfunction
call s:method('Vivacious', 'cmd_fetch_all_help')

function! s:Vivacious_update(args) abort dict
    " Pre-check and build git update commands.
    let update_cmd_list = []
    for record in s:MetaInfo.get_records_from_file(s:MetaInfo.get_lockfile())
        let plug_dir = record.path
        if !isdirectory(plug_dir)
            call add(update_cmd_list,
            \   {'msg': printf("'%s' is not installed...skip.", record.name)})
        endif
        " If the branch is detached state,
        " See branch when git clone and recorded in Vivacious.lock.
        let branch = s:FS.git_current_branch(plug_dir)
        if branch =~# '^([^)]\+)$'
            call s:Msg.debug(printf('%s: detached state (%s)',
            \                       record.name, branch))
            if !has_key(record, 'branch')
            \   || !has_key(record, 'remote')
                throw 'vivacious: The repository is detached state '
                \   . 'but no tracking branch and upstream in Vivacious.lock'
            endif
            let branch = record.branch
            let remote = record.remote
            call add(update_cmd_list,
            \   {'name': record.name,
            \    'work_tree': plug_dir, 'args': ['pull', remote, branch]})

        " If the branch has a remote tracking branch, just git pull.
        elseif s:FS.git_upstream_of(branch, plug_dir) !~# '^\s*$'
            if g:vivacious#debug
                call s:Msg.debug(printf('%s: upstream is set (%s)',
                \   record.name, s:FS.git_upstream_of(branch, plug_dir)))
            endif
            call add(update_cmd_list,
            \   {'name': record.name,
            \    'work_tree': plug_dir, 'args': ['pull']})

        " If the branch does not have a remote tracking branch,
        " Shows an error.
        else
            call s:Msg.debug(printf(
            \   "%s: couldn't find a way to update plugin", record.name))
            throw printf("vivacious: couldn't find a way to "
            \          . "update plugin '%s'.", record.name)
        endif
    endfor
    " Update all plugins.
    for cmd in update_cmd_list
        if has_key(cmd, 'msg')
            call s:Msg.info(cmd.msg)
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
call s:method('Vivacious', 'update')

function! s:Vivacious_cmd_update_help() abort dict
    echo ' '
    echo 'Usage: VivaUpdate'
    echo ' '
    echo 'Updates all installed plugins.'
endfunction
call s:method('Vivacious', 'cmd_update_help')

function! s:Vivacious_http_get(url) abort dict
    if executable('curl')
        return system('curl -L -s -k ' . s:FS.shellescape(a:url))
    elseif executable('wget')
        return system('wget -q -L -O - ' . s:FS.shellescape(a:url))
    else
        throw 'vivacious: s:Vivacious.http_get(): '
        \   . 'you doesn''t have curl nor wget.'
    endif
endfunction
call s:method('Vivacious', 'http_get')


" ===================== s:MetaInfo =====================
" Functions to manipulate metafile.
" lockfile is one of metafile saved in `s:MetaInfo.get_lockfile()`.

function! vivacious#get_metainfo() abort
    return s:MetaInfo
endfunction

function! s:MetaInfo_get_lockfile() abort dict
    return s:FS.join(s:FS.vim_dir(), 'Vivacious.lock')
endfunction
call s:method('MetaInfo', 'get_lockfile')

" @return updated record
" @param init (Boolean)
"   non-zero (:VivaInstall)
"   * Bump version when the plugin is already recorded.
"   * Save current branch before locking version.
"   zero (:VivaFetchAll)
"   * Do not bump version when the plugin is already recorded.
function! s:MetaInfo_update_record(url, vimbundle_dir, plug_dir, init, ...) abort dict
    " Record or Lock
    let plug_name = s:FS.basename(a:plug_dir)
    let vim_lockfile = s:MetaInfo.get_lockfile()
    let old_record = s:MetaInfo.get_record_by_name(plug_name, vim_lockfile)
    if empty(old_record)
        " If the record is not found, record the plugin info.
        let dir = s:FS.join(s:FS.basename(a:vimbundle_dir), plug_name)
        let ver = (a:0 ? a:1 :
        \           s:FS.git({'work_tree': a:plug_dir,
        \                     'args': ['rev-parse', 'HEAD']}))
        let branch = s:FS.git_current_branch(a:plug_dir)
        let remote = s:FS.git_upstream_of(branch, a:plug_dir)
        let record = s:MetaInfo.make_record(plug_name, dir, a:url, 'git',
        \                                   ver, branch, remote)
        call s:MetaInfo.do_record(record, vim_lockfile)
        call s:Msg.info(printf("Recorded the plugin info of '%s'.", plug_name))
        return record
    elseif a:init
        " Bump version.
        call s:MetaInfo.do_unrecord_by_name(plug_name, vim_lockfile)
        let dir = s:FS.join(s:FS.basename(a:vimbundle_dir), plug_name)
        let ver = s:FS.git({'work_tree': a:plug_dir,
        \                   'args': ['rev-parse', 'HEAD']})
        let record = s:MetaInfo.make_record(
        \               plug_name, dir, a:url, 'git', ver,
        \               old_record.branch, old_record.remote)
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

function! s:MetaInfo_expand_plug_name(wildcard, metafile) abort dict
    if a:wildcard !~# '[*?]'
        return [a:wildcard]
    endif
    let records = s:MetaInfo.get_records_from_file(a:metafile)
    let candidates = map(records, 'v:val.name')
    " wildcard -> regexp
    let re = substitute(a:wildcard, '\*', '.*', 'g')
    let re = substitute(re, '?', '.', 'g')
    return filter(candidates, 'v:val =~# re')
endfunction
call s:method('MetaInfo', 'expand_plug_name')

function! s:MetaInfo_make_record(name, dir, url, type, version, branch, remote) abort dict
    return {'name': a:name, 'dir': a:dir, 'url': a:url,
    \       'type': a:type, 'version': a:version, 'branch': a:branch,
    \       'remote': a:remote}
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
    let re = '\<name:' . a:plug_name . '\>'
    let lines = filter(s:MetaInfo.readfile(a:metafile), 'v:val !~# re')
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
        throw 'vivacious: fatal: s:MetaInfo.readfile(): '
        \   . 'Vivacious.lock file is corrupted.'
    endif
    if result.version > s:LOCKFILE_VERSION
        throw 'vivacious: Too old vivacious.vim for parsing metafile. '
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
    \                's:MetaInfo.get_records_from_ltsv(v:val)')
    return filter(records, '!empty(v:val)')
endfunction
call s:method('MetaInfo', 'get_records_from_file')

function! s:MetaInfo_get_records_from_ltsv(line) abort dict
    let record = s:MetaInfo.parse_ltsv(a:line)
    if empty(record)
        return {}
    endif
    return extend(record, {"path": s:FS.abspath_record_dir(record.dir)})
endfunction
call s:method('MetaInfo', 'get_records_from_ltsv')

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
            throw 'vivacious: fatal: s:MetaInfo.parse_ltsv(): '
            \   . 'Vivacious.lock file is corrupted.'
        endif
        let dict[m[1]] = m[2]
    endfor
    " TODO: Validate keys/values?
    return dict
endfunction
call s:method('MetaInfo', 'parse_ltsv')


" ===================== s:FS =====================
" Functions about filesystem.

function! vivacious#get_filesystem() abort
    return s:FS
endfunction

function! s:FS_install_git_plugin(url, redraw, vimbundle_dir) abort dict
    let plug_name = matchstr(a:url, '[^/]\+\%(\.git\)\?$')
    if plug_name ==# ''
        throw 'vivacious: Invalid URL(' . a:url . ')'
    endif
    if !isdirectory(a:vimbundle_dir)
        call s:FS.mkdir_p(a:vimbundle_dir)
    endif
    let plug_dir = s:FS.join(a:vimbundle_dir, plug_name)
    if isdirectory(plug_dir)
        throw "vivacious: You already installed '" . plug_name . "'. "
        \   . "Please uninstall it by "
        \   . ":VivaRemove or :VivaPurge."
    endif
    " Fetch & Install
    call s:Msg.info_nohist(printf("Fetching a plugin from '%s'...", a:url))
    call s:FS.git('clone', a:url, plug_dir)
    if v:shell_error
        throw printf("vivacious: 'git clone %s %s' failed.", a:url, plug_dir)
    endif
    call s:Msg.info(printf("Fetching a plugin from '%s'... Done.", a:url))
    call s:FS.source_plugin(plug_dir)
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
        throw printf("vivacious: 'git checkout %s' failed.",
        \                               a:record.version)
    endif
    call s:Msg.info(printf("Locked the version of '%s' (%s).",
    \                   a:plug_name, a:record.version))
endfunction
call s:method('FS', 'lock_version')

function! s:FS_delete_dir(dir) abort dict
    if !isdirectory(a:dir)
        throw 'vivacious: fatal: s:FS.delete_dir(): '
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
      throw 'vivacious: fatal: s:FS.delete_dir_impl(): '
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
        throw "vivacious: fatal: 'git' is not installed in your PATH."
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
        throw "vivacious: fatal: Could not find current branch "
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

function! s:FS_vim_dir() abort dict
    if exists('$HOME')
        let home = $HOME
    elseif exists('$HOMEDRIVE') && exists('$HOMEPATH')
        let home = $HOMEDRIVE . $HOMEPATH
    else
        throw 'vivacious: fatal: Could not find home directory.'
    endif
    if isdirectory(s:FS.join(home, '.vim'))
        return s:FS.join(home, '.vim')
    elseif isdirectory(s:FS.join(home, 'vimfiles'))
        return s:FS.join(home, 'vimfiles')
    else
        throw 'vivacious: Could not find .vim directory.'
    endif
endfunction
call s:method('FS', 'vim_dir')

function! s:FS_vimbundle_dir() abort dict
    return s:FS.join(s:FS.vim_dir(), 'bundle')
endfunction
call s:method('FS', 'vimbundle_dir')

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

function! vivacious#get_msg() abort
    return s:Msg
endfunction

" TODO: More better highlight.
function! s:Msg_info_nohist(msg, ...) abort dict
    execute 'echohl' (a:0 ? a:1 : 'MoreMsg')
    if g:vivacious#debug
        echomsg 'vivacious:' a:msg
    else
        echo 'vivacious:' a:msg
    endif
    echohl None
endfunction
call s:method('Msg', 'info_nohist')

" TODO: More better highlight.
function! s:Msg_info(msg, ...) abort dict
    execute 'echohl' (a:0 ? a:1 : 'MoreMsg')
    echomsg 'vivacious:' a:msg
    echohl None
endfunction
call s:method('Msg', 'info')

function! s:Msg_error(msg, ...) abort dict
    execute 'echohl' (a:0 ? a:1 : 'ErrorMsg')
    echomsg 'vivacious:' a:msg
    echohl None
endfunction
call s:method('Msg', 'error')

function! s:Msg_debug(msg, ...) abort dict
    if !g:vivacious#debug | return | endif
    execute 'echohl' (a:0 ? a:1 : 'WarningMsg')
    echomsg 'vivacious(DEBUG):' a:msg
    echohl None
endfunction
call s:method('Msg', 'debug')


let &cpo = s:save_cpo
unlet s:save_cpo
" vim:set et:
