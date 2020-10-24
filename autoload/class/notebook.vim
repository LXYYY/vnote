" Class: class#notebook
" Author: lymslive
" Description: notebook manager
" Create: 2017-02-16
" Modify: 2017-08-04

"LOAD:
if exists('s:load') && !exists('g:DEBUG')
    finish
endif

" Constant:
let s:LIST_BUFFER_NAME = '_NLST_'
let s:NBAR_BUFFER_NAME = '_NBAR_'
let s:FILE_NAME_TAGDB = 'tag.db'
let s:FILE_NAME_DATEDB = 'date.db'
let s:rtp = class#less#rtp#export()

" CLASS Define: {{{1
let s:class = class#old()
let s:class._name_ = 'class#notebook'
let s:class._version_ = 1

" the directory of notebook
let s:class.basedir = ''

" the extention of note file
let s:class.suffix = '.md'

" regexp used
let s:class.pattern = {}
" yyyy/mm/dd
let s:class.pattern.datePath = '^\d\d\d\d/\d\d/\d\d\ze/\?'
let s:class.pattern.dateYear = '^\d\d\d\d\ze/\?'
let s:class.pattern.dateMonth = '^\d\d\d\d/\d\d\ze/\?'
" yyyymmdd
let s:class.pattern.dateInt = '^\d\{8\}'
" yyyymmdd_n- \1=NoteDate, \2=NoteNumber, \3=Private
let s:class.pattern.noteFile = '^\(\d\{8\}\)_\(\d\+\)\(-\?\)'

" Class Basic: {{{1
function! class#notebook#class() abort "{{{
    return s:class
endfunction "}}}

" NEW:
function! class#notebook#new(...) abort "{{{
    let l:obj = class#new(s:class, a:000)
    return l:obj
endfunction "}}}

" CTOR:
function! class#notebook#ctor(this, ...) abort "{{{
    if a:0 > 0
        call a:this.SetBasedir(a:1)
    endif
endfunction "}}}

" ISOBJECT:
function! class#notebook#isobject(that) abort "{{{
    return class#isobject(s:class, a:that)
endfunction "}}}

" Directory Struct: {{{1
" SetBasedir: set the directory of notebook, return 0 on success
function! s:class.SetBasedir(pBasedir) dict abort "{{{
    if empty(a:pBasedir)
        echoerr 'cannot set notebook to NONE directory'
        return 1
    endif

    if !isdirectory(a:pBasedir)
        echo '? set notebook to directory that not exists: ' . a:pBasedir
    endif

    let self.basedir = a:pBasedir

    if has_key(self, 'cache_')
        unlet! self['cache_']
    endif

    if has_key(self, 'mru_')
        call self.SaveMru()
        unlet! self['mru_']
    endif

    return 0
endfunction "}}}

" Datedir: 
function! s:class.Datedir() dict abort "{{{
    return s:rtp.AddPath(self.basedir, 'd')
endfunction "}}}
" Tagdir: 
function! s:class.Tagdir() dict abort "{{{
    return s:rtp.AddPath(self.basedir, 't')
endfunction "}}}
" Cachedir: 
function! s:class.Cachedir() dict abort "{{{
    return s:rtp.AddPath(self.basedir, 'c')
endfunction "}}}
" Markdir: 
function! s:class.Markdir() dict abort "{{{
    return s:rtp.AddPath(self.basedir, 'm')
endfunction "}}}

" NoteFile Manage: {{{1
" Notedir: full path of day
" intput: yyyy/mm/dd
function! s:class.Notedir(sDatePath) dict abort "{{{
    if a:sDatePath !~ self.pattern.datePath
        echoerr a:sDatePath . ' is not a valid day path as yyyy/mm/dd'
        return ''
    else
        return self.Datedir() . '/' . a:sDatePath
    endif
endfunction "}}}

" Notefile: full path of a note file, by rule, may not exists yet
" input: (sDatePath, iNumber, [bPrivate])
" return: <notebook>/d/yyyy/mm/dd/yyyymmdd_n[-].md
function! s:class.Notefile(sDatePath, iNumber, ...) dict abort "{{{
    if match(a:sDatePath, self.pattern.datePath) == -1
        echoerr a:sDatePath . ' is not a valid day path as yyyy/mm/dd'
        return ''
    endif

    let l:iDateInt = substitute(a:sDatePath, '/', '', 'g')
    let l:pFileName = self.Datedir() . '/' . a:sDatePath . '/' . l:iDateInt . '_' . a:iNumber

    if a:0 > 0 && a:1
        let l:pFileName .= '-'
    endif

    let l:pFileName .= self.suffix

    return l:pFileName
