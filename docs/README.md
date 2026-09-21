# Project documentation

`Nuno_Project_Explained.pdf` and `.docx` are the same document in two
formats — a technical walkthrough written to be read before an interview.

## Rebuilding

```
pip install reportlab python-docx
python3 docs/build_doc.py     # PDF
python3 docs/build_docx.py    # Word
```

## Why the body lives in `_content.py`

Both builders import it. Keeping one copy means the PDF and the Word file
cannot drift into describing different projects, which is exactly what
happens when two documents are maintained by hand.

`build_doc.py` and `build_docx.py` only supply rendering: how a heading, a
table or a code block should look in that format.

## Keeping it honest

Every figure in the document was read out of this repository rather than
recalled — line counts, the number of Socket.IO events, the size of the
catalogue, the store-read measurements. If the code changes materially, the
numbers should be re-checked before the document is reused.
