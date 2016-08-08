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
	let path = expand('<afile>')
	if ! isdirectory(path) | return | endif

	if ! exists('b:readdir_id')
		let id = range(1,bufnr('$'))
		let taken = filter(map(copy(id),'getbufvar(v:val,"readdir_id")'),'strlen(v:val)')
		call filter(id,'index(taken,v:val) < 0')
		let b:readdir_id = id[0]
	endif

	nnoremap <buffer> <silent> <CR> :call readdir#Open( readdir#Selected() )<CR>
	nnoremap <buffer> <silent> o    :edit `=readdir#Selected()`<CR>
	nnoremap <buffer> <silent> t    :tabedit `=readdir#Selected()`<CR>
	nnoremap <buffer> <silent> -    :call readdir#Open( fnamemodify( b:readdir_cwd, ':h' ) )<CR>
	nnoremap <buffer> <silent> a    :call readdir#CycleHidden()<CR>
	setlocal undolevels=-1 buftype=nofile filetype=readdir

	call readdir#Show( simplify( fnamemodify(path, ':p').'.' ), '' )

	autocmd ReadDir BufEnter <buffer> silent lchdir `=b:readdir_cwd`
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

	let prettied = map(copy(b:readdir_content), 'substitute(v:val, "^.*/", "", "") . ( isdirectory(v:val) ? "/" : "" )')
	let prettied[0] = '..'

	setlocal modifiable
	silent 0,$ delete
	call setline(1, prettied)
	setlocal nomodifiable nomodified

	let line = 1
	if strlen(a:focus)
		let line = 1 + index(b:readdir_content, a:focus)
		let line += line == 0
	endif
	call cursor(line, 1)
endfunction

function readdir#Open(path)
	if isdirectory(a:path) | return readdir#Show( a:path, b:readdir_cwd ) | endif

	if s:set_bufname(a:path)
		silent chdir `=expand('%:p:h')` " reset haslocaldir()
		unlet b:readdir_id b:readdir_cwd b:readdir_content
		setlocal modifiable< buftype< filetype<
		mapclear <buffer>
		autocmd! ReadDir BufEnter <buffer>

		go | edit
		setlocal undolevels< " left late to avoid leaving the content change during :edit on undo stack

		" :file sets the notedited flag but :edit does not clear it (see :help not-edited)
		" HACK: intercept one write, then pretend to write the file, clearing the notedited flag
		autocmd ReadDir BufWriteCmd <buffer> autocmd! ReadDir BufWriteCmd <buffer>
		write!
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
