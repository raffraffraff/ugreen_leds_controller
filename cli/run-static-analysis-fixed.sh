#!/bin/bash

# Static Analysis Script for UGREEN LEDs Controller CLI
# This script runs multiple static analysis tools to check for security issues, bugs, and code quality

set -e

PROJECT_DIR="$(pwd)"
REPORT_DIR="$PROJECT_DIR/static-analysis-reports"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Create reports directory
mkdir -p "$REPORT_DIR"

echo "🔍 Starting comprehensive static analysis of UGREEN LEDs Controller CLI..."
echo "📁 Source directory: $PROJECT_DIR"
echo "📊 Reports directory: $REPORT_DIR"
echo "🕒 Timestamp: $TIMESTAMP"
echo ""

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
        local lines=$(wc -l < "$output_file")
        echo "   📄 Report has $lines lines"
    fi
    echo ""
}

# 1. Cppcheck - C/C++ static analysis
echo "============================================================"
echo "🔍 CPPCHECK ANALYSIS (C/C++ Static Analysis)"
echo "============================================================"
run_analysis "Cppcheck" \
    "cppcheck --enable=all --inconclusive --std=c++17 --platform=unix64 --suppress=missingIncludeSystem --xml --xml-version=2 *.cpp *.h" \
    "$REPORT_DIR/cppcheck-$TIMESTAMP.xml"

# Also create human-readable cppcheck report
run_analysis "Cppcheck (Human Readable)" \
    "cppcheck --enable=all --inconclusive --std=c++17 --platform=unix64 --suppress=missingIncludeSystem *.cpp *.h" \
    "$REPORT_DIR/cppcheck-$TIMESTAMP.txt"

# 2. Clang-tidy - Modern C++ linter
echo "============================================================"
echo "🔍 CLANG-TIDY ANALYSIS (Modern C++ Linter)"
echo "============================================================"

# Create compile_commands.json for clang-tidy
cat > compile_commands.json << EOF
[
EOF

first=true
for cpp_file in *.cpp; do
    if [ -f "$cpp_file" ]; then
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> compile_commands.json
        fi
        cat >> compile_commands.json << EOF
{
  "directory": "$PROJECT_DIR",
  "command": "g++ -std=c++17 -Wall -Wextra -c $cpp_file",
  "file": "$cpp_file"
}
EOF
    fi
done

cat >> compile_commands.json << EOF

]
EOF

for cpp_file in *.cpp; do
    if [ -f "$cpp_file" ]; then
        filename=$(basename "$cpp_file")
        echo "   🔍 Analyzing $filename..."
        run_analysis "Clang-tidy ($filename)" \
            "clang-tidy '$cpp_file' -p . -- -std=c++17" \
            "$REPORT_DIR/clang-tidy-$filename-$TIMESTAMP.txt"
    fi
done

# 3. Flawfinder - Security-focused static analysis
echo "============================================================"
echo "🔍 FLAWFINDER ANALYSIS (Security Vulnerability Scanner)"
echo "============================================================"
run_analysis "Flawfinder" \
    "flawfinder --html --context --minlevel=1 *.cpp *.h" \
    "$REPORT_DIR/flawfinder-$TIMESTAMP.html"

# Also create text version
run_analysis "Flawfinder (Text)" \
    "flawfinder --context --minlevel=1 *.cpp *.h" \
    "$REPORT_DIR/flawfinder-$TIMESTAMP.txt"

# 4. Custom security pattern analysis
echo "============================================================"
echo "🔍 CUSTOM SECURITY PATTERN ANALYSIS"
echo "============================================================"
SECURITY_REPORT="$REPORT_DIR/security-patterns-$TIMESTAMP.txt"
echo "Custom Security Pattern Analysis Report" > "$SECURITY_REPORT"
echo "Generated: $(date)" >> "$SECURITY_REPORT"
echo "=========================================" >> "$SECURITY_REPORT"
echo "" >> "$SECURITY_REPORT"

# Check for common C++ security issues
echo "🔒 Checking for common C++ security patterns..."

echo "--- Potential Buffer Overflow Issues ---" >> "$SECURITY_REPORT"
grep -n -E "(strcpy|strcat|sprintf|gets|memcpy|memmove)" *.cpp *.h >> "$SECURITY_REPORT" 2>/dev/null || echo "None found" >> "$SECURITY_REPORT"
echo "" >> "$SECURITY_REPORT"

echo "--- Raw Pointer Usage ---" >> "$SECURITY_REPORT"
grep -n -E "(\*\s*[a-zA-Z_][a-zA-Z0-9_]*\s*=|[a-zA-Z_][a-zA-Z0-9_]*\s*\*)" *.cpp *.h >> "$SECURITY_REPORT" 2>/dev/null | head -20 || echo "Analysis completed" >> "$SECURITY_REPORT"
echo "" >> "$SECURITY_REPORT"

echo "--- Unchecked Return Values ---" >> "$SECURITY_REPORT"
grep -n -E "^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*\(" *.cpp *.h | grep -v -E "(if|while|for|return|void|static|std::|#)" >> "$SECURITY_REPORT" 2>/dev/null | head -20 || echo "Analysis completed" >> "$SECURITY_REPORT"
echo "" >> "$SECURITY_REPORT"

