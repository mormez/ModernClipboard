import sys
from PIL import Image, ImageDraw, ImageFont

# Render the dmg background at a given scale. Window is WIN_W x WIN_H points.
# Rendered at 1x and 2x; a multi-rep TIFF is built from both so Finder shows the
# right one and sizing matches the window in POINTS.
WIN_W, WIN_H = 600, 460
ICON_Y = 205          # vertical center of the app / Applications icons
TITLE_Y = 74
INSTRUCT_Y = 360      # sits a little higher in the window

S = int(sys.argv[1])  # 1 or 2
out = sys.argv[2]
W, H = WIN_W * S, WIN_H * S

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

# Title
center_text("Modern Clipboard", TITLE_Y, font(34), DARK)

# Icons at (150, ICON_Y) and (450, ICON_Y), 128pt. Arrow centered in the gap,
# drawn as a single balanced shape so the stem flows smoothly into the head.
ay = ICON_Y * S
x_start, x_tip = 238 * S, 362 * S   # length ~124pt, centered at x=300
st = 11 * S                          # stem half-thickness (22pt thick)
hh = 26 * S                          # head half-height (52pt tall)
hl = 34 * S                          # head length
d.polygon([
    (x_start, ay - st),
    (x_tip - hl, ay - st),
    (x_tip - hl, ay - hh),
    (x_tip, ay),
    (x_tip - hl, ay + hh),
    (x_tip - hl, ay + st),
    (x_start, ay + st),
], fill=ACCENT)

# Instruction near the bottom
center_text("Drag the app onto the Applications folder to install", INSTRUCT_Y, font(17), GRAY)

img.save(out)
print("wrote", out, img.size)
