#!/bin/bash
# OpenAPI Generator로 생성된 코드의 알려진 버그를 자동으로 패치하는 스크립트
# 
# 사용법:
#   chmod +x patch_generated.sh
#   ./patch_generated.sh

echo "🔧 Patching generated code for multipart file handling..."

FILE="generated/lib/api/api_api.dart"

if [ ! -f "$FILE" ]; then
  echo "❌ File not found: $FILE"
  echo "   Make sure you've run 'openapi-generator generate' first."
  exit 1
fi

# 백업 생성
cp "$FILE" "${FILE}.backup"
echo "📦 Backup created: ${FILE}.backup"

# file != null을 제거하고 직접 로직 사용 (단일 파일의 경우)
# 108-113 라인의 null 체크와 관련 로직을 제거하고 간단하게 변경
sed -i '' '/if (file != null) {/,/}/c\
    hasFields = true;\
    mp.files.add(file);
' "$FILE"

echo "✅ Patch complete!"
echo ""
echo "📝 Changes made:"
echo "   - Removed unnecessary null check for required file parameter"
echo "   - Simplified multipart file handling"
echo ""
echo "🔄 Next steps:"
echo "   cd generated && dart analyze"
