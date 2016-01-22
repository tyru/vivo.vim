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
    finish
endif

command! -bar -nargs=+
\   -complete=customlist,vivacious#bundleconfig#complete_edit_bundleconfig
\   VivaciousEditBundleConfig
\   call vivacious#bundleconfig#edit_bundleconfig(<f-args>)

command! -bar -nargs=*
\   VivaciousInstall call vivacious#install(<f-args>)
command! -bar -nargs=*
\   -complete=customlist,vivacious#__complete_plug_name__
\   VivaciousRemove call vivacious#remove(<f-args>)
command! -bar -nargs=*
\   -complete=customlist,vivacious#__complete_plug_name__
\   VivaciousPurge call vivacious#purge(<f-args>)
command! -bar -nargs=*
\   VivaciousList call vivacious#list(<f-args>)
command! -bar -nargs=*
\   -complete=file
\   VivaciousFetchAll call vivacious#fetch_all(<f-args>)
command! -bar -nargs=*
\   VivaciousUpdate call vivacious#update(<f-args>)
command! -bar -nargs=*
\   -complete=file
\   VivaciousManage call vivacious#manage(<f-args>)
command! -bar -nargs=*
\   -complete=customlist,vivacious#__complete_plug_name__
\   VivaciousEnable call vivacious#enable(<f-args>)
command! -bar -nargs=*
\   -complete=customlist,vivacious#__complete_plug_name__
\   VivaciousDisable call vivacious#disable(<f-args>)

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et:
