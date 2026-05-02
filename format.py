import os
import glob
import re

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Step 1: Remove useless comments
    new_lines = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('//') and not stripped.startswith('///') and 'MARK:' not in stripped:
            continue
        new_lines.append(line.rstrip())
        
    # Step 2: Strip all empty lines
    non_empty = [line for line in new_lines if line.strip() != '']
    
    formatted = []
    in_imports = False
    
    for i, line in enumerate(non_empty):
        stripped = line.strip()
        
        # Blank line after imports
        if stripped.startswith('import '):
            in_imports = True
        elif in_imports:
            # This is the first line after imports
            formatted.append('')
            in_imports = False
            
        needs_blank = False
        is_decl = re.match(r'^(public\s+|private\s+|internal\s+)?(final\s+)?(struct|class|enum|protocol|extension)\b', stripped)
        
        if is_decl or stripped == '@main' or stripped == '#Preview {':
            needs_blank = True
            
        if needs_blank and i > 0:
            prev_stripped = formatted[-1].strip() if formatted else ''
            # don't add blank line if the previous line is an attribute like @main
            if prev_stripped != '@main' and formatted[-1] != '':
                formatted.append('')
                
        formatted.append(line)

    if formatted and formatted[-1] != '':
        formatted.append('')

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write('\n'.join(formatted))

for f in glob.glob('/Users/xiaoyuan/Documents/Twinskaraoke/**/*.swift', recursive=True):
    process_file(f)
print("Formatting complete.")
