# UI typeface

NotoSansCJKsc-Bold.otf is the official Noto Sans CJK SC Bold face (weight 700), extracted from the installed NotoSansCJK-Bold.ttc SC face index 2 using fontTools. Its OFL/copyright notice is in NotoSansCJK-LICENSE.txt.

The 3.6 MB subset preserves the full GB2312 repertoire, ASCII/Latin/punctuation U+0020–02FF, and every character in this project's scripts, data, and tests. CFF outlines and shaping features remain intact. Unknown future characters fall back to the existing full NotoSansSC-Light.otf rather than displaying missing glyph boxes.

Regenerate with tools/subset_ui_font.py on a system with the official Noto CJK fonts and fontTools installed. This script extracts the SC Bold face and unions all current project text with GB2312 before subsetting. It does not rasterize or synthetically embolden fonts.