endfunction "}}}

" GlobNote: glob note file in a date, and optional note number
function! s:class.GlobNote(sDatePath, ...) dict abort "{{{
    let l:pDatedir = self.Datedir()
    if empty(a:sDatePath)
        let l:pDiretory = l:pDatedir
    elseif a:sDatePath =~ self.pattern.dateYear
        let l:pDiretory = l:pDatedir . '/' . a:sDatePath
    else
        :ELOG 'expact date path argument as yyyy[/mm/dd]'
        return []
    endif

    if a:sDatePath =~ self.pattern.datePath
        " full date path
        let l:iDateInt = substitute(a:sDatePath, '/', '', 'g')
        let l:iNumber = get(a:000, 0, '')
        let l:sNoteGlob = printf('%s/%s_%s*%s', l:pDiretory, l:iDateInt, l:iNumber, self.suffix)
    else
        " partial date path, glob recursively
        let l:sNoteGlob = printf('%s/**/*%s', l:pDiretory, self.suffix)
    endif

    let l:lpNoteFile = glob(l:sNoteGlob, 0, 1)
    return l:lpNoteFile
endfunction "}}}

" NoteCount: how many note in a day (yyyy/mm/dd)
function! s:class.NoteCount(sDatePath) dict abort "{{{
    let l:lpNoteFile = self.GlobNote(a:sDatePath)
    let l:iCount = len(l:lpNoteFile)
    return l:iCount
endfunction "}}}

" AllocNewNote: return a full path name used as new note in a day
function! s:class.AllocNewNote(sDatePath, ...) dict abort "{{{
    let l:iCount = self.NoteCount(a:sDatePath)
    let l:iCount += 1
    if a:0 > 0
        let l:bPrivate = a:1
    else
        let l:bPrivate = v:false
    endif
    return self.Notefile(a:sDatePath, l:iCount, l:bPrivate)
endfunction "}}}

" GetLastNote: return full path name of the last note in a day
function! s:class.GetLastNote(sDatePath) dict abort "{{{
    let l:iCount = self.NoteCount(a:sDatePath)
    if l:iCount <= 0
        let l:iCount = 1
    endif
    return self.FindNoteByDateNo(a:sDatePath, l:iCount, 0)
endfunction "}}}

" FindNoteByDateNo: 
" given a date and number, return the note file full path
" the note may or may not be private, that have - suffix
" option: if a:1 nonempty, allow return a nonexists note file name
function! s:class.FindNoteByDateNo(sDatePath, iNumber, ...) abort "{{{
    let l:lpNoteFile = self.GlobNote(a:sDatePath, a:iNumber)
    let l:iCount = len(l:lpNoteFile)

    if l:iCount == 1
        return l:lpNoteFile[0]
    elseif l:iCount > 1
        echo 'have more than one note, something wrong:'
        for l:pNoteFile in l:lpNoteFile
            echo l:pNoteFile
        endfor
        return ''
    elseif l:iCount == 0
        if a:0 > 0 && !empty(a:1)
            return self.Notefile(a:sDatePath, a:iNumber)
        else
            return ''
        endif
    endif

    return ''
endfunction "}}}

" NoteList Manage: {{{1
" GetListerName: return a file name for note-list buffer
function! s:class.GetListerName() dict abort "{{{
    return s:rtp.AddPath(self.Cachedir(), s:LIST_BUFFER_NAME)
endfunction "}}}

" CreateLister: 
function! s:class.CreateLister() dict abort "{{{
    return class#notelist#new(self)
endfunction "}}}

" GetPublicNote: 
function! s:class.GetPublicNote() dict abort "{{{
    let l:lsCache = self.ReadCache()
    let l:jFilter = class#notefilter#public#new(self)
    return l:jFilter.Filter(l:lsCache)
endfunction "}}}

" GetPrivateNote: 
function! s:class.GetPrivateNote() dict abort "{{{
    let l:lsCache = self.ReadCache()
    let l:jFilter = class#notefilter#private#new(self)
    return l:jFilter.Filter(l:lsCache)
endfunction "}}}

" NoteBar Manage: {{{1
" GetBarName: 
function! s:class.GetBarName() dict abort "{{{
    return s:rtp.AddPath(self.Cachedir(), s:NBAR_BUFFER_NAME)
endfunction "}}}

" CreateBar: 
function! s:class.CreateBar() dict abort "{{{
    return class#notebar#new(self)
endfunction "}}}

