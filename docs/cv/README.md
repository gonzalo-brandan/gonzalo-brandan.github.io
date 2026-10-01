# CV PDF

`assets/cv/Gonzalo-Brandan-CV.pdf` is generated from `cv-public.json` (the public version of career-ops `cv.md`: no phone, address or nationality).

To regenerate, from `~/Career/Automation-Tools/career-ops`:

    node build-cv-html.mjs <site>/docs/cv/cv-public.json /tmp/cv.html
    # then print /tmp/cv.html to A4 PDF with Playwright (0.6in margins)

Copy the PDF to `assets/cv/Gonzalo-Brandan-CV.pdf`.
