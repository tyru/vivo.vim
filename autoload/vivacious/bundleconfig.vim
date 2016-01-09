scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim


" Load dependencies.
let s:MetaInfo = vivacious#get_metainfo()
let s:Msg = vivacious#get_msg()
let s:FS = vivacious#get_filesystem()


let s:bundleconfig = {}
let s:loading_bundleconfig = {}
let s:loaded = 0


function! vivacious#bundleconfig#load(...) abort
    if s:loaded
        return
    endif

    let lockfile = s:MetaInfo.get_lockfile()
    for record in s:MetaInfo.get_records_from_file(lockfile)
        let name = s:get_no_suffix_name(record.path)
        let s:bundleconfig[name] = {
        \   "name": name,
        \   "path": record.path,
        \   "done": 0, "disabled": 0, "user": {},
        \}
    endfor
    call s:bc_load()

    unlet s:bundleconfig
    unlet s:loading_bundleconfig
    let s:loaded = 1
endfunction

function! vivacious#bundleconfig#new()
    if empty(s:loading_bundleconfig)
        call s:Msg.error("Please use vivacious#bundleconfig#new() in bundleconfig file!")
        return {}
    endif
    let name = s:loading_bundleconfig.name
    let s:bundleconfig[name].user = deepcopy(s:BundleUserConfig)
    return s:bundleconfig[name].user
endfunction

function! vivacious#bundleconfig#edit_bundleconfig(name, ...)
    let filename = expand(
    \   '$MYVIMDIR/bundleconfig/' . a:name
    \   . (a:name !~? '\.vim$' ? '.vim' : ''))
    drop `=filename`
    " If a buffer is empty, load template content.
    if line('$') ==# 1 && getline(1) ==# ''
        let template = s:FS.globpath(
        \                   &rtp, 'macros/bundleconfig_template.vim')[0]
        silent read `=template`
        silent 1 delete _
        let plugname = fnamemodify(filename, ':t:r')
        silent %s/<PLUGNAME>/\=plugname/ige
    endif
endfunction

function! vivacious#bundleconfig#complete_edit_bundleconfig(arglead, _l, _p)
    let dirs = glob('$MYVIMDIR/bundleconfig/*', 1, 1)
    call map(dirs, 'substitute(v:val, ".*[/\\\\]", "", "")')
    if a:arglead !=# ''
        " wildcard -> regexp pattern
        let pattern = '^' . a:arglead
        let pattern = substitute(pattern, '\*', '.*', 'g')
        let pattern = substitute(pattern, '\\?', '.', 'g')
        call filter(dirs, 'v:val =~# pattern')
    endif
    return dirs
endfunction



" let s:plugins = rtputil#new()
" call s:plugins.reset()

function! s:cmd_load_plugin(args, now)
    for path in a:args
        if !isdirectory(expand(path))
            call s:Msg.error(path . ": no such a bundle directory")
            return
        endif
        let nosufname = s:get_no_suffix_name(path)
        let bcconf = {
        \   'path': path, 'name': nosufname,
        \   'done': 0, 'disabled': 0,
        \   'user': {},
        \}
        " To load $MYVIMDIR/bundleconfig/<name>.vim
        let s:bundleconfig[nosufname] = bcconf
        if a:now
            " Change 'runtimepath' immediately.
            call rtputil#append(path)
        else
            " Change 'runtimepath' later.
            " call s:plugins.append(path)
        endif
    endfor
endfunction

function! s:cmd_disable_plugin(args)
    let pattern = a:args[0]
    let nosufname = s:get_no_suffix_name(pattern)
    " To load $MYVIMDIR/bundleconfig/<name>.vim
    if has_key(s:bundleconfig, nosufname)
        unlet s:bundleconfig[nosufname]
    endif
    " Change 'runtimepath' later.
    " call s:plugins.remove('\<' . pattern . '\>')
endfunction

