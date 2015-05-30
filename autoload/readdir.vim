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

let g:readdir_hidden = get(g:, 'readdir_hidden', 0)

function s:set_bufname(name)
	if bufname('%') == a:name | return | endif
	silent! file `=a:name`
	exe 'silent! bwipeout!' bufnr('#')
endfunction

function s:current_entry()
	return b:readdir_content[ line('.') - 1 ]
endfunction

function readdir#Setup()
	if ! exists('b:readdir_cwd')
		let path = expand('<afile>')
		if ! isdirectory(path) | return | endif
		let b:readdir_cwd = simplify(fnamemodify(path, ':p'))
	endif

	if ! exists('b:readdir_id')
		let id = range(1,bufnr('$'))
		let taken = filter(map(copy(id),'getbufvar(v:val,"readdir_id")'),'strlen(v:val)')
		call filter(id,'index(taken,v:val) < 0')
		let b:readdir_id = id[0]
	endif

	nnoremap <buffer> <silent> <CR> :call readdir#Open()<CR>
	nnoremap <buffer> <silent> o    :call readdir#OpenNew()<CR>
	nnoremap <buffer> <silent> a    :call readdir#CycleHidden()<CR>
	setlocal undolevels=-1 buftype=nofile filetype=readdir

	call readdir#Show()
endfunction

function readdir#Show()
	if ! exists('b:readdir_cwd') | return | endif

	let path = simplify(b:readdir_cwd.'/.')
	call s:set_bufname(printf('(%d) %s', b:readdir_id, path))

	let b:readdir_content = glob(path.'/*', g:readdir_hidden, 1)
	if g:readdir_hidden == 2
		call extend(b:readdir_content, glob(path.'/.?*', 0, 1), 0)
	elseif isdirectory(path.'/..')
		call extend(b:readdir_content, [path.'/..'], 0)
	endif

	let prettied = map(copy(b:readdir_content), 'substitute(v:val, "^.*/", "", "") . ( isdirectory(v:val) ? "/" : "" )')
	if '../' == prettied[0]
		let prettied[0] = '..'
		let b:readdir_content[0] = simplify(b:readdir_content[0])
	endif

	setlocal modifiable
	0,$ delete
	call setline(1, prettied)
	setlocal nomodifiable nomodified

	let line = 1
	if exists('b:readdir_prev')
		let line = 1 + index(b:readdir_content, b:readdir_prev)
		let line += line == 0
		unlet b:readdir_prev
	endif
	call cursor(line, 1)
endfunction

function readdir#Open()
	let path = s:current_entry()

	if isdirectory(path)
		let b:readdir_prev = b:readdir_cwd
		let b:readdir_cwd = path
		return readdir#Show()
	endif

	unlet b:readdir_id b:readdir_cwd b:readdir_content
	setlocal modifiable< buftype< filetype<
	mapclear <buffer>
	call s:set_bufname(path) | go | edit
	setlocal undolevels< " left late to avoid leaving the content change during :edit on undo stack

	" :file sets the notedited flag but :edit does not clear it (see :help not-edited)
	" HACK: intercept one write, then pretend to write the file, clearing the notedited flag
	autocmd ReadDir BufWriteCmd <buffer> autocmd! ReadDir BufWriteCmd <buffer>
	write!
endfunction

function readdir#OpenNew()
	edit `=s:current_entry()`
endfunction

function readdir#CycleHidden()
	let g:readdir_hidden = ( g:readdir_hidden + 1 ) % 3
	let b:readdir_prev = s:current_entry()
	call readdir#Show()
endfunction

" vim:foldmethod=marker
