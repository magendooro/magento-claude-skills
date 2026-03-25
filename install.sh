#!/usr/bin/env bash
# install.sh — Install Magento Claude Skills into Claude Code
#
# Usage:
#   ./install.sh              # Install to ~/.claude/skills/ (personal, all projects)
#   ./install.sh --project    # Install to ./.claude/skills/ (current project only)
#   ./install.sh --update     # Same as default, overwrites existing skills

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${REPO_DIR}/.claude/skills"

# Resolve install target
if [[ "${1:-}" == "--project" ]]; then
  TARGET_DIR="$(pwd)/.claude/skills"
  SCOPE="project"
else
  TARGET_DIR="${HOME}/.claude/skills"
  SCOPE="personal"
fi

echo "Magento Claude Skills installer"
echo "================================"
echo "Source : ${SOURCE_DIR}"
echo "Target : ${TARGET_DIR}"
echo "Scope  : ${SCOPE}"
echo ""

# Verify source exists
if [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "Error: skills directory not found at ${SOURCE_DIR}" >&2
  exit 1
fi

# Create target
mkdir -p "${TARGET_DIR}"

# Copy each skill
INSTALLED=0
UPDATED=0

for skill_path in "${SOURCE_DIR}"/*/; do
  skill_name="$(basename "${skill_path}")"
  target_skill="${TARGET_DIR}/${skill_name}"

  if [[ -d "${target_skill}" ]]; then
    rm -rf "${target_skill}"
    cp -r "${skill_path}" "${TARGET_DIR}/"
    echo "  updated  ${skill_name}"
    UPDATED=$((UPDATED + 1))
  else
    cp -r "${skill_path}" "${TARGET_DIR}/"
    echo "  installed ${skill_name}"
    INSTALLED=$((INSTALLED + 1))
  fi
done

echo ""
echo "Done — ${INSTALLED} installed, ${UPDATED} updated"
echo ""
echo "Next steps:"
echo ""
echo "  1. Set environment variables:"
echo "     export MAGENTO_BASE_URL=https://your-store.example.com"
echo "     export MAGENTO_ADMIN_TOKEN=your-integration-token"
echo ""
if [[ "${SCOPE}" == "personal" ]]; then
  echo "  2. Start Claude Code normally — skills are available in all projects."
else
  echo "  2. Start Claude Code in this project — skills are available in .claude/skills/."
fi
echo ""
echo "  3. Verify: ask Claude 'run /magento-connect check'"
echo ""
echo "Docs: https://github.com/magendooroo/magento-claude-skills"