echo "--- Exception Handling ---" >> "$SECURITY_REPORT"
grep -n -E "(try|catch|throw|noexcept)" *.cpp *.h >> "$SECURITY_REPORT" 2>/dev/null || echo "None found" >> "$SECURITY_REPORT"
echo "" >> "$SECURITY_REPORT"

echo "--- Memory Management ---" >> "$SECURITY_REPORT"
grep -n -E "(new|delete|malloc|free|shared_ptr|unique_ptr)" *.cpp *.h >> "$SECURITY_REPORT" 2>/dev/null || echo "None found" >> "$SECURITY_REPORT"
echo "" >> "$SECURITY_REPORT"

echo "--- Thread Safety ---" >> "$SECURITY_REPORT"
grep -n -E "(thread|mutex|lock|atomic)" *.cpp *.h >> "$SECURITY_REPORT" 2>/dev/null || echo "None found" >> "$SECURITY_REPORT"
echo "" >> "$SECURITY_REPORT"

echo "   ✅ Custom security analysis completed"
echo "   📄 Report: $SECURITY_REPORT"
echo ""

# 5. Code complexity analysis
echo "============================================================"
echo "🔍 CODE COMPLEXITY ANALYSIS"
echo "============================================================"
COMPLEXITY_REPORT="$REPORT_DIR/complexity-$TIMESTAMP.txt"

echo "Code Complexity Analysis Report" > "$COMPLEXITY_REPORT"
echo "Generated: $(date)" >> "$COMPLEXITY_REPORT"
echo "===============================" >> "$COMPLEXITY_REPORT"
echo "" >> "$COMPLEXITY_REPORT"

for file in *.cpp *.h; do
    if [ -f "$file" ]; then
        echo "--- Analysis for $file ---" >> "$COMPLEXITY_REPORT"
        echo "Lines of Code:" >> "$COMPLEXITY_REPORT"
        wc -l "$file" >> "$COMPLEXITY_REPORT"
        
        echo "Function Count:" >> "$COMPLEXITY_REPORT"
        grep -c -E "^[a-zA-Z_].*\(.*\)\s*(const)?\s*{?" "$file" >> "$COMPLEXITY_REPORT" 2>/dev/null || echo "0" >> "$COMPLEXITY_REPORT"
        
        echo "Class Count:" >> "$COMPLEXITY_REPORT"
        grep -c "^class " "$file" >> "$COMPLEXITY_REPORT" 2>/dev/null || echo "0" >> "$COMPLEXITY_REPORT"
        
        echo "TODO/FIXME Comments:" >> "$COMPLEXITY_REPORT"
        grep -n -i -E "(TODO|FIXME|XXX|HACK)" "$file" >> "$COMPLEXITY_REPORT" 2>/dev/null || echo "None found" >> "$COMPLEXITY_REPORT"
        echo "" >> "$COMPLEXITY_REPORT"
    fi
done

echo "   ✅ Code complexity analysis completed"
echo "   📄 Report: $COMPLEXITY_REPORT"
echo ""

# 6. Generate summary report
echo "============================================================"
echo "📊 GENERATING SUMMARY REPORT"
echo "============================================================"
SUMMARY_REPORT="$REPORT_DIR/summary-$TIMESTAMP.txt"

echo "UGREEN LEDs Controller CLI - Static Analysis Summary" > "$SUMMARY_REPORT"
echo "===================================================" >> "$SUMMARY_REPORT"
echo "Generated: $(date)" >> "$SUMMARY_REPORT"
echo "Project: $PROJECT_DIR" >> "$SUMMARY_REPORT"
echo "" >> "$SUMMARY_REPORT"

echo "📁 FILES ANALYZED:" >> "$SUMMARY_REPORT"
for file in *.cpp *.h; do
    if [ -f "$file" ]; then
        echo "  - $file ($(wc -l < "$file") lines)" >> "$SUMMARY_REPORT"
    fi
done
echo "" >> "$SUMMARY_REPORT"

echo "🔧 TOOLS USED:" >> "$SUMMARY_REPORT"
echo "  - Cppcheck (C/C++ static analysis)" >> "$SUMMARY_REPORT"
echo "  - Clang-tidy (Modern C++ linter)" >> "$SUMMARY_REPORT"
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
echo "  - Cppcheck issues: $(grep -c "error\|warning" "$REPORT_DIR/cppcheck-$TIMESTAMP.txt" 2>/dev/null || echo "0")" >> "$SUMMARY_REPORT"
echo "  - Flawfinder hits: $(grep -c "Hits = " "$REPORT_DIR/flawfinder-$TIMESTAMP.txt" 2>/dev/null || echo "0")" >> "$SUMMARY_REPORT"
echo "" >> "$SUMMARY_REPORT"

echo "📋 NEXT STEPS:" >> "$SUMMARY_REPORT"
echo "  1. Review individual tool reports for detailed findings" >> "$SUMMARY_REPORT"
echo "  2. Address high-priority security issues first" >> "$SUMMARY_REPORT"
echo "  3. Fix coding standard violations" >> "$SUMMARY_REPORT"
echo "  4. Consider modern C++ best practices" >> "$SUMMARY_REPORT"
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
