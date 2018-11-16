command! -nargs=+ -buffer -complete=customlist,goadapt#complete GoAdapt call goadapt#do(<f-args>)
command! -nargs=+ -buffer -complete=customlist,goadapt#complete Adapt  GoAdapt <args>
