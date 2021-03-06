let s:save_cpo = &cpo
set cpo&vim

let g:goadapt#gocmd = get(g:, 'goadapt#gocmd', 'go')
let g:goadapt#cmd = get(g:, 'goadapt#cmd', 'adapt')
let g:goadapt#godoccmd = get(g:, 'goadapt#godoccmd', 'godoc')

function! s:bin_path()
    " check if our global custom path is set, if not check if $GOBIN is set so
    " we can use it, otherwise use $GOPATH + '/bin'
    if exists("g:go_bin_path")
        return g:go_bin_path
    elseif !empty($GOBIN)
        return $GOBIN
    elseif !empty($GOPATH)
        return $GOPATH . '/bin'
    endif

    return ''
endfunction

function! s:check_bin_path(binpath)
    let binpath = a:binpath
    if executable(binpath)
        return binpath
    endif

    " just get the basename
    let basename = fnamemodify(binpath, ":t")

    " check if we have an appropriate bin_path
    let go_bin_path = s:bin_path()
    if empty(go_bin_path)
        return ''
    endif

    let new_binpath = go_bin_path . '/' . basename
    if !executable(new_binpath)
        return ''
    endif

    return new_binpath
endfunction


function! s:error(msg)
    echohl ErrorMsg | echomsg a:msg | echohl None
endfunction

function! s:has_vimproc()
    if !exists('s:exists_vimproc')
        try
            silent call vimproc#version()
            let s:exists_vimproc = 1
        catch
            let s:exists_vimproc = 0
        endtry
    endif
    return s:exists_vimproc
endfunction

function! s:system(str, ...)
    let command = a:str
    let input = a:0 >= 1 ? a:1 : ''

    if a:0 == 0
        let output = s:has_vimproc() ?
                    \ vimproc#system(command) : system(command)
    elseif a:0 == 1
        let output = s:has_vimproc() ?
                    \ vimproc#system(command, input) : system(command, input)
    else
        " ignores 3rd argument unless you have vimproc.
        let output = s:has_vimproc() ?
                    \ vimproc#system(command, input, a:2) : system(command, input)
    endif

    return output
endfunction

function! s:shell_error()
    return s:has_vimproc() ? vimproc#get_last_status() : v:shell_error
endfunction

function! s:chomp(str)
    return a:str[len(a:str)-1] ==# "\n" ? a:str[:len(a:str)-2] : a:str
endfunction

function! s:os_arch()
    let os = s:chomp(s:system(g:goadapt#gocmd . ' env GOOS'))
    if s:shell_error()
        return ''
    endif

    let arch = s:chomp(s:system(g:goadapt#gocmd . ' env GOARCH'))
    if s:shell_error()
        return ''
    endif

    return os . '_' . arch
endfunction

let g:goadapt#os_arch = get(g:, 'goadapt#os_arch', s:os_arch())

function! goadapt#pkgiface(pkg, iface)
    let binpath = s:check_bin_path(g:goadapt#cmd)
    if empty(binpath)
        call s:error(g:goadapt#cmd . ' command is not found. Please check g:goadapt#cmd')
        return ''
    endif

    let result = s:system(printf("%s '%s' '%s'", binpath, a:pkg, a:iface))

    if s:shell_error()
        call s:error(binpath . ' command failed: ' . result)
        return ''
    endif

    return result
endfunction

function! goadapt#iface(iface)
    let binpath = s:check_bin_path(g:goadapt#cmd)
    if empty(binpath)
        call s:error(g:goadapt#cmd . ' command is not found. Please check g:goadapt#cmd')
        return ''
    endif

    let result = s:system(printf("%s '%s'", binpath, a:iface))

    if s:shell_error()
        call s:error(binpath . ' command failed: ' . result)
        return ''
    endif

    return result
endfunction


function! goadapt#do(...)
    if a:0 < 2
        if a:0 < 1
            call s:error('GoAdapt {package} {interface}')
            return
        endif
        let iface = join(a:000[:-1], ' ')
        let result = goadapt#iface(iface)

        if result ==# ''
            return
        end

        let pos = getpos('.')
        put =result
        call setpos('.', pos)
        return
    endif

    let pkg = join(a:000[:-2], ' ')
    let iface = a:000[-1]
    let result = goadapt#pkgiface(pkg, iface)

    if result ==# ''
        return
    end

    let pos = getpos('.')
    put =result
    call setpos('.', pos)
endfunction

if exists('*uniq')
    function! s:uniq(list)
        return uniq(a:list)
    endfunction
else
    " Note: Believe that the list is sorted
    function! s:uniq(list)
        let i = len(a:list) - 1
        while 0 < i
            if a:list[i-1] ==# a:list[i]
                call remove(a:list, i)
                let i -= 2
            else
                let i -= 1
            endif
        endwhile
        return a:list
    endfunction
endif

function! s:root_dirs()
    let dirs = []

    let root = substitute(s:chomp(s:system(g:goadapt#gocmd . ' env GOROOT')), '\\', '/', 'g')
    if s:shell_error()
        return []
    endif

    if root !=# '' && isdirectory(root)
        call add(dirs, root)
    endif

    let path_sep = has('win32') || has('win64') ? ';' : ':'
    let paths = map(split(s:chomp(s:system(g:goadapt#gocmd . ' env GOPATH')), path_sep), "substitute(v:val, '\\\\', '/', 'g')")
    if s:shell_error()
        return []
    endif

    if !empty(filter(paths, 'isdirectory(v:val)'))
        call extend(dirs, paths)
    endif

    return dirs
endfunction

function! s:go_packages(dirs)
    let pkgs = []
    for d in a:dirs
        let pkg_root = expand(d . '/pkg/' . s:os_arch())
        call extend(pkgs, split(globpath(pkg_root, '**/*.a', 1), "\n"))
    endfor
    return map(pkgs, "fnamemodify(v:val, ':t:r')")
endfunction

function! s:interface_list(pkg)
    let contents = split(s:system(g:goadapt#godoccmd . ' ' . a:pkg), "\n")
    if s:shell_error()
        return []
    endif

    call filter(contents, 'v:val =~# ''^type\s\+\h\w*\s\+interface''')
    return map(contents, 'a:pkg . "." . matchstr(v:val, ''^type\s\+\zs\h\w*\ze\s\+interface'')')
endfunction

" Complete package and interface for {interface}
function! goadapt#complete(arglead, cmdline, cursorpos)
    if !executable(g:goadapt#godoccmd)
        return []
    endif

    let words = split(a:cmdline, '\s\+', 1)
    if len(words) <= 3
        " TODO
        return []
    endif

    if words[-1] ==# ''
        return s:uniq(sort(s:go_packages(s:root_dirs())))
    elseif words[-1] =~# '^\h\w*$'
        return s:uniq(sort(filter(s:go_packages(s:root_dirs()), 'stridx(v:val, words[-1]) == 0')))
    elseif words[-1] =~# '^\h\w*\.\%(\h\w*\)\=$'
        let [pkg, interface] = split(words[-1], '\.', 1)
        echomsg pkg
        return s:uniq(sort(filter(s:interface_list(pkg), 'v:val =~? words[-1]')))
    else
        return []
    endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