function! s:get_no_suffix_name(path)
    let nosufname = substitute(a:path, '.*[/\\]', '', '')
    let nosufname = substitute(nosufname, '\c[.-]vim$', '', '')
    let nosufname = substitute(nosufname, '\c^vim[.-]', '', '')
    return nosufname
endfunction



" See macros/bundleconfig_template.vim for each function.
let s:BundleUserConfig = {}

function! s:BundleUserConfig.config()
endfunction

function! s:BundleUserConfig.depends()
    return []
endfunction

function! s:BundleUserConfig.recommends()
    return []
endfunction

function! s:BundleUserConfig.depends_commands()
    return []
endfunction

function! s:BundleUserConfig.recommends_commands()
    return []
endfunction



function! s:bc_load()
    for bcconf in values(s:bundleconfig)
        call s:bc_do_source(bcconf)
    endfor
    " Load in order?
    for name in keys(s:bundleconfig)
        let bcconf = s:bundleconfig[name]
        if bcconf.done
            continue
        endif
        call s:bc_do_load(bcconf)
    endfor
endfunction

function! s:bc_do_source(bcconf)
    let s:loading_bundleconfig = a:bcconf
    try
        execute 'runtime! bundleconfig/' . a:bcconf.name . '/**/*.vim'
        execute 'runtime! bundleconfig/' . a:bcconf.name . '*.vim'

        if has_key(a:bcconf.user, 'enable_if')
            let a:bcconf.disabled = !a:bcconf.user.enable_if()
        endif
        if has_key(a:bcconf.user, 'disable_if')
            let a:bcconf.disabled = a:bcconf.user.disable_if()
        endif
        if has_key(a:bcconf.user, 'depends_commands')
            let commands = a:bcconf.user.depends_commands()
            for cmd in type(commands) is type([]) ?
            \               commands : [commands]
                if !executable(cmd)
                    call s:Msg.error("[bundleconfig] " .
                    \   "'" . a:bcconf.name . "' requires " .
                    \   "'" . cmd . "' command but not in your PATH!")
                    let a:bcconf.disabled = 1
                    continue
                endif
            endfor
        endif
    catch
        call s:Msg.error('--- Sourcing ' . a:bcconf.path . ' ... ---')
        for msg in split(v:exception, '\n')
            call s:Msg.error(msg)
        endfor
        for msg in split(v:throwpoint, '\n')
            call s:Msg.error(msg)
        endfor
        call s:Msg.error('--- Sourcing ' . a:bcconf.path . ' ... ---')
    finally
        let s:loading_bundleconfig = {}
    endtry
endfunction

function! s:bc_do_load(bcconf)
    if a:bcconf.disabled
        return 0
    endif
    try
        if has_key(a:bcconf.user, 'depends')
            let depfail = []
            let depends = a:bcconf.user.depends()
            for depname in type(depends) is type([]) ? depends : [depends]
                if !s:bc_do_load(s:bundleconfig[depname])
                    let depfail += [depname]
                endif
            endfor
            if !empty(depfail)
                call s:Msg.error("Stop loading '" . a:bcconf.name . "' " .
                \                "due to load failed/disabled depending " .
                \                "plugin(s) [" . join(depfail, ', ') . "]")
                return 0
            endif
        endif
        if has_key(a:bcconf.user, 'config')
            let s:loading_bundleconfig = a:bcconf
            call a:bcconf.user.config()
        endif
    catch
        call s:Msg.error('--- Loading ' . a:bcconf.path . ' ... ---')
        for msg in split(v:exception, '\n')
            call s:Msg.error(msg)
        endfor
        for msg in split(v:throwpoint, '\n')
            call s:Msg.error(msg)
        endfor
        call s:Msg.error('--- Loading ' . a:bcconf.path . ' ... ---')
        return 0
    finally
        let s:loading_bundleconfig = {}
    endtry
    let a:bcconf.done = 1
    return 1
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et:
