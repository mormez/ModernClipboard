import sys
from PIL import Image, ImageDraw, ImageFont

# Render the dmg background at a given scale. Window is 600x400 points.
# We render at 1x (600x400) and 2x (1200x800); a multi-rep TIFF is built from
# both so Finder shows the right one and sizing matches the window in POINTS.
S = int(sys.argv[1])          # 1 or 2
out = sys.argv[2]
W, H = 600 * S, 400 * S

img = Image.new("RGB", (W, H), "#ffffff")
px = img.load()
top, bot = (251, 251, 253), (235, 238, 243)
for y in range(H):
    t = y / (H - 1)
    c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
    for x in range(W):
        px[x, y] = c

d = ImageDraw.Draw(img)
SF = "/System/Library/Fonts/SFNS.ttf"
def font(sz):
    try: return ImageFont.truetype(SF, sz * S)
    except: return ImageFont.load_default()

def center_text(text, cy, fnt, fill):
    bb = d.textbbox((0, 0), text, font=fnt)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    d.text(((W - w) / 2, cy * S - h / 2 - bb[1]), text, font=fnt, fill=fill)

ACCENT = (91, 91, 214)
DARK = (29, 29, 31)
GRAY = (110, 110, 115)

# Title (1x point coords)
center_text("Modern Clipboard", 70, font(34), DARK)

# Icons at (150,200) and (450,200), 128pt. Arrow centered in the gap, same y.
ay = 200 * S
x0, x1 = 245 * S, 340 * S       # shaft
sh = 13 * S
d.rounded_rectangle([x0, ay - sh // 2, x1, ay + sh // 2], radius=sh // 2, fill=ACCENT)
head = 29 * S
d.polygon([(x1, ay - head), (x1 + head + 5 * S, ay), (x1, ay + head)], fill=ACCENT)

# Instruction near the bottom
center_text("Drag the app onto the Applications folder to install", 335, font(17), GRAY)

img.save(out)
print("wrote", out, img.size)
