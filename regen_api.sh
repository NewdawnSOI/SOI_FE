#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./regen_api.sh [--fetch-only] [--skip-pub-get] [--base-url <url>] [--path <path>]

Options:
  --fetch-only    Download the latest OpenAPI spec into api/openapi.yaml only.
  --skip-pub-get  Skip flutter pub get after generation.
  --base-url      Override the OpenAPI server base URL.
  --path          Override the preferred OpenAPI docs path.
  -h, --help      Show this help.

Environment:
  SOI_OPENAPI_BASE_URL   Default base URL. Falls back to https://newdawnsoi.site
  SOI_OPENAPI_PATH       Preferred docs path. Falls back to /v3/api-docs
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$SCRIPT_DIR/api"
SPEC_PATH="$API_DIR/openapi.yaml"
CONFIG_PATH="$API_DIR/config.yaml"
PATCH_SCRIPT="$API_DIR/patch_generated.sh"

BASE_URL="${SOI_OPENAPI_BASE_URL:-https://newdawnsoi.site}"
PREFERRED_PATH="${SOI_OPENAPI_PATH:-/v3/api-docs}"
FETCH_ONLY=0
SKIP_PUB_GET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fetch-only)
      FETCH_ONLY=1
      shift
      ;;
    --skip-pub-get)
      SKIP_PUB_GET=1
      shift
      ;;
    --base-url)
      BASE_URL="$2"
      shift 2
      ;;
    --path)
      PREFERRED_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

TMP_SPEC="$(mktemp)"
trap 'rm -f "$TMP_SPEC"' EXIT

add_candidate() {
  local candidate="$1"
  local existing
  for existing in "${DOC_PATHS[@]:-}"; do
    if [[ "$existing" == "$candidate" ]]; then
      return 0
    fi
  done
  DOC_PATHS+=("$candidate")
}

validate_spec() {
  local spec_file="$1"
  python3 - "$spec_file" <<'PY'
import json
import sys
from pathlib import Path

spec_path = Path(sys.argv[1])
data = json.loads(spec_path.read_text())
if not isinstance(data, dict) or "openapi" not in data or "paths" not in data:
    raise SystemExit("Downloaded document is not a valid OpenAPI JSON spec.")
PY
}

download_spec() {
  local url="$1"
  if ! curl --fail --silent --show-error --location "$url" -o "$TMP_SPEC"; then
    return 1
  fi
  validate_spec "$TMP_SPEC"
}

DOC_PATHS=()
add_candidate "$PREFERRED_PATH"
add_candidate "/v3/api-docs"
add_candidate "/openapi.json"
add_candidate "/api-docs"

SELECTED_URL=""
for path in "${DOC_PATHS[@]}"; do
  candidate_url="${BASE_URL%/}${path}"
  echo "Downloading OpenAPI spec from ${candidate_url}..."
  if download_spec "$candidate_url"; then
    SELECTED_URL="$candidate_url"
    break
  fi
done

if [[ -z "$SELECTED_URL" ]]; then
  echo "Failed to download a valid OpenAPI spec from ${BASE_URL}" >&2
  exit 1
fi

cp "$TMP_SPEC" "$SPEC_PATH"
echo "Updated ${SPEC_PATH} from ${SELECTED_URL}"

if [[ "$FETCH_ONLY" -eq 1 ]]; then
  echo "Fetch-only mode complete."
  exit 0
fi

echo "Generating Dart client from ${CONFIG_PATH}..."
(
  cd "$API_DIR"
  openapi-generator generate -c "$CONFIG_PATH"
  "$PATCH_SCRIPT"

  if [[ "$SKIP_PUB_GET" -eq 0 ]]; then
    cd generated
    flutter pub get
  fi
)

if [[ "$SKIP_PUB_GET" -eq 0 ]]; then
  (
    cd "$SCRIPT_DIR"
    flutter pub get
  )
fi

echo "Regeneration complete."
