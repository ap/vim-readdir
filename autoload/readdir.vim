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

if ! has('patch-7.2.051')
	echoerr printf('Vim 7.3 is required for readdir (this is only %d.%d)',v:version/100,v:version%100)
	finish
endif

exe printf( join( [ 'function s:glob(path, nosuf)', 'return %s', 'endfunction' ], "\n" ),
	\ has('patch-7.3.465') ? 'glob(a:path, a:nosuf, 1)' : 'split(glob(a:path, a:nosuf), "\n")' )

let s:sep = fnamemodify('',':p')[-1:]

function s:set_bufname(name)
	if bufname('%') == a:name | return 1 | endif
	let prev_alt = bufnr('#')
	silent! file `=a:name` " on success, creates an alt buffer to hold the old name
	if bufnr('#') != prev_alt | exe 'silent! bwipeout!' bufnr('#') | endif
	return bufname('%') == a:name
endfunction

function readdir#Selected()
	return b:readdir.content[ line('.') - 1 ]
endfunction

function readdir#Show(path, focus)
	silent lchdir `=a:path`
	call s:set_bufname(printf('(%d) %s', b:readdir.id, a:path))

	let path = fnamemodify(a:path, ':p') " ensure trailing slash
	let content
		\ = [fnamemodify(a:path,':h')]
		\ + ( b:readdir.hidden == 2 ? s:glob(path.'.[^.]', 0) + s:glob(path.'.??*', 0) : [] )
		\ + s:glob(path.'*', b:readdir.hidden)

	setlocal modifiable
	silent 0,$ delete
	call setline( 1, ['..'] + map( content[1:], 'split(v:val,s:sep)[-1] . ( isdirectory(v:val) ? s:sep : "" )' ) )
	setlocal nomodifiable nomodified

	let line = 1 + index(content, a:focus)
	call cursor(line ? line : 1, 1)

	call extend( b:readdir, { 'cwd': a:path, 'content': content } )
endfunction

function readdir#Open(path)
	if isdirectory(a:path) | return a:path == b:readdir.cwd || readdir#Show( a:path, b:readdir.cwd ) | endif

	if s:set_bufname(a:path)
		unlet b:readdir
		set modifiable< buftype< filetype< noswapfile< wrap<
		mapclear <buffer>

		" HACK: because :file sets not-edited (:help not-edited) but :edit won't clear it
		autocmd ReadDir BufWriteCmd <buffer> exe
		write!

		" reset &undolevels after :edit (avoid undo step) but before ftplugins (avoid overriding them)
		autocmd ReadDir BufReadPre <buffer> exe 'set undolevels<' | autocmd! ReadDir * <buffer>

		go | edit!
	else " file already open in another buffer, just switch
		let me = bufnr('%')
		edit `=a:path`
		exe 'silent! bwipeout!' me
	endif
endfunction

function readdir#CycleHidden()
	let b:readdir.hidden = ( b:readdir.hidden + 1 ) % 3
	call readdir#Show( b:readdir.cwd, readdir#Selected() )
endfunction

" vim:foldmethod=marker
