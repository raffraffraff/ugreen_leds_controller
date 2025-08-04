#!/bin/bash

# Static Analysis Script for TUXEDO YT6801 Network Driver
# This script runs multiple static analysis tools to check for security issues, bugs, and code quality

set -e

PROJECT_DIR="$(pwd)"
SRC_DIR="$PROJECT_DIR/src"
REPORT_DIR="$PROJECT_DIR/static-analysis-reports"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Create reports directory
mkdir -p "$REPORT_DIR"

echo "🔍 Starting comprehensive static analysis of TUXEDO YT6801 driver..."
echo "📁 Source directory: $SRC_DIR"
echo "📊 Reports directory: $REPORT_DIR"
echo "🕒 Timestamp: $TIMESTAMP"
echo ""

# Change to project directory
cd "$PROJECT_DIR"

# Function to run analysis tools
run_analysis() {
    local tool_name="$1"
    local command="$2"
    local output_file="$3"
    
    echo "🔧 Running $tool_name..."
    echo "   Command: $command"
    echo "   Output: $output_file"
    
    if eval "$command" > "$output_file" 2>&1; then
        echo "   ✅ $tool_name completed successfully"
        local lines=$(wc -l < "$output_file")
        echo "   📄 Report has $lines lines"
    else
        echo "   ⚠️  $tool_name completed with warnings/errors (check report)"
    fi
    echo ""
}

# Find kernel build directory
KERNEL_BUILD_DIR="/lib/modules/$(uname -r)/build"
if [ ! -d "$KERNEL_BUILD_DIR" ]; then
    echo "⚠️  Kernel build directory not found for current kernel: $KERNEL_BUILD_DIR"
    echo "   Looking for alternative kernel build directories..."
    
    # Try to find any available kernel build directory
    ALT_BUILD_DIR=$(find /lib/modules -name "build" -type l 2>/dev/null | head -n1)
    if [ -n "$ALT_BUILD_DIR" ] && [ -d "$ALT_BUILD_DIR" ]; then
        KERNEL_BUILD_DIR="$ALT_BUILD_DIR"
        echo "   ✅ Using alternative kernel build directory: $KERNEL_BUILD_DIR"
    else
        echo "   ❌ No kernel build directory found. Please install kernel-devel package"
        echo "   Continuing with limited analysis (skipping kernel-specific tools)..."
        KERNEL_BUILD_DIR=""
    fi
fi

echo "🐧 Kernel build directory: $KERNEL_BUILD_DIR"
echo ""

# 1. Sparse - Linux kernel static analysis tool
if [ -n "$KERNEL_BUILD_DIR" ] && [ -d "$KERNEL_BUILD_DIR" ]; then
    echo "============================================================"
    echo "🔍 SPARSE ANALYSIS (Linux Kernel Static Checker)"
    echo "============================================================"
    run_analysis "Sparse" \
        "make -C $KERNEL_BUILD_DIR M=$SRC_DIR C=2 CF='-D__CHECK_ENDIAN__ -Wbitwise -Wcast-truncate -Wdefault-bitfield-sign -Wdo-while -Winit-cstring -Wone-bit-signed-bitfield -Wparen-string -Wptr-subtraction-blows -Wreturn-void -Wshadow -Wtypesign -Wundef' modules" \
        "$REPORT_DIR/sparse-$TIMESTAMP.txt"
else
    echo "⚠️  Skipping Sparse analysis (no kernel build directory available)"
    echo "" > "$REPORT_DIR/sparse-$TIMESTAMP.txt"
fi

# 2. Cppcheck - C/C++ static analysis
echo "============================================================"
echo "🔍 CPPCHECK ANALYSIS (C/C++ Static Analysis)"
echo "============================================================"
run_analysis "Cppcheck" \
    "cppcheck --enable=all --inconclusive --std=c99 --platform=unix64 --suppress=missingIncludeSystem --xml --xml-version=2 $SRC_DIR" \
    "$REPORT_DIR/cppcheck-$TIMESTAMP.xml"

# Also create human-readable cppcheck report
run_analysis "Cppcheck (Human Readable)" \
    "cppcheck --enable=all --inconclusive --std=c99 --platform=unix64 --suppress=missingIncludeSystem $SRC_DIR" \
    "$REPORT_DIR/cppcheck-$TIMESTAMP.txt"

# 3. Clang-tidy - Modern C++ linter
echo "============================================================"
echo "🔍 CLANG-TIDY ANALYSIS (Modern C Linter)"
echo "============================================================"

if [ -n "$KERNEL_BUILD_DIR" ] && [ -d "$KERNEL_BUILD_DIR" ]; then
    # Create compile_commands.json for clang-tidy
    cat > compile_commands.json << EOF
