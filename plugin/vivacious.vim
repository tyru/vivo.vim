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
\   VivaInstall call vivacious#install(<f-args>)
command! -bar -nargs=*
\   -complete=customlist,vivacious#__complete_remove__
\   VivaRemove call vivacious#remove(<f-args>)
command! -bar -nargs=*
\   -complete=customlist,vivacious#__complete_remove__
\   VivaPurge call vivacious#purge(<f-args>)
command! -bar -nargs=*
\   VivaList call vivacious#list(<f-args>)
command! -bar -nargs=*
\   -complete=file
\   VivaFetchAll call vivacious#fetch_all(<f-args>)
command! -bar -nargs=*
\   VivaUpdate call vivacious#update(<f-args>)

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et:
