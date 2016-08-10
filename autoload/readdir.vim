" Vim global plugin for very minimal directory browsing
" Licence:     The MIT License (MIT)
" Commit:      $Format:%H$
" {{{ Copyright (c) 2015 Aristotle Pagaltzis <pagaltzis@gmx.de>
" 
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
" 
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
" 
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
" THE SOFTWARE.
" }}}

if v:version < 700
	echoerr printf('Vim 7 is required for readdir (this is only %d.%d)',v:version/100,v:version%100)
	finish
endif

exe printf( join( [ 'function s:glob(path, nosuf)', 'return %s', 'endfunction' ], "\n" ),
	\ v:version < 704 ? 'split(glob(a:path, a:nosuf), "\n")' : 'glob(a:path, a:nosuf, 1)' )

let g:readdir_hidden = get(g:, 'readdir_hidden', 0)
let s:sep = fnamemodify('',':p')[-1:]

function s:set_bufname(name)
	if bufname('%') == a:name | return 1 | endif
	let prev_alt = bufnr('#')
	silent! file `=a:name` " on success, creates an alt buffer to hold the old name
	if bufnr('#') != prev_alt | exe 'silent! bwipeout!' bufnr('#') | endif
	return bufname('%') == a:name
endfunction

function readdir#Selected()
	return b:readdir_content[ line('.') - 1 ]
endfunction

function readdir#Setup()
	if ! isdirectory(expand('%')) | return | endif

	if ! exists('b:readdir_id')
		let id = range(1,bufnr('$'))
		let taken = map(copy(id),'getbufvar(v:val,"readdir_id")')
		let b:readdir_id = filter(id,'index(taken,v:val) < 0')[0]
	endif

	call readdir#Show( simplify( expand('%:p').'.' ), '' )

	autocmd ReadDir BufEnter <buffer> silent lchdir `=b:readdir_cwd`
	nnoremap <buffer> <silent> <CR> :call readdir#Open( readdir#Selected() )<CR>
	nnoremap <buffer> <silent> o    :edit `=readdir#Selected()`<CR>
	nnoremap <buffer> <silent> t    :tabedit `=readdir#Selected()`<CR>
	nnoremap <buffer> <silent> -    :call readdir#Open( fnamemodify( b:readdir_cwd, ':h' ) )<CR>
	nnoremap <buffer> <silent> a    :call readdir#CycleHidden()<CR>
endfunction

function readdir#Show(path, focus)
	if a:path == get(b:, 'readdir_cwd', '') | return | endif
	let b:readdir_cwd = a:path

	silent lchdir `=b:readdir_cwd`
	call s:set_bufname(printf('(%d) %s', b:readdir_id, b:readdir_cwd))

	let path = fnamemodify(b:readdir_cwd, ':p') " ensure trailing slash
	let b:readdir_content
		\ = [fnamemodify(b:readdir_cwd,':h')]
		\ + ( g:readdir_hidden == 2 ? s:glob(path.'.[^.]', 0) + s:glob(path.'.??*', 0) : [] )
		\ + s:glob(path.'*', g:readdir_hidden)

	setlocal modifiable buftype=nofile filetype=readdir noswapfile nowrap undolevels=-1
	silent 0,$ delete
	call setline( 1, ['..'] + map( b:readdir_content[1:], 'split(v:val,s:sep)[-1] . ( isdirectory(v:val) ? s:sep : "" )' ) )
	setlocal nomodifiable nomodified

	let line = 1 + index(b:readdir_content, a:focus)
	call cursor(line ? line : 1, 1)
endfunction

function readdir#Open(path)
	if isdirectory(a:path) | return readdir#Show( a:path, b:readdir_cwd ) | endif

	if s:set_bufname(a:path)
		unlet b:readdir_id b:readdir_cwd b:readdir_content
		set modifiable< buftype< filetype< noswapfile< wrap<
		mapclear <buffer>

		" HACK: because :file sets not-edited (:help not-edited) but :edit won't clear it
		autocmd ReadDir BufWriteCmd <buffer> exe
		write!

		" reset &undolevels after :edit (creates undo step) but before ftplugins (avoid overriding them)
		autocmd ReadDir BufReadPre <buffer> exe 'set undolevels<' | autocmd! ReadDir * <buffer>

		go | edit!
	else " file already open in another buffer, just switch
		let me = bufnr('%')
		exe 'edit' a:path
		exe 'silent! bwipeout!' me
	endif
endfunction

function readdir#CycleHidden()
	let g:readdir_hidden = ( g:readdir_hidden + 1 ) % 3
	call readdir#Show( b:readdir_cwd, readdir#Selected() )
endfunction

" vim:foldmethod=marker
