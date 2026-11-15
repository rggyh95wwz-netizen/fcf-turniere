ObjC.import('PDFKit');
function run(argv){ var d=$.PDFDocument.alloc.initWithURL($.NSURL.fileURLWithPath(argv[0])); if(!d||d.isNil()) return ''; return ObjC.unwrap(d.string); }
