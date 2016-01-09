scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


let s:<PLUGNAME> = vivacious#bundleconfig#new()

" Configuration for <PLUGNAME>.
function! s:<PLUGNAME>.config()
endfunction

" Plugin dependencies for <PLUGNAME>.
function! s:<PLUGNAME>.depends()
    return []
endfunction

" Recommended plugin dependencies for <PLUGNAME>.
" If the plugins are not installed, vivacious shows recommended plugins.
function! s:<PLUGNAME>.recommends()
    return []
endfunction

" External commands dependencies for <PLUGNAME>.
" (e.g.: curl)
function! s:<PLUGNAME>.depends_commands()
    return []
endfunction

" Recommended external commands dependencies for <PLUGNAME>.
" If the plugins are not installed, vivacious shows recommended commands.
function! s:<PLUGNAME>.recommends_commands()
    return []
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
