from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path

W, H = 1600, 1000
OUT = Path(__file__).with_name("yalla-cash-app-preview.png")
REG = str(Path(__file__).parents[1] / "packages/yalla_cash_core/assets/fonts/Almarai-ExtraBold.ttf")
BOLD = REG
LATIN = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
MARK = Path(__file__).parents[1] / "packages/yalla_cash_core/assets/images/yalla_cash_mark.png"

NAVY = "#0E2A3B"
BLUE = "#1EA7E0"
BLUE2 = "#0B7EB0"
MUTED = "#667A86"
LINE = "#DFEAEE"
BG = "#F7FBFD"
GOLD = "#E7A93E"
GREEN = "#0E8C79"


def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else REG, size)


def txt(d, xy, value, size, color=NAVY, bold=False, anchor="ra", rtl=True):
    chosen_font = font(size, bold) if rtl else ImageFont.truetype(LATIN, size)
    d.text(xy, value, font=chosen_font, fill=color, anchor=anchor,
           direction="rtl" if rtl else "ltr", language="ar" if rtl else None)


def rr(d, box, radius, fill, outline=None, width=1):
    d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def paste_mark(base, box, color=None):
    x1, y1, x2, y2 = map(int, box)
    mark = Image.open(MARK).convert("RGBA")
    mark.thumbnail((x2-x1, y2-y1), Image.Resampling.LANCZOS)
    if color:
        tint = Image.new("RGBA", mark.size, color)
        tint.putalpha(mark.getchannel("A"))
        mark = tint
    px = x1 + (x2-x1-mark.width)//2
    py = y1 + (y2-y1-mark.height)//2
    base.alpha_composite(mark, (px, py))


def gradient_box(img, box, c1, c2, radius):
    x1, y1, x2, y2 = map(int, box)
    sw, sh = x2-x1, y2-y1
    grad = Image.new("RGB", (sw, sh))
    p = grad.load()
    a = tuple(int(c1[i:i+2], 16) for i in (1, 3, 5))
    b = tuple(int(c2[i:i+2], 16) for i in (1, 3, 5))
    for y in range(sh):
        for x in range(sw):
            t = (x/sw + y/sh)/2
            p[x, y] = tuple(int(a[i]*(1-t)+b[i]*t) for i in range(3))
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw-1, sh-1), radius=radius, fill=255)
    img.paste(grad, (x1, y1), mask)


def shadow(base, box, radius=30, blur=25, color=(0, 0, 0, 120), offset=(0, 15)):
    lay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    b = tuple(v + offset[i % 2] for i, v in enumerate(box))
    ImageDraw.Draw(lay).rounded_rectangle(b, radius=radius, fill=color)
    lay = lay.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(lay)


img = Image.new("RGBA", (W, H), "#071D2B")
# Background glows
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse((-220, -240, 430, 410), fill=(30, 167, 224, 82))
gd.ellipse((1230, 650, 1840, 1260), fill=(21, 105, 139, 70))
glow = glow.filter(ImageFilter.GaussianBlur(95))
img.alpha_composite(glow)
d = ImageDraw.Draw(img)

# Header
txt(d, (1555, 48), "معاينة واجهات يلا كاش", 31, "white", True)
txt(d, (1555, 87), "تطبيق الزبون  ·  تطبيق المحل  ·  لوحة التحكم", 14, "#ABC7D5")
paste_mark(img, (48, 35, 101, 91))
d = ImageDraw.Draw(img)
txt(d, (118, 47), "يلا كاش", 23, "white", True, anchor="la")
txt(d, (118, 80), "Flutter MVP · الواجهة الحالية", 11, "#7FA5B8", anchor="la", rtl=False)


