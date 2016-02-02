scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


let s:<PLUGVARNAME> = vivo#bundleconfig#new()

" Configuration for <PLUGNAME>.
function! s:<PLUGVARNAME>.config()
endfunction

" Plugin dependencies for <PLUGNAME>.
function! s:<PLUGVARNAME>.depends()
    return []
endfunction

" Recommended plugin dependencies for <PLUGNAME>.
" If the plugins are not installed, vivo shows recommended plugins.
function! s:<PLUGVARNAME>.recommends()
    return []
endfunction

" External commands dependencies for <PLUGNAME>.
" (e.g.: curl)
function! s:<PLUGVARNAME>.depends_commands()
    return []
endfunction

" Recommended external commands dependencies for <PLUGNAME>.
" If the plugins are not installed, vivo shows recommended commands.
function! s:<PLUGVARNAME>.recommends_commands()
    return []
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
