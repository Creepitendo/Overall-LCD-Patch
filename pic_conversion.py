import numpy as np
import json
from PIL import Image

def rgb888_to_rgb565(red:np.uint16, green:np.uint16, blue:np.uint16) -> np.uint16:
    red_rgb_565 = (red >> 3) & 0b00011111
    green_rgb_565 = (green >> 2) & 0b00111111
    blue_rgb_565 = (blue >> 3) & 0b00011111
    return (red_rgb_565 << 11) | (green_rgb_565 << 5) | (blue_rgb_565)

def rgb888_to_rgb666(red:np.uint16, green:np.uint16, blue:np.uint16) -> np.uint16:
    red_rgb_666 = (red >> 2) & 0b00111111
    green_rgb_666 = (green >> 2) & 0b00111111
    blue_rgb_666 = (blue >> 2) & 0b00111111
    return (red_rgb_666 << 12) | (green_rgb_666 << 6) | (blue_rgb_666)

img = Image.open("bild.jpg")

neue_breite = 190 
neue_höhe = 190

resized_img = img.resize((neue_breite, neue_höhe))

resized_img.save("bild_resized.jpg")

bitmap_rgb = np.array(resized_img)
print(bitmap_rgb.shape[0], bitmap_rgb.shape[1], bitmap_rgb.shape[2])

bitmap_rgb_565 = np.zeros(bitmap_rgb.shape[0] * bitmap_rgb.shape[1], dtype=np.uint16)

i = 0
for r, row in enumerate(bitmap_rgb):
    for c, column in enumerate(row):
        red, green, blue = column
        val:np.uint16 = rgb888_to_rgb565(np.uint16(red), np.uint16(green), np.uint16(blue))
        bitmap_rgb_565[i] = val
        i+=1

print("RGB_888: ", bitmap_rgb[0][0][0], " ", bitmap_rgb[0][0][1], " ", bitmap_rgb[0][0][2])
red_rgb_565 = (np.uint16(bitmap_rgb[0][0][0]) >> 3) & 0b00011111
green_rgb_565 = (np.uint16(bitmap_rgb[0][0][1]) >> 2) & 0b00111111
blue_rgb_565 = (np.uint16(bitmap_rgb[0][0][2]) >> 3) & 0b00011111
print("RGB_565: ", red_rgb_565, " ", green_rgb_565, " ", blue_rgb_565)
print("RGB_565: ", rgb888_to_rgb565(np.uint16(bitmap_rgb[0][0][0]), np.uint16(bitmap_rgb[0][0][1]), np.uint16(bitmap_rgb[0][0][2])))

with open("bitmap.json", "w") as f:
    json.dump(bitmap_rgb_565.tolist(), f)








def rgb565_to_rgb888(rgb565):
    # Extrahiere die Farbbits
    r = (rgb565 >> 11) & 0x1F
    g = (rgb565 >> 5) & 0x3F
    b = rgb565 & 0x1F

    # Skaliere auf 0-255
    r = (r << 3) | (r >> 2)
    g = (g << 2) | (g >> 4)
    b = (b << 3) | (b >> 2)

    return (r, g, b)


# Konvertiere alle Werte
rgb888_list = [rgb565_to_rgb888(val) for val in bitmap_rgb_565]

# Erstelle das Bild
img = Image.new("RGB", (neue_breite, neue_höhe))
img.putdata(rgb888_list)

# Bild anzeigen oder speichern
img.save("bild.png")