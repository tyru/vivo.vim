scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


let g:vivacious#bundleconfig#open_cmd =
\       get(g:, 'vivacious#bundleconfig#open_cmd', 'vsplit')

" Load dependencies.
let s:Msg = vivacious#get_msg()
let s:FS = vivacious#get_filesystem()


" for vivacious#bundleconfig#new(),
" s:bundleconfig and s:loading_bundleconfig cannot be local variables.
let s:bundleconfig = {}
let s:loading_bundleconfig = {}
let s:loaded = 0


function! vivacious#bundleconfig#load(...) abort
    if s:loaded
        return
    endif

    for plug_dir in map(split(&rtp, ','), 'expand(v:val)')
        if isdirectory(plug_dir)
            let name = s:get_no_suffix_name(plug_dir)
            if name !=# ''
                let s:bundleconfig[name] = {
                \   "name": name, "path": plug_dir,
                \   "done": 0, "disabled": 0, "user": {},
                \}
            endif
        endif
    endfor
    call s:load_all_bundleconfig()

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
    execute g:vivacious#bundleconfig#open_cmd filename
    " If a buffer is empty, load template content.
    if line('$') ==# 1 && getline(1) ==# ''
        let template = s:FS.globpath(
        \                   &rtp, 'macros/bundleconfig_template.vim')[0]
        silent read `=template`
        silent 1 delete _
        let plugname = fnamemodify(filename, ':t:r')
        let plugvarname = substitute(plugname, '\W', '', 'g')
        let plugvarname = substitute(plugvarname, '^[0-9]\+', '', 'g')
        silent %s/<PLUGNAME>/\=plugname/ige
        silent %s/<PLUGVARNAME>/\=plugvarname/ige
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


function! s:load_all_bundleconfig()
    for bcconf in values(s:bundleconfig)
        call s:do_source(bcconf)
    endfor
    " Load in order?
    for name in keys(s:bundleconfig)
        let bcconf = s:bundleconfig[name]
        if bcconf.done
            continue
        endif
        call s:load_bundleconfig(bcconf)
    endfor
endfunction

function! s:do_source(bcconf)
    let s:loading_bundleconfig = a:bcconf
    try
        execute 'runtime! bundleconfig/' . a:bcconf.name . '/**/*.vim'
        execute 'runtime! bundleconfig/' . a:bcconf.name . '.vim'

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

function! s:load_bundleconfig(bcconf)
    if a:bcconf.disabled
        return 0
    endif
    try
        if has_key(a:bcconf.user, 'depends')
            let depfail = []
            let depends = a:bcconf.user.depends()
            for depname in type(depends) is type([]) ? depends : [depends]
                if !has_key(s:bundleconfig, depname) ||
                \   !s:load_bundleconfig(s:bundleconfig[depname])
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


let &cpo = s:save_cpo
unlet s:save_cpo
" vim:set et:
