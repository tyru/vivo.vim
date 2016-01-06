scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim


let g:vivacious#debug = get(g:, 'vivacious#debug', 0)


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
    if a:cmdline !~# '^[A-Z]\w*\s\+.\+$'    " no args
        return map(s:get_records_from_file(s:get_lockfile()), 'v:val.name')
    elseif a:arglead !=# ''    " has arguments
        if a:arglead =~# '[*?]'    " it has wildcard characters
            return s:expand_plug_name(a:arglead, s:get_lockfile())
        endif
        " match by prefix
        let candidates = map(s:get_records_from_file(s:get_lockfile()),
        \                    'v:val.name')
        call filter(candidates, 'v:val =~# "^" . a:arglead')
        return candidates
    endif
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

function! vivacious#update(...) abort
    call s:call_with_error_handlers('s:update', a:000,
    \                               's:cmd_update_help')
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
        let url = a:args[0]
        call s:install_git_plugin(url, 1, s:vimbundle_dir())
        let plug_name = matchstr(url, '[^/]\+\%(\.git\)\?$')
        let plug_dir = s:path_join(s:vimbundle_dir(),
        \                          s:path_basename(url))
        let record = s:update_record(url, s:vimbundle_dir(), plug_dir, 1)
        call s:lock_version(record, plug_name, plug_dir)
    else
        throw 'vivacious: VivaInstall: invalid arguments.'
    endif
endfunction

" @param arg 'tyru/vivacious.vim'
function! s:install_github_plugin(arg) abort
    let url = 'https://github.com/' . a:arg
    call s:install_git_plugin(url, 1, s:vimbundle_dir())
    let plug_name = s:path_basename(a:arg)
    let plug_dir  = s:path_join(s:vimbundle_dir(), plug_name)
    let record = s:update_record(url, s:vimbundle_dir(), plug_dir, 1)
    call s:lock_version(record, plug_name, plug_dir)
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

" @return updated record
" @param init (Boolean)
"   non-zero (:VivaInstall)
"   * Bump version when the plugin is already recorded.
"   * Save current branch before locking version.
"   zero (:VivaFetchAll)
"   * Do not bump version when the plugin is already recorded.
function! s:update_record(url, vimbundle_dir, plug_dir, init, ...) abort
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
        let branch = s:git_current_branch(a:plug_dir)
        let remote = s:git_upstream_of(branch, a:plug_dir)
        let record = s:make_record(plug_name, dir, a:url, 'git',
        \                          ver, branch, remote)
        call s:do_record(record, vim_lockfile)
        call s:info_msg(printf("Recorded the plugin info of '%s'.", plug_name))
        return record
    elseif a:init
        " Bump version.
        call s:do_unrecord_by_name(plug_name, vim_lockfile)
        let dir = s:path_join(s:path_basename(a:vimbundle_dir), plug_name)
        let ver = s:git({'work_tree': a:plug_dir,
        \                'args': ['rev-parse', 'HEAD']})
        let record = s:make_record(plug_name, dir, a:url, 'git',
        \               ver, old_record.branch, old_record.remote)
        call s:do_record(record, vim_lockfile)
        if old_record.version ==# record.version
            call s:info_msg(printf("The version of '%s' was unchanged (%s).",
            \                       plug_name, record.version))
        else
            call s:info_msg(printf("Updated the version of '%s' (%s -> %s).",
            \               plug_name, old_record.version, record.version))
        endif
        return record
    else
        return old_record
    endif
endfunction

function! s:lock_version(record, plug_name, plug_dir) abort
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
    try
        call s:fetch_all_from_lockfile(lockfile)
    finally
        if lockfile =~# s:HTTP_URL_RE
            call delete(lockfile)
        endif
    endtry
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
            let plug_name = s:path_basename(plug_dir)
            call s:update_record(record.url, vimbundle_dir,
            \                    plug_dir, 0, record.version)
            call s:lock_version(record, plug_name, plug_dir)
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

