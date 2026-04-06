#!/usr/bin/env python3
"""
Generate Material 3 adaptive app icons for the Vibes app.
Creates icons with the purple/pink gradient theme.
"""

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math
import os

# App colors matching the Flutter theme
PRIMARY = (224, 64, 251)      # #E040FB
SECONDARY = (124, 77, 255)    # #7C4DFF
ACCENT = (0, 229, 255)        # #00E5FF
BACKGROUND = (10, 10, 15)     # #0A0A0F
SURFACE = (26, 26, 46)        # #1A1A2E

def create_gradient(size, color1, color2, direction='diagonal'):
    """Create a gradient image."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    for y in range(size):
        for x in range(size):
            if direction == 'diagonal':
                ratio = (x + y) / (2 * size)
            elif direction == 'vertical':
                ratio = y / size
            else:
                ratio = x / size
            
            r = int(color1[0] * (1 - ratio) + color2[0] * ratio)
            g = int(color1[1] * (1 - ratio) + color2[1] * ratio)
            b = int(color1[2] * (1 - ratio) + color2[2] * ratio)
            
            draw.point((x, y), fill=(r, g, b, 255))
    
    return img


def create_play_icon(size, color=(255, 255, 255)):
    """Create a play button triangle."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Calculate play triangle points (centered, slightly offset right)
    margin = size * 0.25
    offset = size * 0.05  # Slight right offset for visual balance
    
    points = [
        (margin + offset, margin),           # Top left
        (margin + offset, size - margin),    # Bottom left
        (size - margin + offset, size / 2),  # Right point
    ]
    
    draw.polygon(points, fill=color)
    return img


def create_rounded_rect_mask(size, radius):
    """Create a rounded rectangle mask."""
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def create_circle_mask(size):
    """Create a circular mask."""
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse([0, 0, size - 1, size - 1], fill=255)
    return mask


def add_glow(img, color, radius=20, intensity=0.5):
    """Add a glow effect around the image."""
    # Create glow layer
    glow = Image.new('RGBA', img.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    
    # Draw colored background for glow
    glow_draw.rectangle([0, 0, img.size[0], img.size[1]], 
                        fill=(color[0], color[1], color[2], int(255 * intensity)))
    
    # Blur it
    glow = glow.filter(ImageFilter.GaussianBlur(radius))
    
    # Composite with original
    result = Image.alpha_composite(glow, img)
    return result


def create_app_icon(size, include_background=True):
    """Create the main app icon."""
    # Create base with gradient background
    if include_background:
        base = create_gradient(size, SURFACE, BACKGROUND, 'diagonal')
    else:
        base = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    
    # Create gradient overlay circle
    circle_size = int(size * 0.7)
    circle_offset = (size - circle_size) // 2
    
    gradient_circle = create_gradient(circle_size, PRIMARY, SECONDARY, 'diagonal')
    circle_mask = create_circle_mask(circle_size)
    
    # Apply circular mask to gradient
    gradient_circle.putalpha(circle_mask)
    
    # Paste circle onto base
    base.paste(gradient_circle, (circle_offset, circle_offset), gradient_circle)
    
    # Add play icon
    play_size = int(size * 0.35)
    play_offset = (size - play_size) // 2
    play_icon = create_play_icon(play_size, (255, 255, 255))
    
    base.paste(play_icon, (play_offset + int(size * 0.02), play_offset), play_icon)
    
    return base


def create_adaptive_foreground(size):
    """Create the adaptive icon foreground (the main design)."""
    # Adaptive icons need safe zone - use 66% of the icon for content
    safe_zone = int(size * 0.66)
    offset = (size - safe_zone) // 2
    
    # Create transparent base
    base = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    
    # Create the icon content
    content = create_app_icon(safe_zone, include_background=False)
    
    # Paste centered
    base.paste(content, (offset, offset), content)
    
    return base


def create_adaptive_background(size):
    """Create the adaptive icon background (gradient)."""
    return create_gradient(size, SURFACE, BACKGROUND, 'diagonal')


def create_monochrome_icon(size):
    """Create a monochrome version for Material You theming."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Circle
    circle_margin = int(size * 0.15)
    draw.ellipse([circle_margin, circle_margin, 
                  size - circle_margin, size - circle_margin], 
                 fill=(255, 255, 255, 255))
    
    # Play icon (cut out - we'll use transparency)
    play_size = int(size * 0.35)
    play_offset = (size - play_size) // 2
    
    margin = play_size * 0.25
    offset_x = play_size * 0.05
    
    points = [
        (play_offset + margin + offset_x, play_offset + margin),
        (play_offset + margin + offset_x, play_offset + play_size - margin),
        (play_offset + play_size - margin + offset_x, play_offset + play_size / 2),
    ]
    
    # Draw play icon in a darker shade (will be themed by system)
    draw.polygon(points, fill=(0, 0, 0, 0))
    
    return img


def create_splash_icon(size):
    """Create a splash/launch screen icon."""
    base = Image.new('RGBA', (size, size), BACKGROUND + (255,))
    
    icon_size = int(size * 0.4)
    icon = create_app_icon(icon_size, include_background=False)
    
    offset = (size - icon_size) // 2
    base.paste(icon, (offset, offset), icon)
    
    return base


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    assets_dir = os.path.join(project_dir, 'assets', 'icons')
    
    os.makedirs(assets_dir, exist_ok=True)
    
    print("Generating Material 3 app icons...")
    
    # Main app icon (1024x1024 for best quality)
    print("  - app_icon.png (1024x1024)")
    icon = create_app_icon(1024)
    icon.save(os.path.join(assets_dir, 'app_icon.png'))
    
    # Adaptive icon foreground
    print("  - ic_launcher_foreground.png (1024x1024)")
    foreground = create_adaptive_foreground(1024)
    foreground.save(os.path.join(assets_dir, 'ic_launcher_foreground.png'))
    
    # Adaptive icon background
    print("  - ic_launcher_background.png (1024x1024)")
    background = create_adaptive_background(1024)
    background.save(os.path.join(assets_dir, 'ic_launcher_background.png'))
    
    # Monochrome icon for Material You
    print("  - ic_launcher_monochrome.png (1024x1024)")
    mono = create_monochrome_icon(1024)
    mono.save(os.path.join(assets_dir, 'ic_launcher_monochrome.png'))
    
    # Splash icon
    print("  - splash_icon.png (1024x1024)")
    splash = create_splash_icon(1024)
    splash.save(os.path.join(assets_dir, 'splash_icon.png'))
    
    # Notification icon (white on transparent)
    print("  - notification_icon.png (96x96)")
    notif = create_monochrome_icon(96)
    notif.save(os.path.join(assets_dir, 'notification_icon.png'))
    
    # Web favicon sizes
    for size in [16, 32, 48, 64, 128, 192, 512]:
        print(f"  - favicon_{size}.png")
        favicon = create_app_icon(size)
        favicon.save(os.path.join(assets_dir, f'favicon_{size}.png'))
    
    print(f"\nAll icons saved to: {assets_dir}")
    print("\nNext steps:")
    print("  1. Update pubspec.yaml with flutter_launcher_icons config")
    print("  2. Run: flutter pub run flutter_launcher_icons")


if __name__ == '__main__':
    main()
