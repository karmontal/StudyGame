#!/usr/bin/env bash
# Downloads the Higgsfield-generated reward pictures (assets/rewards/) and stickers (assets/stickers/).
# The game uses every picture in that folder; without them it draws a simple landscape instead.
# Needs curl and python3 with Pillow (pip install pillow). CI runs this before building the APK.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets/rewards
base="https://d8j0ntlcm91z4.cloudfront.net/user_2zPmXEx9JaamGUwb4ZkXMQA3WpR"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fetch() {  # out file, CDN name, max size
	curl -fsSL -o "$tmp/src.png" "$base/$2"
	python3 -c "from PIL import Image; im = Image.open('$tmp/src.png').convert('RGB'); im.thumbnail(($3, $3)); im.save('$1', quality=85)"
	echo "$1"
}
# Kids' reward pictures (16:9, gpt_image_2_5), revealed tile by tile during a quiz.
fetch assets/rewards/reward_00.jpg hf_20261010_162143_42a064c8-3d6d-4175-b8d7-81b4be85f750.png 1280  # olive grove
fetch assets/rewards/reward_01.jpg hf_20261010_162143_5cf8fe88-9839-4721-bf1d-4b3d3f5dc944.png 1280  # beach and boats
fetch assets/rewards/reward_02.jpg hf_20261010_162143_a570d3ee-7bb6-4ba8-b48e-25cf547a263a.png 1280  # cat and puppy reading
fetch assets/rewards/reward_03.jpg hf_20261010_162144_cdbc8b35-4f3b-437f-984b-925336533382.png 1280  # hot air balloon
fetch assets/rewards/reward_04.jpg hf_20261010_162145_29129a0a-dbd4-4ab5-a531-07566a255d69.png 1280  # under the sea
fetch assets/rewards/reward_05.jpg hf_20261010_162143_47d003b9-c8da-4aa7-88f7-9aa75a4d9d64.png 1280  # rocket and planets
fetch assets/rewards/reward_06.jpg hf_20261010_162142_5218cb5f-2217-40d1-be6e-ab3a925c51a8.png 1280  # rabbits gardening
fetch assets/rewards/reward_07.jpg hf_20261010_162144_afb93c01-e0fb-4693-b62c-4df22159015a.png 1280  # rainbow village and kites
fetch assets/rewards/reward_08.jpg hf_20261010_162144_23942e72-0c55-4e4e-8b14-baf7ef1093b0.png 1280  # camels in the desert
fetch assets/rewards/reward_09.jpg hf_20261010_162142_6e83bc71-a3e1-408b-8325-f88dca21473d.png 1280  # snowy forest owl

# Stickers for the album/shop (1:1, gpt_image_2_5), shown at 512px.
mkdir -p assets/stickers
fetch assets/stickers/lion.jpg hf_20261010_165323_30e12569-f948-47d3-b07c-573aab51c818.png 512
fetch assets/stickers/rocket.jpg hf_20261010_165324_7dadc9c4-f76f-4eb4-a282-56b130c2598a.png 512
fetch assets/stickers/owl.jpg hf_20261010_165323_6bb38d59-2ec9-4f8c-8c5e-3684d843eecf.png 512
fetch assets/stickers/turtle.jpg hf_20261010_165323_9af6c0ef-7d4f-4763-813a-96d4f97efb9a.png 512
fetch assets/stickers/dino.jpg hf_20261010_165322_deb3f134-b38a-4c79-b1a1-53013e9897ac.png 512
fetch assets/stickers/olive.jpg hf_20261010_165323_5d8d6ccb-9a01-4704-9570-5e45247a5c30.png 512
fetch assets/stickers/camel.jpg hf_20261010_165324_b9bfb72e-08ad-4f97-96c6-72a2b63e6156.png 512
fetch assets/stickers/dolphin.jpg hf_20261010_165324_fef5588f-93a6-4b36-8ab0-419bb38773b6.png 512
fetch assets/stickers/falcon.jpg hf_20261010_165322_a43808de-99f8-4eeb-9b35-c580e95f755c.png 512
fetch assets/stickers/flask.jpg hf_20261010_165322_9357133d-b541-4b6d-b943-d37be57fb93d.png 512
fetch assets/stickers/saturn.jpg hf_20261010_165322_2bce5259-a3ef-4d39-a0b8-f1c0c007234f.png 512
fetch assets/stickers/trophy.jpg hf_20261010_165324_d97a71b6-b0b9-4f85-b1f6-717bcf0fce3d.png 512

# App launcher icon (1:1, gpt_image_2_5): a smiling owl on a book. Android crops the adaptive
# foreground to a circle or squircle, so the subject sits in the middle of the picture.
# Other option: hf_20261011_053234_71aec26a-b7a2-4944-8b12-db8d1113c431.png (open book with a star).
mkdir -p assets/icon
curl -fsSL -o "$tmp/icon.png" "$base/hf_20261011_053235_8c69fbd7-f14f-4141-a109-8ceba028c11f.png"
python3 - "$tmp/icon.png" <<'PY'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
im.resize((512, 512), Image.LANCZOS).save("assets/icon/icon_512.png")
im.resize((432, 432), Image.LANCZOS).save("assets/icon/foreground_432.png")
# The adaptive background is the picture's own corner colour, so the edges blend in.
Image.new("RGB", (432, 432), im.getpixel((4, 4))).save("assets/icon/background_432.png")
PY
echo assets/icon
