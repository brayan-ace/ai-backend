#!/usr/bin/env python3

file_path = 'lib/screens/online_ai_screen.dart'

# Read the file
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find and replace the method
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    
    # Look for the start of _buildSendButton method
    if 'Widget _buildSendButton()' in line and '{`n' in lines[i+1] if i+1 < len(lines) else False:
        # Replace with the correct method
        new_lines.append('  Widget _buildSendButton() {\n')
        new_lines.append('    return Container(\n')
        new_lines.append('      decoration: BoxDecoration(\n')
        new_lines.append('        shape: BoxShape.circle,\n')
        new_lines.append('        gradient: LinearGradient(\n')
        new_lines.append('          begin: Alignment.topLeft,\n')
        new_lines.append('          end: Alignment.bottomRight,\n')
        new_lines.append('          colors: AppTheme.primaryGradient,\n')
        new_lines.append('        ),\n')
        new_lines.append('        boxShadow: AppTheme.glowShadow,\n')
        new_lines.append('      ),\n')
        new_lines.append('      margin: EdgeInsets.only(right: 4, bottom: 4),\n')
        new_lines.append('      child: IconButton(\n')
        new_lines.append('        icon: Icon(Icons.arrow_upward, color: Colors.white, size: 20),\n')
        
        # Skip the corrupted lines until we find "onPressed:"
        while i < len(lines) and 'onPressed:' not in lines[i]:
            i += 1
        
        # Add the remaining lines
        new_lines.append(lines[i])  # onPressed: _send,
        i += 1
        new_lines.append(lines[i])  # padding: ...
        i += 1
        new_lines.append(lines[i])  # constraints: ...
        i += 1
        new_lines.append(lines[i])  # ),
        i += 1
        new_lines.append(lines[i])  # );
        i += 1
        new_lines.append(lines[i])  # }
    else:
        new_lines.append(line)
    
    i += 1

# Write the file back
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print('Send button fixed!')