def phone_shell(x, label):
    txt(d, (x+172, 125), label, 14, "#D8EEF9", True, anchor="ma")
    shadow(img, (x, 148, x+344, 958), 39, 27, (0, 0, 0, 135))
    rr(d, (x, 148, x+344, 958), 39, "#0A2535", "#315568", 1)
    rr(d, (x+10, 158, x+334, 948), 31, BG)
    rr(d, (x+118, 157, x+226, 180), 14, "#0A2535")
    # status bar
    d.rectangle((x+10, 180, x+334, 203), fill="white")
    txt(d, (x+29, 193), "9:41", 8, "#647680", anchor="lm", rtl=False)
    txt(d, (x+316, 193), "▮▮  ◔  100%", 8, "#647680", anchor="rm", rtl=False)
    return x+10, 203, x+334, 948


def appbar(sx1, sy, sx2, title, subtitle, symbol):
    d.rectangle((sx1, sy, sx2, sy+64), fill="white")
    d.line((sx1, sy+63, sx2, sy+63), fill="#EDF3F6", width=1)
    paste_mark(img, (sx2-51, sy+13, sx2-17, sy+51))
    txt(d, (sx2-59, sy+23), title, 15, BLUE2, True)
    txt(d, (sx2-59, sy+45), subtitle, 8, MUTED)
    rr(d, (sx1+15, sy+14, sx1+50, sy+49), 11, "#EAF6FC")
    txt(d, (sx1+32, sy+31), symbol, 16, BLUE2, anchor="mm", rtl=False)


def bottom_nav(sx1, sx2, y, active=0):
    d.rectangle((sx1, y, sx2, y+61), fill="white")
    d.line((sx1, y, sx2, y), fill=LINE)
    labels = [("⌂", "الرئيسية"), ("▦", "الكود"), ("▱", "المحفظة"), ("✦", "المكافآت")]
    cell = (sx2-sx1)/4
    for i, (sym, lab) in enumerate(labels):
        cx = sx2-cell*(i+.5)
        col = BLUE2 if i == active else "#70838E"
        txt(d, (cx, y+18), sym, 17, col, anchor="mm", rtl=False)
        txt(d, (cx, y+43), lab, 8, col, i == active, anchor="ma")


def store_card(x1, y, x2, name, cat, color, sym):
    rr(d, (x1, y, x2, y+60), 16, "white", "#E1EBEF")
    d.ellipse((x2-50, y+11, x2-12, y+49), fill=color)
    txt(d, (x2-31, y+30), sym, 16, "white", True, anchor="mm", rtl=False)
    txt(d, (x2-60, y+24), name, 12, NAVY, True)
    txt(d, (x2-60, y+44), cat, 8, MUTED)
    rr(d, (x1+12, y+19, x1+57, y+41), 11, "#EAF7F2")
    txt(d, (x1+34, y+29), "حصري", 8, "#14795E", True, anchor="ma")


# Customer phone
x = 48
sx1, sy, sx2, sb = phone_shell(x, "تطبيق الزبون")
appbar(sx1, sy, sx2, "يلا كاش", "مرحباً أحمد", "☰")
cx1, cx2 = sx1+15, sx2-15
gradient_box(img, (cx1, sy+77, cx2, sy+231), BLUE2, BLUE, 22)
d = ImageDraw.Draw(img)
d.ellipse((cx1+16, sy+94, cx1+56, sy+134), fill=GOLD)
paste_mark(img, (cx1+24, sy+100, cx1+48, sy+128), "#47320B")
d = ImageDraw.Draw(img)
txt(d, (cx2-20, sy+109), "رصيد النقاط", 12, "#D8F2FF")
txt(d, (cx2-20, sy+157), "2,860", 35, "white", True, rtl=False)
txt(d, (cx2-20, sy+192), "كل نقطة تعني قيمة وفر حقيقية", 9, "#D8F2FF")
txt(d, (cx2-2, sy+261), "المحلات الحصرية بمدينتك", 13, NAVY, True)
store_card(cx1, sy+275, cx2, "مطعم الوسيم", "مطاعم", BLUE2, "♨")
store_card(cx1, sy+343, cx2, "ماركت البركة", "سوبرماركت", GREEN, "▣")
store_card(cx1, sy+411, cx2, "كافيه الزاوية", "كافيهات", "#8A5A26", "♨")
store_card(cx1, sy+479, cx2, "صالون لمسة", "صالونات", "#C7447A", "✂")
bottom_nav(sx1, sx2, sb-61, 0)


