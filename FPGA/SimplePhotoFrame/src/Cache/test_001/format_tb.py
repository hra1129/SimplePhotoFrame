from pathlib import Path
import re

p = Path('tb.sv')
text = p.read_text(encoding='utf-8')
lines = []
for line in text.splitlines():
    s = line
    if 'if(' in s or 'if (' in s:
        s = re.sub(r'if\s*\(\s*(.*?)\s*\)\s*begin', r'if( \1 ) begin', s)
        s = re.sub(r'if\s*\(\s*(.*?)\s*\)\s*else', r'if( \1 ) else', s)
    if '$display(' in s or '$display (' in s:
        s = re.sub(r'\$display\s*\(\s*(.*?)\s*\);', r'$display( \1 );', s)
    lines.append(s)
p.write_text('\n'.join(lines) + '\n', encoding='utf-8')
