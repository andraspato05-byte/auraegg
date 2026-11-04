#!/usr/bin/env bash
# Full check of Steal the Aura Egg. Run it before every commit:
#
#   tools/check.sh          generate -> lint -> API check -> build -> tests
#   tools/check.sh --ci     same, and fail if generated files weren't committed
#   tools/check.sh --models also rebuild the Blender animals (needs: pip install bpy)
#
# Needs: python3, rojo, selene, lune (see aftman.toml / tools/install_tools.sh)
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$PWD/.tools/bin:$HOME/.cargo/bin:$PATH"

CI=0
MODELS=0
for arg in "$@"; do
	case "$arg" in
		--ci) CI=1 ;;
		--models) MODELS=1 ;;
		*) echo "unknown option: $arg"; exit 2 ;;
	esac
done

step() { printf '\n\033[1;35m==> %s\033[0m\n' "$1"; }

for tool in python3 rojo selene lune; do
	command -v "$tool" >/dev/null || { echo "missing tool: $tool (see docs/WORKFLOW.md)"; exit 1; }
done

step "1/6 Generate the map and GUI"
python3 tools/generate_map.py
python3 tools/generate_gui.py
if [[ "$MODELS" == 1 ]]; then
	python tools/generate_pets.py
fi

step "2/6 Generated files are up to date"
if [[ "$CI" == 1 ]]; then
	if ! git diff --exit-code --stat -- map gui src/server/PetShapes.luau; then
		echo "Generated files differ from the generators. Run tools/check.sh locally and commit the result."
		exit 1
	fi
	echo "ok"
else
	echo "skipped (only checked with --ci)"
fi

step "3/6 Lint (selene)"
selene src

step "4/6 Roblox API check"
python3 tools/check_api.py

step "5/6 Build the place (rojo)"
rojo build default.project.json -o StealTheAuraEgg.rbxlx

step "6/6 Automated tests (lune)"
lune run tests/run.luau

printf '\n\033[1;32mAll checks passed. StealTheAuraEgg.rbxlx is ready to open in Studio.\033[0m\n'