function! s:update(args) abort
    " Pre-check and build git update commands.
    let update_cmd_list = []
    for record in s:get_records_from_file(s:get_lockfile())
        let plug_dir = s:abspath_record_dir(record.dir)
        if !isdirectory(plug_dir)
            call add(update_cmd_list,
            \   {'msg': printf("'%s' is not installed...skip.", record.name)})
        endif
        " If the branch is detached state,
        " See branch when git clone and recorded in Vivacious.lock.
        let branch = s:git_current_branch(plug_dir)
        if branch =~# '^([^)]\+)$'
            call s:debug_msg(printf('%s: detached state (%s)',
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
        elseif s:git_upstream_of(branch, plug_dir) !~# '^\s*$'
            if g:vivacious#debug
                call s:debug_msg(printf('%s: upstream is set (%s)',
                \   record.name, s:git_upstream_of(branch, plug_dir)))
            endif
            call add(update_cmd_list,
            \   {'name': record.name,
            \    'work_tree': plug_dir, 'args': ['pull']})

        " If the branch does not have a remote tracking branch,
        " Shows an error.
        else
            call s:debug_msg(printf(
            \   "%s: couldn't find a way to update plugin", record.name))
            throw printf("vivacious: couldn't find a way to "
            \          . "update plugin '%s'.", record.name)
        endif
    endfor
    " Update all plugins.
    for cmd in update_cmd_list
        if has_key(cmd, 'msg')
            call s:info_msg(cmd.msg)
        else
            let name = remove(cmd, 'name')
            call s:info(printf('%s: Updating...', name), 'Normal')
            let oldver = s:git({'work_tree': cmd.work_tree,
            \                   'args': ['rev-parse', '--short', 'HEAD']})
            let start = reltime()
            call s:git(cmd)
            let time  = str2float(reltimestr(reltime(start)))
            let ver = s:git({'work_tree': cmd.work_tree,
            \                'args': ['rev-parse', '--short', 'HEAD']})
            if oldver !=# ver
                call s:info_msg(printf('%s: Updated (%.1fs, %s -> %s)',
                \                       name, time, oldver, ver))
            else
                call s:info_msg(printf('%s: Unchanged (%.1fs, %s)',
                \                       name, time, ver), 'Normal')
            endif
        endif
    endfor
    call s:info_msg(' ')
    call s:info_msg('Updated all plugins!')
endfunction

function! s:cmd_update_help() abort
    echo ' '
    echo 'Usage: VivaUpdate'
    echo ' '
    echo 'Updates all installed plugins.'
endfunction

function! s:http_get(url) abort
    if executable('curl')
        return system('curl -L -s -k ' . s:shellescape(a:url))
    elseif executable('wget')
        return system('wget -q -L -O - ' . s:shellescape(a:url))
    else
        throw 'vivacious: s:http_get(): '
        \   . 'you doesn''t have curl nor wget.'
    endif
endfunction

function! s:make_record(name, dir, url, type, version, branch, remote) abort
    return {'name': a:name, 'dir': a:dir, 'url': a:url,
    \       'type': a:type, 'version': a:version, 'branch': a:branch,
    \       'remote': a:remote}
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
    let [ver; lines] = readfile(a:lockfile)
    let result = s:parse_ltsv(ver)
    if !has_key(result, 'version')
        throw 'vivacious: fatal: s:read_lockfile(): '
        \   . 'Vivacious.lock file is corrupted.'
    endif
    if result.version > s:LOCKFILE_VERSION
        throw 'vivacious: Too old vivacious.vim for parsing lockfile. '
        \   . 'Please update the plugin.'
    endif
    return filter(lines, '!empty(v:val)')
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
    let ret = system(cmd . ' ' . s:shellescape(a:path))
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
      let ret = system(cmd . ' ' . s:shellescape(a:path))
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

function! s:shellescape(str) abort
    let quote = (&shellxquote ==# '"' ? "'" : '"')
    return quote . a:str . quote
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

function! s:git_current_branch(work_tree) abort
    let lines = split(s:git({'args': ['branch'],
    \                        'work_tree': a:work_tree}), '\n')
    let re = '^\* '
    call filter(lines, 'v:val =~# re')
    if empty(lines)
        throw "vivacious: fatal: Could not find current branch "
        \   . "from 'git branch' output."
    endif
    return substitute(lines[0], re, '', '')
endfunction

" Get an upstream of remote tracking branch 'a:branch'.
function! s:git_upstream_of(branch, work_tree) abort
    let config = 'branch.' . a:branch . '.remote'
    return s:git({'args': ['config', '--get', config],
    \                   'work_tree': a:work_tree})
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

" TODO: More better highlight.
function! s:info(msg, ...) abort
    execute 'echohl' (a:0 ? a:1 : 'MoreMsg')
    echo 'vivacious:' a:msg
    echohl None
endfunction

" TODO: More better highlight.
function! s:info_msg(msg, ...) abort
    execute 'echohl' (a:0 ? a:1 : 'MoreMsg')
    echomsg 'vivacious:' a:msg
    echohl None
endfunction

function! s:error(msg, ...) abort
    execute 'echohl' (a:0 ? a:1 : 'ErrorMsg')
    echomsg 'vivacious:' a:msg
    echohl None
endfunction

function! s:debug_msg(msg, ...) abort
    if !g:vivacious#debug | return | endif
    execute 'echohl' (a:0 ? a:1 : 'WarningMsg')
    echomsg 'vivacious(DEBUG):' a:msg
    echohl None
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et:
