# 1. 최신 OpenAPI 스펙 다운로드
curl -o api/openapi.yaml https://newdawnsoi.site/v3/api-docs

# 2. 코드 재생성
cd api
openapi-generator generate -c config.yaml

# 3. 패치 스크립트 실행 (필수!)
./patch_generated.sh
  
# 4. 의존성 재설치
cd generated
flutter pub get

# 5. 메인 프로젝트 의존성 업데이트
cd ../..
flutter pub get
