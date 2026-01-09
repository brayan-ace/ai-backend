#!/usr/bin/env python3

file_path = 'lib/screens/online_ai_screen.dart'

# Read the file
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the method
old_method = '''  Widget _buildSendButton() {`n    return Container(`n      decoration: BoxDecoration(`n        shape: BoxShape.circle,`n        gradient: LinearGradient(`n          begin: Alignment.topLeft,`n          end: Alignment.bottomRight,`n          colors: AppTheme.primaryGradient,`n        ),`n        boxShadow: AppTheme.glowShadow,`n      ),`n      margin: EdgeInsets.only(right: 4, bottom: 4),`n      child: IconButton(`n        icon: Icon(Icons.arrow_upward, color: Colors.white, size: 20),
        onPressed: _send,
        padding: EdgeInsets.all(8),
        constraints: BoxConstraints(),
      ),
    );
  }'''

new_method = '''  Widget _buildSendButton() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.primaryGradient,
        ),
        boxShadow: AppTheme.glowShadow,
      ),
      margin: EdgeInsets.only(right: 4, bottom: 4),
      child: IconButton(
        icon: Icon(Icons.arrow_upward, color: Colors.white, size: 20),
        onPressed: _send,
        padding: EdgeInsets.all(8),
        constraints: BoxConstraints(),
      ),
    );
  }'''

content = content.replace(old_method, new_method)

# Write the file back
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Send button updated successfully!')
