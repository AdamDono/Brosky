import os
import glob

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    original = content
    content = content.replace("GoogleFonts.inter(", "TextStyle(fontFamily: '.SF Pro Display', ")
    content = content.replace("GoogleFonts.poppins(", "TextStyle(fontFamily: '.SF Pro Display', ")
    content = content.replace("GoogleFonts.outfit(", "TextStyle(fontFamily: '.SF Pro Display', ")
    
    # Text themes
    content = content.replace("GoogleFonts.outfitTextTheme(ThemeData.light().textTheme)", "ThemeData.light().textTheme.apply(fontFamily: '.SF Pro Display')")
    content = content.replace("GoogleFonts.interTextTheme(ThemeData.light().textTheme)", "ThemeData.light().textTheme.apply(fontFamily: '.SF Pro Display')")
    content = content.replace("GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme)", "ThemeData.light().textTheme.apply(fontFamily: '.SF Pro Display')")

    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        print('Updated', filepath)

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