" GetTagdbFile: 
function! s:class.GetTagdbFile() dict abort "{{{
    return s:rtp.AddPath(self.Tagdir(), s:FILE_NAME_TAGDB)
endfunction "}}}

" Cache Manage: {{{1
" SaveCache: 
function! s:class.SaveCache(sEntry) dict abort "{{{
    if a:sEntry !~# self.pattern.noteFile
        :ELOG 'invalid cache entry to save'
        return -1
    endif

    if !has_key(self, 'cache_')
        let self.cache_ = class#notecache#day#new(self.Cachedir())
    endif
    return self.cache_.PullEntry([a:sEntry])
endfunction "}}}

" RebuildCache: 
function! s:class.RebuildCache(lsOption) dict abort "{{{
    let l:lsNote = self.GlobNote('')
    if empty(l:lsNote)
        :WLOG 'no note in the notebook now?'
        return -1
    endif

    if has_key(self, 'cache_')
        unlet! self['cache_']
    endif

    let l:cache = class#notecache#hist#new(self.Cachedir())
    return l:cache.Rebuild(l:lsNote, a:lsOption)
endfunction "}}}

" ReadCache: 
function! s:class.ReadCache() dict abort "{{{
    if !has_key(self, 'cache_')
        let self.cache_ = class#notecache#day#new(self.Cachedir())
    endif
    return self.cache_.ReadAll()
endfunction "}}}

" MRU Manage: {{{1
" GetMruObject: 
function! s:class.GetMruObject() dict abort "{{{
    if !has_key(self, 'mru_')
        let l:dConfig = vnote#GetConfig()
        let l:iCapacity = get(l:dConfig, 'max_mru_note_list', 10)
        let self.mru_ = class#notetag#mru#new(l:iCapacity)
    endif
    return self.mru_
endfunction "}}}

" AddMru: 
function! s:class.AddMru(sNoteEntry) dict abort "{{{
    let l:jMru = self.GetMruObject()
    call l:jMru.AddEntry(a:sNoteEntry)
endfunction "}}}

" GetMruList: 
function! s:class.GetMruList() dict abort "{{{
    let l:jMru = self.GetMruObject()
    return l:jMru.list()
endfunction "}}}

" MruEmpty: 
function! s:class.MruEmpty() dict abort "{{{
    return empty(self.GetMruList())
endfunction "}}}

" SaveMru: 
function! s:class.SaveMru() dict abort "{{{
    if has_key(self, 'mru_')
        return self.mru_.SaveTagFile()
    endif
endfunction "}}}

" OnConfigChange: 
function! s:class.OnConfigChange(dArg) dict abort "{{{
    if has_key(l:dArg, 'max_mru_note_list')
        if has_key(self, 'mru_')
            call self.mru_.Resize(a:dArg['max_mru_note_list'])
        endif
    endif
endfunction "}}}

" Foot: {{{1
" LOAD:
let s:load = 1
" :DLOG 'class#notebook is loading ...'
function! class#notebook#load(...) abort "{{{
    if a:0 > 0 && !empty(a:1) && exists('s:load')
        unlet s:load
        return 0
    endif
    return s:load
endfunction "}}}

" TEST:
function! class#notebook#test(...) abort "{{{
    echo 'notebook in ~/notebook'
    " let l:jNoteBook = class#notebook#new('~/notebook')
    let l:jNoteBook = class#notebook#new(expand('~/notebook'))
    " echo l:jNoteBook.Notedir('2010/1/11')
    echo l:jNoteBook.Notedir('2010/01/11')
    echo l:jNoteBook.Notedir('2010/11/11')
    echo l:jNoteBook.Notefile('2010/11/11', 1)
    echo l:jNoteBook.Notefile('2010/11/11', 2, 'private')
    echo l:jNoteBook.Notefile('2010/11/11', 3, 1)
    echo l:jNoteBook.Notefile('2010/11/11', 4, 0)

    echo 'change notebook in ~/notebook-test'
    " call l:jNoteBook.SetBasedir('~/notebook-test')
    call l:jNoteBook.SetBasedir(expand('~/notebook-test'))
    echo l:jNoteBook.Notedir('2010/01/11')
    echo l:jNoteBook.Notedir('2010/11/11')
    echo l:jNoteBook.Notefile('2010/11/11', 1)
    echo l:jNoteBook.Notefile('2010/11/11', 2, 'private')
    echo l:jNoteBook.Notefile('2010/11/11', 3, 1)
    echo l:jNoteBook.Notefile('2010/11/11', 4, 0)
    return 0
endfunction "}}}
