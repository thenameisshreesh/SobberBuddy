import pypdfium2 as pdfium
from pathlib import Path

pdf = pdfium.PdfDocument(r"m:\me\Projects\SoberBuddyF\FinTech_Bank_Management_Pitch.pdf")
out = Path(r"m:\me\Projects\SoberBuddyF\_pitch_preview")
out.mkdir(exist_ok=True)
print("pages", len(pdf))
for i, page in enumerate(pdf):
    bitmap = page.render(scale=1.4)
    img = bitmap.to_pil()
    dest = out / f"page_{i+1}.png"
    img.save(dest)
    print(dest, img.size)
