use framework "Foundation"
use framework "Quartz"

on run argv
    set posixPath to item 1 of argv
    set theURL to current application's |NSURL|'s fileURLWithPath:posixPath
    set pdfDoc to current application's PDFDocument's alloc()'s initWithURL:theURL
    if pdfDoc is missing value then
        return "Failed to load PDF"
    end if
    set pageCount to pdfDoc's pageCount()
    set txt to ""
    repeat with i from 0 to (pageCount - 1)
        set thePage to (pdfDoc's pageAtIndex:i)
        set pageStr to (thePage's |string|()) as text
        set txt to txt & pageStr & return
    end repeat
    return txt
end run
