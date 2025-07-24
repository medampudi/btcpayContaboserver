#!/bin/bash
# Fix script to correct all the heredoc issues in bitcoin-sovereignty-setup.sh

# Backup the original
cp bitcoin-sovereignty-setup.sh bitcoin-sovereignty-setup.sh.backup

# Fix all the heredoc issues
sed -i '
# Fix the access-info script heredoc
s/cat > \/opt\/bitcoin\/scripts\/access-info.sh <<'\''EOF'\''/cat > \/opt\/bitcoin\/scripts\/access-info.sh <<EOF/g

# Fix the backup script heredoc  
s/cat > \/opt\/bitcoin\/scripts\/backup.sh <<'\''EOF'\''/cat > \/opt\/bitcoin\/scripts\/backup.sh <<EOF/g

# Fix the health-check script heredoc
s/cat > \/opt\/bitcoin\/scripts\/health-check.sh <<'\''EOF'\''/cat > \/opt\/bitcoin\/scripts\/health-check.sh <<EOF/g

# Fix the family scripts heredoc
s/cat > \/opt\/bitcoin\/scripts\/family-status.sh <<'\''EOF'\''/cat > \/opt\/bitcoin\/scripts\/family-status.sh <<EOF/g
s/cat > \/opt\/bitcoin\/scripts\/family-access.sh <<'\''EOF'\''/cat > \/opt\/bitcoin\/scripts\/family-access.sh <<EOF/g

# Fix the service-manager script heredoc
s/cat > \/opt\/bitcoin\/scripts\/service-manager.sh <<'\''EOF'\''/cat > \/opt\/bitcoin\/scripts\/service-manager.sh <<EOF/g
' bitcoin-sovereignty-setup.sh

# Now escape all the $ signs in the scripts that shouldn't be expanded
# This is more complex, so let's do it with a proper script fix

echo "Fixed heredoc declarations. Now fixing variable escaping..."

# Create a Python script to properly fix the escaping
cat > fix_escaping.py << 'PYTHON_EOF'
#!/usr/bin/env python3
import re

with open('bitcoin-sovereignty-setup.sh', 'r') as f:
    content = f.read()

# Find all script creation blocks and fix them
script_blocks = [
    ('access-info.sh', 'show_post_install'),
    ('backup.sh', 'health-check.sh'),
    ('health-check.sh', 'family-status.sh'),
    ('family-status.sh', 'family-access.sh'),
    ('family-access.sh', 'chmod +x'),
    ('service-manager.sh', 'chmod +x /opt/bitcoin/scripts/service-manager.sh')
]

for start_marker, end_marker in script_blocks:
    pattern = rf'(cat > /opt/bitcoin/scripts/{start_marker} <<EOF\n)(.*?)(\nEOF.*?{end_marker})'
    
    def fix_block(match):
        header = match.group(1)
        content = match.group(2)
        footer = match.group(3)
        
        # Don't escape variables that should be substituted
        keep_vars = ['BITCOIN_RPC_USER', 'BITCOIN_RPC_PASS', 'BTCPAY_DOMAIN', 'ADMIN_USER', 
                     'EMAIL', 'FAMILY_NAME', 'TAILSCALE_IP']
        
        # Escape all $ except for the ones we want to keep
        lines = content.split('\n')
        fixed_lines = []
        
        for line in lines:
            # Skip lines that are setting these variables
            if any(f'{var}=' in line for var in keep_vars):
                fixed_lines.append(line)
                continue
                
            # For other lines, escape $ but keep our variables
            fixed_line = line
            
            # First, temporarily replace our variables
            for i, var in enumerate(keep_vars):
                fixed_line = fixed_line.replace(f'${{{var}}}', f'KEEPER{i}')
                fixed_line = fixed_line.replace(f'${var}', f'KEEPER{i}')
            
            # Now escape all remaining $
            fixed_line = fixed_line.replace('$', '\\$')
            
            # Restore our variables
            for i, var in enumerate(keep_vars):
                fixed_line = fixed_line.replace(f'KEEPER{i}', f'${{{var}}}')
            
            fixed_lines.append(fixed_line)
        
        return header + '\n'.join(fixed_lines) + footer
    
    content = re.sub(pattern, fix_block, content, flags=re.DOTALL)

with open('bitcoin-sovereignty-setup.sh', 'w') as f:
    f.write(content)

print("Fixed variable escaping in all script blocks")
PYTHON_EOF

python3 fix_escaping.py

echo "Script fixing complete!"