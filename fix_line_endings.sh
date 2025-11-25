#!/bin/bash
# Fix line endings for all shell scripts

echo "Fixing line endings for shell scripts..."

# Fix all .sh files in current directory
for file in *.sh; do
    if [ -f "$file" ]; then
        dos2unix "$file" 2>/dev/null || sed -i 's/\r$//' "$file"
        chmod +x "$file"
        echo "✓ Fixed: $file"
    fi
done

# Fix scripts in scripts/ directory
if [ -d "scripts" ]; then
    for file in scripts/*.sh; do
        if [ -f "$file" ]; then
            dos2unix "$file" 2>/dev/null || sed -i 's/\r$//' "$file"
            chmod +x "$file"
            echo "✓ Fixed: $file"
        fi
    done
fi

echo ""
echo "✓ Line endings fixed!"
echo ""
echo "Now you can run: ./setup_post_restauracion.sh"
