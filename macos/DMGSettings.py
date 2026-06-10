app_path = defines["app_path"]
background_dir = defines["background_dir"]
icon_path = defines["icon_path"]

format = "UDRW"
filesystem = "HFS+"

files = [app_path, (background_dir, ".background")]
symlinks = {"Applications": "/Applications"}
icon = icon_path
hide = [".background"]

# Finder writes the final background reference natively after this image is mounted.
window_rect = ((120, 120), (720, 525))
default_view = "icon-view"
show_toolbar = False
show_status_bar = False
show_pathbar = False
show_sidebar = False

icon_size = 96
text_size = 12
label_pos = "bottom"
icon_locations = {
    "Szlauch.app": (180, 263),
    "Applications": (540, 263),
}
