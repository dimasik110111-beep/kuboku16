#!/usr/bin/env python3
"""Prepare Android launcher icons using the official FHR tournament asset."""
from io import BytesIO
from pathlib import Path
import urllib.request
from PIL import Image, ImageOps

SOURCE="https://img.fhr.ru/tournaments/b6/ef/25008909.webp"
req=urllib.request.Request(SOURCE,headers={"User-Agent":"JUNIOR-U16-Android/1.0","Accept":"image/webp,image/*"})
with urllib.request.urlopen(req,timeout=30) as response:
    data=response.read(2_000_000)
if len(data)<100 or len(data)>1_000_000:
    raise RuntimeError("Official FHR logo returned invalid image size")
with Image.open(BytesIO(data)) as src:
    if src.format!="WEBP":
        raise RuntimeError("FHR tournament image is not the expected WebP")
    logo=src.convert("RGBA")
    print("FHR tournament logo",logo.size,"original bytes",len(data),flush=True)
    if logo.width < 48 or logo.height < 48:
        raise RuntimeError("FHR logo source is too small")
    for density,side in {"mdpi":48,"hdpi":72,"xhdpi":96,"xxhdpi":144,"xxxhdpi":192}.items():
        canvas=Image.new("RGBA",(side,side),(17,20,27,255))
        max_dim=int(side*0.87)
        art=ImageOps.contain(logo,(max_dim,max_dim),Image.Resampling.LANCZOS)
        canvas.alpha_composite(art,((side-art.width)//2,(side-art.height)//2))
        path=Path(f"android/app/src/main/res/mipmap-{density}/ic_launcher.png")
        path.parent.mkdir(parents=True,exist_ok=True)
        canvas.convert("RGB").save(path,format="PNG")
        print("Prepared",path,flush=True)
