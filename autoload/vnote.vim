" File: vnote
" Author: lymslive
" Description: manage the overall vnote plugin
" Create: 2017-02-17
" Modify: 2017-02-24

let s:default_notebook = "~/notebook"
if exists('g:vnote_default_notebook')
    let s:default_notebook = g:vnote_default_notebook
endif
let s:default_notebook = expand(s:default_notebook)

" global configue for vnote
let s:dConfig = {}
let s:dConfig.max_tags = 5
let s:dConfig.save_minus_tag = v:true
let s:dConfig.save_plus_tag = v:true
let s:dConfig.autosave_minus_tag = v:false
let s:dConfig.autosave_plus_tag = v:false
let s:dConfig.rename_by_tag = v:false
let s:dConfig.always_update_tag = v:false

" GetNoteBook: 
let s:jNoteBook = {}
function! vnote#GetNoteBook() "{{{
    if empty(s:jNoteBook)
        let s:jNoteBook = class#notebook#new(s:default_notebook)
    endif
    return s:jNoteBook
endfunction "}}}

" GetConfig: 
function! vnote#GetConfig(...) abort "{{{
    if a:0 == 0
        return s:dConfig
    elseif a:0 == 1
        return get(s:dConfig, a:1, '')
    else
        return map(a:000, 'get(s:dConfig, v:val, "")')
    endif
endfunction "}}}

" SetConfig: 
function! vnote#SetConfig(...) abort "{{{
    if a:0 == 0
        :ELOG '[vnote] SetConfig need argument paris'
        return -1
    elseif a:0 % 2 != 0
        :ELOG '[vnote] SetConfig need argument paris'
        return -1
    endif

    let l:dict = module#less#dict#import()
    let l:dArg = l:dict.FromList(a:000)
    if has_key(l:dArg, 'notebook')
        let l:dArg['notebook'] = expand(l:dArg['notebook'])
    endif
    call l:dict.Absorb(s:dConfig, l:dArg)

    return 0
endfunction "}}}

" hNoteConfig: 
function! vnote#hNoteConfig(...) abort "{{{
    if a:0 == 0
        :LOG '[vnote] current config:'
        let l:dict = module#less#dict#import()
        echo l:dict.Display(s:dConfig)
        return 0
    endif

    let l:sArg = join(a:000, "\t")
    let l:lsArgv = split(l:sArg, '[\s,=;:]\+')
    return vnote#SetConfig(l:lsArgv)
endfunction "}}}

" statistics infor
let s:dStatis = {}
let s:dStatis.lister = 0
" GetStatis: 
function! vnote#GetStatis() abort "{{{
    return s:dStatis
endfunction "}}}
