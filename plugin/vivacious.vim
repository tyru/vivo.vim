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
\   VivaInstall call vivacious#install([<f-args>])
command! -bar -nargs=*
\   VivaUninstall call vivacious#uninstall([<f-args>])

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et:
