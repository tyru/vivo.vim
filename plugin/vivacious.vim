scriptencoding utf-8

if exists('g:loaded_vivacious')
  finish
endif
let g:loaded_vivacious = 1

let s:save_cpo = &cpo
set cpo&vim

if !executable('git')
    echohl ErrorMsg
    echomsg "vivacious: 'git' is not installed in your PATH."
    echohl None
endif

command! -bar -nargs=*
\   VivaciousInstall call vivacious#install(<f-args>)
command! -bar -nargs=*
\   -complete=customlist,vivacious#__complete_remove__
\   VivaciousRemove call vivacious#remove(<f-args>)
command! -bar -nargs=*
\   -complete=customlist,vivacious#__complete_remove__
\   VivaciousPurge call vivacious#purge(<f-args>)
command! -bar -nargs=*
\   VivaciousList call vivacious#list(<f-args>)
command! -bar -nargs=*
\   -complete=file
\   VivaciousFetchAll call vivacious#fetch_all(<f-args>)
command! -bar -nargs=*
\   VivaciousUpdate call vivacious#update(<f-args>)

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et:
