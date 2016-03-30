scriptencoding utf-8

if exists('g:loaded_vivo')
  finish
endif
let g:loaded_vivo = 1

let s:save_cpo = &cpo
set cpo&vim

if !executable('git')
    echohl ErrorMsg
    echomsg "vivo: 'git' is not installed in your PATH."
    echohl None
    finish
endif

command! -bar -nargs=+
\   -complete=customlist,vivo#plugconf#complete_edit_plugconf
\   VivoEditPlugConf
\   call vivo#plugconf#edit_plugconf(<f-args>)

command! -bar -nargs=*
\   -complete=customlist,vivo#__complete_install__
\   VivoInstall call vivo#install(<f-args>)
command! -bar -nargs=*
\   -complete=customlist,vivo#__complete_plug_name__
\   VivoRemove call vivo#remove(<f-args>)
command! -bar -nargs=*
\   -complete=customlist,vivo#__complete_plug_name__
\   VivoPurge call vivo#purge(<f-args>)
command! -bar -nargs=*
\   VivoList call vivo#list(<f-args>)
command! -bar -nargs=*
\   -complete=file
\   VivoFetchAll call vivo#fetch_all(<f-args>)
command! -bar -nargs=*
\   -complete=customlist,vivo#__complete_plug_name__
\   VivoUpdate call vivo#update(<f-args>)
command! -bar -nargs=*
\   -complete=file
\   VivoManage call vivo#manage(<f-args>)
command! -bar -nargs=*
\   -complete=customlist,vivo#__complete_plug_name__
\   VivoEnable call vivo#enable(<f-args>)
command! -bar -nargs=*
\   -complete=customlist,vivo#__complete_plug_name__
\   VivoDisable call vivo#disable(<f-args>)

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et:
