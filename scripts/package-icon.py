"""Package standard PNG representations into an ICNS container."""
from pathlib import Path
from struct import pack

folder = Path("build/AppIcon.iconset")
representations = {
    b"icp4": "icon_16x16.png",
    b"icp5": "icon_32x32.png",
    b"icp6": "icon_32x32@2x.png",
    b"ic07": "icon_128x128.png",
    b"ic08": "icon_256x256.png",
    b"ic09": "icon_512x512.png",
    b"ic10": "icon_512x512@2x.png",
    b"ic11": "icon_16x16@2x.png",
    b"ic12": "icon_32x32@2x.png",
    b"ic13": "icon_128x128@2x.png",
    b"ic14": "icon_256x256@2x.png",
}
chunks = []
for tag, filename in representations.items():
    data = (folder / filename).read_bytes()
    chunks.append(tag + pack(">I", len(data) + 8) + data)
body = b"".join(chunks)
Path("build/AppIcon.icns").write_bytes(b"icns" + pack(">I", len(body) + 8) + body)
