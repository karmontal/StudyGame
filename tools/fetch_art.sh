#!/usr/bin/env bash
# Downloads the Higgsfield-generated reward pictures into assets/rewards/ (resized JPGs).
# The game uses every picture in that folder; without them it draws a simple landscape instead.
# Needs curl and python3 with Pillow (pip install pillow). CI runs this before building the APK.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets/rewards
base="https://d8j0ntlcm91z4.cloudfront.net/user_2zPmXEx9JaamGUwb4ZkXMQA3WpR"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fetch() {
	curl -fsSL -o "$tmp/src.png" "$base/$2"
	python3 -c "from PIL import Image; im = Image.open('$tmp/src.png').convert('RGB'); im.thumbnail((1280, 1280)); im.save('$1', quality=85)"
	echo "$1"
}
# Kids' reward pictures (16:9, gpt_image_2_5), revealed tile by tile during a quiz.
fetch assets/rewards/reward_00.jpg hf_20261010_162143_42a064c8-3d6d-4175-b8d7-81b4be85f750.png  # olive grove
fetch assets/rewards/reward_01.jpg hf_20261010_162143_5cf8fe88-9839-4721-bf1d-4b3d3f5dc944.png  # beach and boats
fetch assets/rewards/reward_02.jpg hf_20261010_162143_a570d3ee-7bb6-4ba8-b48e-25cf547a263a.png  # cat and puppy reading
fetch assets/rewards/reward_03.jpg hf_20261010_162144_cdbc8b35-4f3b-437f-984b-925336533382.png  # hot air balloon
fetch assets/rewards/reward_04.jpg hf_20261010_162145_29129a0a-dbd4-4ab5-a531-07566a255d69.png  # under the sea
fetch assets/rewards/reward_05.jpg hf_20261010_162143_47d003b9-c8da-4aa7-88f7-9aa75a4d9d64.png  # rocket and planets
fetch assets/rewards/reward_06.jpg hf_20261010_162142_5218cb5f-2217-40d1-be6e-ab3a925c51a8.png  # rabbits gardening
fetch assets/rewards/reward_07.jpg hf_20261010_162144_afb93c01-e0fb-4693-b62c-4df22159015a.png  # rainbow village and kites
fetch assets/rewards/reward_08.jpg hf_20261010_162144_23942e72-0c55-4e4e-8b14-baf7ef1093b0.png  # camels in the desert
fetch assets/rewards/reward_09.jpg hf_20261010_162142_6e83bc71-a3e1-408b-8325-f88dca21473d.png  # snowy forest owl
