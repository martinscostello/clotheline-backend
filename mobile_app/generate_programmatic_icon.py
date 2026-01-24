from PIL import Image, ImageDraw

def create_icon(output_path):
    # Dimensions and Colors
    size = 1024
    bg_color = (14, 165, 232) # #0EA5E8
    machine_color = (255, 255, 255)
    door_rim_color = (200, 200, 200)
    door_glass_color = (135, 206, 235) # Light blue like glass
    detail_color = (14, 165, 232)
    
    # Create canvas
    img = Image.new('RGB', (size, size), bg_color)
    draw = ImageDraw.Draw(img)
    
    # Calculate machine dimensions (Centered)
    margin = 150
    m_left = margin
    m_top = margin
    m_right = size - margin
    m_bottom = size - margin
    
    # Draw Washing Machine Body (Rounded Rectangle style)
    draw.rounded_rectangle([m_left, m_top, m_right, m_bottom], radius=60, fill=machine_color)
    
    # Draw Control Panel Area
    panel_height = 150
    draw.line([(m_left, m_top + panel_height), (m_right, m_top + panel_height)], fill=(230,230,230), width=5)
    
    # Draw a Knob
    knob_radius = 25
    knob_x = m_left + 100
    knob_y = m_top + 75
    draw.ellipse([knob_x - knob_radius, knob_y - knob_radius, knob_x + knob_radius, knob_y + knob_radius], fill=detail_color)
    
    # Draw Buttons
    btn_radius = 15
    for i in range(3):
        btn_x = m_left + 220 + (i * 50)
        btn_y = m_top + 75
        draw.ellipse([btn_x - btn_radius, btn_y - btn_radius, btn_x + btn_radius, btn_y + btn_radius], fill=(200, 200, 200))

    # Draw Door (Concentric circles)
    center_x = size // 2
    center_y = (m_top + panel_height + m_bottom) // 2
    
    door_radius = 220
    rim_width = 40
    
    # Rim
    draw.ellipse([center_x - door_radius, center_y - door_radius, center_x + door_radius, center_y + door_radius], fill=door_rim_color)
    
    # Glass
    glass_radius = door_radius - rim_width
    draw.ellipse([center_x - glass_radius, center_y - glass_radius, center_x + glass_radius, center_y + glass_radius], fill=door_glass_color)
    
    # Reflection on glass (simple arc or circle)
    ref_x = center_x + 50
    ref_y = center_y - 50
    ref_r = 30
    draw.ellipse([ref_x - ref_r, ref_y - ref_r, ref_x + ref_r, ref_y + ref_r], fill=(255, 255, 255, 128)) # Semi-transparent if possible, but mode is RGB.
    # Since mode is RGB, we use solid white relative to the glass color, or just light blue.
    draw.ellipse([ref_x - ref_r, ref_y - ref_r, ref_x + ref_r, ref_y + ref_r], fill=(200, 230, 255))

    # Bubbles / Stars (White circles around)
    bubbles = [
        (100, 200, 20), (900, 150, 25), (65, 800, 15), (950, 700, 30),
        (center_x, m_top - 60, 20)
    ]
    
    for bx, by, br in bubbles:
        draw.ellipse([bx - br, by - br, bx + br, by + br], fill=(255, 255, 255))
        
    img.save(output_path, quality=95)
    print(f"Generated clean icon at {output_path}")

if __name__ == "__main__":
    create_icon("assets/images/generated_icon.jpg")
