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

# files.field 라인 제거 (존재하지 않는 getter)
sed -i '' '/mp\.fields\[.*files.*\] = files\.field;/d' "$FILE"

# mp.files.add(files)를 mp.files.addAll(files)로 변경
sed -i '' 's/mp\.files\.add(files);/mp.files.addAll(files);/g' "$FILE"

# files != null을 files.isNotEmpty로 변경 (더 안전)
sed -i '' 's/if (files != null)/if (files.isNotEmpty)/g' "$FILE"

echo "✅ Patch complete!"
echo ""
echo "📝 Changes made:"
echo "   - Removed: mp.fields[r'files'] = files.field;"
echo "   - Changed: mp.files.add(files) → mp.files.addAll(files)"
echo "   - Changed: files != null → files.isNotEmpty"
echo ""
echo "🔄 Next steps:"
echo "   cd generated && flutter pub get"