# Merchant phone
x = 420
sx1, sy, sx2, sb = phone_shell(x, "تطبيق المحل")
appbar(sx1, sy, sx2, "يلا كاش للمحلات", "مطعم الوسيم", "↪")
cx1, cx2 = sx1+15, sx2-15
gap = 9
cardw = (cx2-cx1-gap)//2
for i, (value, label, sym) in enumerate([("1", "عدد المبيعات", "▤"), ("340,000", "قيمة المبيعات", "▱")]):
    bx1 = cx1+i*(cardw+gap)
    rr(d, (bx1, sy+77, bx1+cardw, sy+188), 18, "white", LINE)
    txt(d, (bx1+cardw-14, sy+102), sym, 18, BLUE2, anchor="ra", rtl=False)
    txt(d, (bx1+cardw-14, sy+145), value, 17, NAVY, True, rtl=False)
    txt(d, (bx1+cardw-14, sy+173), label, 8, MUTED)
gradient_box(img, (cx1, sy+198, cx2, sy+324), BLUE2, BLUE, 20)
d = ImageDraw.Draw(img)
txt(d, (cx2-16, sy+226), "◉", 19, "white", anchor="ra", rtl=False)
txt(d, (cx2-16, sy+270), "22,780 ل.س", 22, "white", True)
txt(d, (cx2-16, sy+302), "العمولة المستحقة · النسبة 6.7%", 9, "#DDF4FF")
txt(d, (cx2, sy+361), "آخر العمليات", 13, NAVY, True)
rr(d, (cx1, sy+376, cx2, sy+446), 17, "white", LINE)
d.ellipse((cx2-50, sy+392, cx2-14, sy+428), fill="#E5F6F0")
txt(d, (cx2-32, sy+410), "✓", 16, "#168260", True, anchor="mm", rtl=False)
txt(d, (cx2-60, sy+401), "340,000 ل.س", 11, NAVY, True)
txt(d, (cx2-60, sy+425), "15/08/2026 · cust-001", 7, MUTED, rtl=False)
txt(d, (cx1+12, sy+409), "22,780 ل.س", 9, BLUE2, True, anchor="la")
rr(d, (cx1, sb-78, cx2, sb-28), 14, BLUE2)
txt(d, ((cx1+cx2)//2, sb-53), "▦   بدء عملية جديدة", 11, "white", True, anchor="mm")


# Admin dashboard
ax, ay, aw, ah = 792, 148, 760, 810
txt(d, (ax+aw//2, 125), "لوحة تحكم الإدارة", 14, "#D8EEF9", True, anchor="ma")
shadow(img, (ax, ay, ax+aw, ay+ah), 25, 27, (0, 0, 0, 135))
rr(d, (ax, ay, ax+aw, ay+ah), 25, BG, "#315568")
d.rectangle((ax, ay, ax+aw, ay+66), fill="white")
d.line((ax, ay+65, ax+aw, ay+65), fill="#E6EEF2")
txt(d, (ax+aw-22, ay+34), "نظرة عامة", 17, NAVY, True)
for i, sym in enumerate(["☾", "↪"]):
    bx = ax+18+i*43
    rr(d, (bx, ay+16, bx+34, ay+50), 10, "#EDF7FB")
    txt(d, (bx+17, ay+33), sym, 15, BLUE2, anchor="mm", rtl=False)

sidew = 203
sx = ax+aw-sidew
d.rectangle((sx, ay+66, ax+aw, ay+ah), fill="white")
d.line((sx, ay+66, sx, ay+ah), fill="#DDE8ED")
d.ellipse((ax+aw-54, ay+87, ax+aw-17, ay+124), fill="#E8F6FC")
paste_mark(img, (ax+aw-51, ay+89, ax+aw-20, ay+122))
d = ImageDraw.Draw(img)
txt(d, (ax+aw-64, ay+98), "يلا كاش", 14, NAVY, True)
txt(d, (ax+aw-64, ay+119), "لوحة التحكم", 8, MUTED)
d.line((sx+12, ay+138, ax+aw-12, ay+138), fill="#EDF2F5")
menus = [("▦", "نظرة عامة"), ("▱", "طلبات الكاش"), ("♙", "المستخدمون"), ("▣", "المحلات"), ("✦", "المنتجات الرقمية"), ("♧", "حسابات المحلات"), ("▤", "التحاسب الشهري"), ("⚙", "الإعدادات")]
for i, (sym, lab) in enumerate(menus):
    my = ay+148+i*47
    if i == 0:
        rr(d, (sx+11, my, ax+aw-11, my+42), 11, "#DFF2FB")
    col = BLUE2 if i == 0 else "#5F7380"
    txt(d, (ax+aw-29, my+21), sym, 14, col, anchor="mm", rtl=False)
    txt(d, (ax+aw-50, my+21), lab, 9, col, i == 0, anchor="rm")

mx1, mx2 = ax+25, sx-25
txt(d, (mx2, ay+101), "نظرة عامة", 21, NAVY, True)
txt(d, (mx2, ay+132), "ملخص أداء منصة يلا كاش", 10, MUTED)
kpi_y = ay+154
kpi_gap = 11
kpi_w = (mx2-mx1-kpi_gap)//2
kpis = [
    ("2", "المستخدمون", "♙", "#E2F3FA", BLUE2),
    ("430,000 ل.س", "المبيعات المسجلة", "▤", "#E2F5F0", GREEN),
    ("14,990 ل.س", "دخل المنصة", "↗", "#EEEBFF", "#6755DB"),
    ("1", "طلبات كاش معلقة", "♢", "#FFF4DF", "#C6811E"),
]
for i, (value, label, sym, bg, col) in enumerate(kpis):
    row, column = divmod(i, 2)
    x1 = mx1+column*(kpi_w+kpi_gap)
    y1 = kpi_y+row*103
    rr(d, (x1, y1, x1+kpi_w, y1+92), 18, "white", LINE)
    d.ellipse((x1+kpi_w-58, y1+25, x1+kpi_w-18, y1+65), fill=bg)
    txt(d, (x1+kpi_w-38, y1+45), sym, 16, col, anchor="mm", rtl=False)
    txt(d, (x1+kpi_w-70, y1+38), value, 14, NAVY, True)
    txt(d, (x1+kpi_w-70, y1+62), label, 8, MUTED)

table_y = kpi_y+224
txt(d, (mx2, table_y), "آخر العمليات", 13, NAVY, True)
ty = table_y+17
rr(d, (mx1, ty, mx2, ty+127), 16, "white", LINE)
cols = [mx2-15, mx2-150, mx2-292, mx2-400]
for lab, px in zip(["المحل", "الفاتورة", "النقاط", "التاريخ"], cols):
    txt(d, (px, ty+24), lab, 8, "#496471", True)
d.line((mx1, ty+40, mx2, ty+40), fill="#EDF2F4")
rows = [("مطعم الوسيم", "340,000 ل.س", "+2,278", "15/08/2026"), ("كافيه الزاوية", "90,000 ل.س", "+720", "13/08/2026")]
for r, vals in enumerate(rows):
    yy = ty+64+r*42
    for j, (val, px) in enumerate(zip(vals, cols)):
        txt(d, (px, yy), val, 8, GREEN if j == 2 else NAVY, j == 2, rtl=j != 3)
    if r == 0:
        d.line((mx1, ty+84, mx2, ty+84), fill="#EDF2F4")

txt(d, (1554, 984), "البيانات المعروضة تجريبية ومضمّنة داخل المشروع", 10, "#6E94A8")
img.convert("RGB").save(OUT, quality=95)
print(OUT)
