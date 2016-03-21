scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


let g:vivo#plugconf#open_cmd =
\       get(g:, 'vivo#plugconf#open_cmd', 'vsplit')

" Load dependencies.
let s:Msg = vivo#get_msg()
let s:FS = vivo#get_filesystem()


" for vivo#plugconf#new(),
" s:plugconf and s:loading_plugconf cannot be local variables.
let s:plugconf = {}
let s:loading_plugconf = {}
let s:loaded = 0
let s:FS = vivo#get_fs()

function! vivo#plugconf#load(...) abort
    if s:loaded
        return
    endif

    for plug_dir in map(split(&rtp, ','), 'expand(v:val)')
        if isdirectory(plug_dir)
            let name = s:get_no_suffix_name(plug_dir)
            if name !=# ''
                let s:plugconf[name] = {
                \   "name": name, "path": plug_dir,
                \   "done": 0, "disabled": 0, "user": {},
                \}
            endif
        endif
    endfor
    call s:load_all_plugconf()

    unlet s:plugconf
    unlet s:loading_plugconf
    let s:loaded = 1
endfunction

function! vivo#plugconf#new()
    if empty(s:loading_plugconf)
        call s:Msg.error("Please use vivo#plugconf#new() in plugconf file!")
        return {}
    endif
    let name = s:loading_plugconf.name
    let s:plugconf[name].user = deepcopy(s:BundleUserConfig)
    return s:plugconf[name].user
endfunction

function! vivo#plugconf#edit_plugconf(name, ...)
    let filename = s:FS.join(
    \   s:FS.plugconf_dir(),
    \   a:name . (a:name !~? '\.vim$' ? '.vim' : '')
    \)
    execute g:vivo#plugconf#open_cmd filename
    " If a buffer is empty, load template content.
    if line('$') ==# 1 && getline(1) ==# ''
        let template = s:FS.globpath(
        \   &rtp, 'macros/plugconf_template.vim'
        \)[0]
        silent read `=template`
        silent 1 delete _
        let plugname = fnamemodify(filename, ':t:r')
        let plugvarname = substitute(plugname, '\W', '', 'g')
        let plugvarname = substitute(plugvarname, '^[0-9]\+', '', 'g')
        silent %s/<PLUGNAME>/\=plugname/ige
        silent %s/<PLUGVARNAME>/\=plugvarname/ige
    endif
endfunction

function! vivo#plugconf#complete_edit_plugconf(arglead, ...)
    let dirs = s:FS.glob(s:FS.plugconf_dir() . '/*')
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


function! s:load_all_plugconf()
    for bcconf in values(s:plugconf)
        call s:do_source(bcconf)
    endfor
    " Load in order?
    for name in keys(s:plugconf)
        let bcconf = s:plugconf[name]
        if bcconf.done
            continue
        endif
        call s:load_plugconf(bcconf)
    endfor
endfunction

function! s:do_source(bcconf)
    let s:loading_plugconf = a:bcconf
    try
        execute 'runtime! vivo/plugconf/' . a:bcconf.name . '/**/*.vim'
        execute 'runtime! vivo/plugconf/' . a:bcconf.name . '.vim'

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
                    call s:Msg.error("[plugconf] " .
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
        let s:loading_plugconf = {}
    endtry
endfunction

function! s:load_plugconf(bcconf)
    if a:bcconf.disabled
        return 0
    endif
    try
        if has_key(a:bcconf.user, 'depends')
            let depfail = []
            let depends = a:bcconf.user.depends()
            for depname in type(depends) is type([]) ? depends : [depends]
                if !has_key(s:plugconf, depname) ||
                \   !s:load_plugconf(s:plugconf[depname])
                    let depfail += [depname]
                endif
            endfor
            if !empty(depfail)
                call s:Msg.error("Stop loading '" . a:bcconf.name . "' " .
                \                "because cannot fulfilling requirements " .
                \                "[" . join(depfail, ', ') . "]")
                return 0
            endif
        endif
        if has_key(a:bcconf.user, 'config')
            let s:loading_plugconf = a:bcconf
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
        let s:loading_plugconf = {}
    endtry
    let a:bcconf.done = 1
    return 1
endfunction

function! s:get_no_suffix_name(path)
    let nosufname = substitute(a:path, '.*[/\\]', '', '')
    let nosufname = substitute(nosufname, '\c[.-]vim$', '', '')
    let nosufname = substitute(nosufname, '\c^vim[.-]', '', '')
    return nosufname
endfunction


" See macros/plugconf_template.vim for each function.
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


let &cpo = s:save_cpo
unlet s:save_cpo
" vim:set et:
