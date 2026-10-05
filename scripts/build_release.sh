#!/usr/bin/env bash
#
# Builds the Flutter Release APK for Laundry Management with required Supabase configuration.
# In Release mode, SupabaseConfig strictly enforces compile-time environment variables
# (SUPABASE_URL_ROOT and SUPABASE_ANON_KEY) to prevent accidental fallback to development credentials (RISK-002).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${WORKSPACE_ROOT}"

SUPABASE_URL_ROOT="${SUPABASE_URL_ROOT:-${1:-}}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-${2:-}}"
DEFINE_FILE="${DEFINE_FILE:-}"

if [ -n "${DEFINE_FILE}" ]; then
  if [ ! -f "${DEFINE_FILE}" ]; then
    echo "Error: Define file not found: ${DEFINE_FILE}" >&2
    exit 1
  fi
  if grep -q "dyhfgnbhijukbdptreto" "${DEFINE_FILE}"; then
    echo "Safety check failed: Define file '${DEFINE_FILE}' targets the Development Supabase project ('dyhfgnbhijukbdptreto'). Release builds must target Production ('rvrskluqfbrkvvlxtxfp')." >&2
    exit 1
  fi
  if grep -E -q "<.*>|REPLACE_WITH_PRODUCTION_ANON_KEY" "${DEFINE_FILE}"; then
    echo "Safety check failed: Define file '${DEFINE_FILE}' contains unreplaced placeholders. Provide your actual Production Supabase anon key." >&2
    exit 1
  fi
  echo "Building release APK using define file: ${DEFINE_FILE}..."
  flutter build apk --release --dart-define-from-file="${DEFINE_FILE}"
else
  if [ -z "${SUPABASE_URL_ROOT}" ] || [ -z "${SUPABASE_ANON_KEY}" ]; then
    echo "Error: Missing required Supabase configuration for release build." >&2
    echo "In release mode, SupabaseConfig strictly forbids falling back to development credentials." >&2
    echo "" >&2
    echo "Usage:" >&2
    echo "  ./scripts/build_release.sh <SUPABASE_URL_ROOT> <SUPABASE_ANON_KEY>" >&2
    echo "Or set environment variables:" >&2
    echo "  export SUPABASE_URL_ROOT=\"https://rvrskluqfbrkvvlxtxfp.supabase.co\"" >&2
    echo "  export SUPABASE_ANON_KEY=\"<your-production-anon-key>\"" >&2
    echo "  ./scripts/build_release.sh" >&2
    echo "Or pass a define file:" >&2
    echo "  DEFINE_FILE=scripts/release_env.json ./scripts/build_release.sh" >&2
    exit 1
  fi

  if [[ "${SUPABASE_URL_ROOT}" == *"dyhfgnbhijukbdptreto"* ]]; then
    echo "Safety check failed: SUPABASE_URL_ROOT targets the Development Supabase project ('dyhfgnbhijukbdptreto'). Release builds must target Production ('rvrskluqfbrkvvlxtxfp')." >&2
    exit 1
  fi

  if [[ "${SUPABASE_ANON_KEY}" =~ \<.*> ]] || [[ "${SUPABASE_ANON_KEY}" == *"REPLACE_WITH_PRODUCTION_ANON_KEY"* ]]; then
    echo "Safety check failed: SUPABASE_ANON_KEY contains placeholder text. Provide your actual Production Supabase anon key." >&2
    exit 1
  fi

  echo "Building release APK with explicit --dart-define parameters..."
  flutter build apk --release \
    --dart-define="SUPABASE_URL_ROOT=${SUPABASE_URL_ROOT}" \
    --dart-define="SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"
fi

echo "Release APK build successful: build/app/outputs/flutter-apk/app-release.apk"