[
{
  "directory": "$PROJECT_DIR",
  "command": "gcc -I$KERNEL_BUILD_DIR/include -I$KERNEL_BUILD_DIR/arch/x86/include -I$KERNEL_BUILD_DIR/arch/x86/include/generated -I$KERNEL_BUILD_DIR/include/generated -D__KERNEL__ -DMODULE -c src/yt6801_main.c",
  "file": "src/yt6801_main.c"
},
{
  "directory": "$PROJECT_DIR",
  "command": "gcc -I$KERNEL_BUILD_DIR/include -I$KERNEL_BUILD_DIR/arch/x86/include -I$KERNEL_BUILD_DIR/arch/x86/include/generated -I$KERNEL_BUILD_DIR/include/generated -D__KERNEL__ -DMODULE -c src/yt6801_ethtool.c",
  "file": "src/yt6801_ethtool.c"
}
]
EOF

    for c_file in $SRC_DIR/*.c; do
        if [ -f "$c_file" ]; then
            filename=$(basename "$c_file")
            echo "   🔍 Analyzing $filename..."
            run_analysis "Clang-tidy ($filename)" \
                "clang-tidy '$c_file' -p . -- -I$KERNEL_BUILD_DIR/include -I$KERNEL_BUILD_DIR/arch/x86/include -I$KERNEL_BUILD_DIR/arch/x86/include/generated -I$KERNEL_BUILD_DIR/include/generated -D__KERNEL__ -DMODULE" \
                "$REPORT_DIR/clang-tidy-$filename-$TIMESTAMP.txt"
        fi
    done
else
    echo "⚠️  Skipping Clang-tidy analysis (no kernel build directory available)"
    for c_file in $SRC_DIR/*.c; do
        if [ -f "$c_file" ]; then
            filename=$(basename "$c_file")
            echo "" > "$REPORT_DIR/clang-tidy-$filename-$TIMESTAMP.txt"
        fi
    done
fi

# 4. Flawfinder - Security-focused static analysis
echo "============================================================"
echo "🔍 FLAWFINDER ANALYSIS (Security Vulnerability Scanner)"
echo "============================================================"
run_analysis "Flawfinder" \
    "flawfinder --html --context --minlevel=1 $SRC_DIR" \
    "$REPORT_DIR/flawfinder-$TIMESTAMP.html"

# Also create text version
run_analysis "Flawfinder (Text)" \
    "flawfinder --context --minlevel=1 $SRC_DIR" \
    "$REPORT_DIR/flawfinder-$TIMESTAMP.txt"

# 5. Custom security pattern analysis
echo "============================================================"
echo "🔍 CUSTOM SECURITY PATTERN ANALYSIS"
echo "============================================================"
SECURITY_REPORT="$REPORT_DIR/security-patterns-$TIMESTAMP.txt"
echo "Custom Security Pattern Analysis Report" > "$SECURITY_REPORT"
echo "Generated: $(date)" >> "$SECURITY_REPORT"
echo "=========================================" >> "$SECURITY_REPORT"
echo "" >> "$SECURITY_REPORT"

# Check for common kernel security issues
echo "🔒 Checking for common kernel security patterns..."

echo "--- Potential Buffer Overflow Issues ---" >> "$SECURITY_REPORT"
grep -n -E "(strcpy|strcat|sprintf|gets|memcpy|memmove)" $SRC_DIR/*.c >> "$SECURITY_REPORT" 2>/dev/null || echo "None found" >> "$SECURITY_REPORT"
echo "" >> "$SECURITY_REPORT"

echo "--- Unchecked Return Values ---" >> "$SECURITY_REPORT"
grep -n -E "^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*\(" $SRC_DIR/*.c | grep -v -E "(if|while|for|return|void|static)" >> "$SECURITY_REPORT" 2>/dev/null | head -20 || echo "Analysis completed" >> "$SECURITY_REPORT"
echo "" >> "$SECURITY_REPORT"

echo "--- Direct Memory Access Patterns ---" >> "$SECURITY_REPORT"
grep -n -E "(ioremap|__raw_|readl|writel|inb|outb)" $SRC_DIR/*.c >> "$SECURITY_REPORT" 2>/dev/null || echo "None found" >> "$SECURITY_REPORT"
echo "" >> "$SECURITY_REPORT"

echo "--- Integer Overflow Checks ---" >> "$SECURITY_REPORT"
grep -n -E "(SIZE_MAX|INT_MAX|UINT_MAX|overflow|underflow)" $SRC_DIR/*.c >> "$SECURITY_REPORT" 2>/dev/null || echo "None found" >> "$SECURITY_REPORT"
echo "" >> "$SECURITY_REPORT"

echo "--- Locking and Synchronization ---" >> "$SECURITY_REPORT"
grep -n -E "(spin_lock|mutex_lock|rcu_read|atomic_)" $SRC_DIR/*.c >> "$SECURITY_REPORT" 2>/dev/null || echo "None found" >> "$SECURITY_REPORT"
echo "" >> "$SECURITY_REPORT"

echo "   ✅ Custom security analysis completed"
echo "   📄 Report: $SECURITY_REPORT"
echo ""

# 6. Code complexity analysis
echo "============================================================"
echo "🔍 CODE COMPLEXITY ANALYSIS"
echo "============================================================"
COMPLEXITY_REPORT="$REPORT_DIR/complexity-$TIMESTAMP.txt"

echo "Code Complexity Analysis Report" > "$COMPLEXITY_REPORT"
echo "Generated: $(date)" >> "$COMPLEXITY_REPORT"
echo "===============================" >> "$COMPLEXITY_REPORT"
echo "" >> "$COMPLEXITY_REPORT"

for c_file in $SRC_DIR/*.c; do
    if [ -f "$c_file" ]; then
        echo "--- Analysis for $(basename "$c_file") ---" >> "$COMPLEXITY_REPORT"
        echo "Lines of Code:" >> "$COMPLEXITY_REPORT"
        wc -l "$c_file" >> "$COMPLEXITY_REPORT"
        
        echo "Function Count:" >> "$COMPLEXITY_REPORT"
        grep -c "^[a-zA-Z_].*(" "$c_file" >> "$COMPLEXITY_REPORT" 2>/dev/null || echo "0" >> "$COMPLEXITY_REPORT"
        
        echo "TODO/FIXME Comments:" >> "$COMPLEXITY_REPORT"
        grep -n -i -E "(TODO|FIXME|XXX|HACK)" "$c_file" >> "$COMPLEXITY_REPORT" 2>/dev/null || echo "None found" >> "$COMPLEXITY_REPORT"
        echo "" >> "$COMPLEXITY_REPORT"
    fi
done

echo "   ✅ Code complexity analysis completed"
echo "   📄 Report: $COMPLEXITY_REPORT"
echo ""

# 7. Generate summary report
echo "============================================================"
echo "📊 GENERATING SUMMARY REPORT"
echo "============================================================"
SUMMARY_REPORT="$REPORT_DIR/summary-$TIMESTAMP.txt"

echo "TUXEDO YT6801 Driver - Static Analysis Summary" > "$SUMMARY_REPORT"
echo "===============================================" >> "$SUMMARY_REPORT"
echo "Generated: $(date)" >> "$SUMMARY_REPORT"
echo "Project: $PROJECT_DIR" >> "$SUMMARY_REPORT"
echo "" >> "$SUMMARY_REPORT"

echo "📁 FILES ANALYZED:" >> "$SUMMARY_REPORT"
find "$SRC_DIR" -name "*.c" -o -name "*.h" | while read file; do
    echo "  - $(basename "$file") ($(wc -l < "$file") lines)" >> "$SUMMARY_REPORT"
done
echo "" >> "$SUMMARY_REPORT"

echo "🔧 TOOLS USED:" >> "$SUMMARY_REPORT"
echo "  - Sparse (Linux kernel static checker)" >> "$SUMMARY_REPORT"
echo "  - Cppcheck (C/C++ static analysis)" >> "$SUMMARY_REPORT"
echo "  - Clang-tidy (Modern C linter)" >> "$SUMMARY_REPORT"
echo "  - Flawfinder (Security vulnerability scanner)" >> "$SUMMARY_REPORT"
echo "  - Custom security pattern analysis" >> "$SUMMARY_REPORT"
echo "  - Code complexity analysis" >> "$SUMMARY_REPORT"
echo "" >> "$SUMMARY_REPORT"

echo "📊 REPORT FILES GENERATED:" >> "$SUMMARY_REPORT"
ls -la "$REPORT_DIR"/*$TIMESTAMP* | while read line; do
    echo "  - $(echo "$line" | awk '{print $9}' | xargs basename)" >> "$SUMMARY_REPORT"
done
echo "" >> "$SUMMARY_REPORT"

echo "🔍 QUICK ANALYSIS:" >> "$SUMMARY_REPORT"
echo "  - Sparse warnings: $(grep -c "warning" "$REPORT_DIR/sparse-$TIMESTAMP.txt" 2>/dev/null || echo "0")" >> "$SUMMARY_REPORT"
echo "  - Cppcheck issues: $(grep -c "error\|warning" "$REPORT_DIR/cppcheck-$TIMESTAMP.txt" 2>/dev/null || echo "0")" >> "$SUMMARY_REPORT"
echo "  - Flawfinder hits: $(grep -c "Hits = " "$REPORT_DIR/flawfinder-$TIMESTAMP.txt" 2>/dev/null || echo "0")" >> "$SUMMARY_REPORT"
echo "" >> "$SUMMARY_REPORT"

echo "📋 NEXT STEPS:" >> "$SUMMARY_REPORT"
echo "  1. Review individual tool reports for detailed findings" >> "$SUMMARY_REPORT"
echo "  2. Address high-priority security issues first" >> "$SUMMARY_REPORT"
echo "  3. Fix coding standard violations" >> "$SUMMARY_REPORT"
echo "  4. Consider kernel coding style guidelines" >> "$SUMMARY_REPORT"
echo "  5. Run tests after making fixes" >> "$SUMMARY_REPORT"
echo "" >> "$SUMMARY_REPORT"

# Clean up temporary files
rm -f compile_commands.json

echo "✅ Static analysis completed successfully!"
echo ""
echo "📊 Summary report: $SUMMARY_REPORT"
echo "📁 All reports in: $REPORT_DIR"
echo ""
echo "🔍 To view the summary:"
echo "   cat $SUMMARY_REPORT"
echo ""
echo "🔍 To view individual reports:"
echo "   ls -la $REPORT_DIR/"
