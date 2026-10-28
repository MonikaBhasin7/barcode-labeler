# Barcode Labeler

A Windows desktop app to design barcode labels and print them on sheets,
with the data coming from Excel. Built with Flutter. It is developed and
tested on a Mac, and installed on Windows.

## What it does

- **Sheet setup:** paper size, label size, margins, gaps, labels across and
  down, print order, and "fit as many as possible".
- **Designer:** rulers in cm/mm, drag to move, a corner handle to resize,
  arrow keys to nudge, undo/redo. Items: barcode, QR code, text, line, box,
  circle, picture.
- **Barcode types:** Code 128, Code 39, Code 93, EAN-13, EAN-8, UPC-A,
  UPC-E, Interleaved 2 of 5, ITF-14, Codabar, QR code, Data Matrix, PDF417.
- **Where a value comes from:** fixed text, an Excel column, a serial
  number (start, step, repeat, zero padding, count down), a date (with
  "add days"), a value typed when printing, several of these joined
  together, or the same value as another item. Text can be added before
  and after.
- **Fonts:** 9 fonts ship with the app (Roboto, Roboto Condensed, Roboto
  Mono, Lato, Montserrat, Libre Franklin, Rubik, Work Sans, and Tinos,
  which looks like Times New Roman), each with
  normal and bold, plus a text size. They are embedded in the PDF, so a
  label looks the same on every computer. Licences:
  `assets/fonts/FONT_LICENSES.txt`.
- **Units:** mm, cm or inches (Settings). Designs are always stored in mm.
- **Excel:** `.xlsx` and `.csv`, read in the background. Formula cells show
  their result, and number and date formats (`000123`, `"LOT-"000`,
  `#,##0`, `12.50`, `d-mmm-yy`) show as Excel shows them. Rows hidden by a
  filter are left out. Row numbers are Excel's own. Old `.xls` files must
  be saved as `.xlsx` first.
- **Print:** all rows, a from–to range, or picked rows; copies; start
  position on a half-used sheet; the printer. Preview, print, or save as
  PDF. Before printing it checks barcode values, text that is too long for
  its box, letters the font cannot print, and unanswered questions. Serial
  numbers carry on from the last print (shared by copies of a design made
  with Save as). The Excel file is read again if it changed. A per-printer
  shift fixes printers that print a little off. A test sheet prints the
  label outlines and a 100 mm line.
- **Windows:** one copy of the app runs at a time, so two windows cannot
  print the same serial numbers. Double-clicking a `.labeldesign` file
  opens it.

Designs are saved as `.labeldesign` files (JSON). Pictures are stored
inside the file.

## Run on a Mac

```bash
flutter run -d macos
```

## Windows installer

Every push to `main` runs `.github/workflows/windows-build.yml` on a
Windows machine. It runs the tests, builds the app, adds the Visual C++
runtime files, and builds `BarcodeLabelerSetup-<version>.exe` with Inno
Setup (`installer/barcode_labeler.iss`). Download it from the run's
**Artifacts**. The installer does not need admin rights.

## Tests

```bash
flutter test
```
