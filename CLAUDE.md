# Repo rules

- All text files use LF line endings (see `.gitattributes`: `* text eol=lf`). Only `*.bat`, `*.cmd`
  and `*.ps1` use CRLF.
- Never write CRLF. After creating or editing files, verify with `git ls-files --eol -m -o
  --exclude-standard` (every `w/` column must say `lf`). Strip carriage returns with
  `dos2unix <file>`. Do not count them with `grep` and a CR escape: the quoting gets mangled and
  it matches every line.
- Python writing files must pass `newline="\n"` (use `open(..., newline="\n")`, not
  `Path.write_text`, which converts to CRLF on Windows).
