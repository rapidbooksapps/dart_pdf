import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:path_provider/path_provider.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;
import 'package:printing/printing.dart';

import 'document.dart';
import 'viewer.dart';

void main() => runApp(MaterialApp(home: MyApp()));

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() {
    return MyAppState();
  }
}

class MyAppState extends State<MyApp> {
  final GlobalKey<State<StatefulWidget>> shareWidget = GlobalKey();
  final GlobalKey<State<StatefulWidget>> pickWidget = GlobalKey();
  final GlobalKey<State<StatefulWidget>> previewContainer = GlobalKey();

  Printer selectedPrinter;

  Future<void> _printPdf() async {
    print('Print ...');
    final bool result = await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async =>
            (await generateDocument(format)).save());

    print('Document printed: $result');
  }

  Future<void> _saveAsFile() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String appDocPath = appDocDir.path;
    final File file = File(appDocPath + '/' + 'document.pdf');
    print('Save as file ${file.path} ...');
    await file.writeAsBytes((await generateDocument(PdfPageFormat.a4)).save());
    Navigator.push<dynamic>(
      context,
      MaterialPageRoute<dynamic>(
          builder: (BuildContext context) => PdfViewer(file: file)),
    );
  }

  Future<void> _pickPrinter() async {
    print('Pick printer ...');

    // Calculate the widget center for iPad sharing popup position
    final RenderBox referenceBox = pickWidget.currentContext.findRenderObject();
    final Offset topLeft =
        referenceBox.localToGlobal(referenceBox.paintBounds.topLeft);
    final Offset bottomRight =
        referenceBox.localToGlobal(referenceBox.paintBounds.bottomRight);
    final Rect bounds = Rect.fromPoints(topLeft, bottomRight);

    try {
      final Printer printer = await Printing.pickPrinter(bounds: bounds);
      print('Selected printer: $selectedPrinter');

      setState(() {
        selectedPrinter = printer;
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _directPrintPdf() async {
    print('Direct print ...');
    final bool result = await Printing.directPrintPdf(
        printer: selectedPrinter,
        onLayout: (PdfPageFormat format) async =>
            (await generateDocument(PdfPageFormat.letter)).save());

    print('Document printed: $result');
  }

  Future<void> _sharePdf() async {
    print('Share ...');
    final pdf.Document document = await generateDocument(PdfPageFormat.a4);

    // Calculate the widget center for iPad sharing popup position
    final RenderBox referenceBox =
        shareWidget.currentContext.findRenderObject();
    final Offset topLeft =
        referenceBox.localToGlobal(referenceBox.paintBounds.topLeft);
    final Offset bottomRight =
        referenceBox.localToGlobal(referenceBox.paintBounds.bottomRight);
    final Rect bounds = Rect.fromPoints(topLeft, bottomRight);

    await Printing.sharePdf(
        bytes: document.save(), filename: 'my-résumé.pdf', bounds: bounds);
  }

  Future<void> _printScreen() async {
    final RenderRepaintBoundary boundary =
        previewContainer.currentContext.findRenderObject();
    final ui.Image im = await boundary.toImage();
    final ByteData bytes =
        await im.toByteData(format: ui.ImageByteFormat.rawRgba);
    print('Print Screen ${im.width}x${im.height} ...');

    Printing.layoutPdf(onLayout: (PdfPageFormat format) {
      final pdf.Document document = pdf.Document();

      final PdfImage image = PdfImage(document.document,
          image: bytes.buffer.asUint8List(),
          width: im.width,
          height: im.height);

      document.addPage(pdf.Page(
          pageFormat: format,
          build: (pdf.Context context) {
            return pdf.Center(
              child: pdf.Expanded(
                child: pdf.Image(image),
              ),
            ); // Center
          })); // Page

      return document.save();
    });
  }

  Future<void> _printHtml() async {
    print('Print html ...');
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async {
      final String html = await rootBundle.loadString('assets/example.html');
      return await Printing.convertHtml(format: format, html: html);
    });
  }

  Future<void> _printMarkdown() async {
    print('Print Markdown ...');
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async {
      final String md = await rootBundle.loadString('assets/example.md');
      final String html = markdown.markdownToHtml(md,
          extensionSet: markdown.ExtensionSet.gitHubWeb);
      return await Printing.convertHtml(format: format, html: html);
    });
  }

  @override
  Widget build(BuildContext context) {
    bool canDebug = false;
    assert(() {
      canDebug = true;
      return true;
    }());
    return RepaintBoundary(
        key: previewContainer,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Pdf Printing Example'),
          ),
          body: RichText(
            textDirection: TextDirection.rtl,
            text: TextSpan(
              text: 'قهوة\n',
              style: TextStyle(
                fontFamily: 'arabic',
                color: Colors.black,
                fontSize: 60,
              ),
              children: const <TextSpan>[
                TextSpan(
                  text:
                      'القهوة مشروب يعد من بذور الب المحمصة، وينمو في أكثر من 70 لداً. خصوصاً في المناطق الاستوائية في أمريكا الشمالية والجنوبية وجنوب شرق آسيا وشبه القارة الهندية وأفريقيا. ويقال أن البن الأخضر هو ثاني أكثر السلع تداولاً في العالم بعد النفط الخام.',
                  style: TextStyle(
                    fontSize: 30,
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
