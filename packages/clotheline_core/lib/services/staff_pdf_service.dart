import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';

class StaffPdfService {
  static Future<Uint8List> generatePaySlip({
    required Staff staff,
    required Branch branch,
    required StaffPayment payment,
  }) async {
    final pdf = pw.Document();
    final isAbuja = branch.name.toLowerCase().contains('abuja');
    final companyName = isAbuja ? 'Brimarck Cleaning Services' : 'Clotheline Services';
    final ceoName = isAbuja ? 'Mrs Natalie Usigbe Izuwagbe' : 'Mr Martins Usigbe';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(companyName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text("PAY SLIP", style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Staff Name: ${staff.name}"),
                      pw.Text("Staff ID: ${staff.staffId}"),
                      pw.Text("Position: ${staff.position}"),
                      pw.Text("Branch: ${branch.name}"),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Date: ${DateFormat('MMMM dd, yyyy').format(payment.date)}"),
                      pw.Text("Ref: ${payment.reference ?? 'N/A'}"),
                    ],
                  ),
                ],
              ),
              pw.Divider(height: 40),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Description", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Amount (NGN)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Basic Salary (${DateFormat('MMMM yyyy').format(payment.date)})")),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(NumberFormat.currency(symbol: '', decimalDigits: 0).format(payment.amount))),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text("Total Paid: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text("NGN ${NumberFormat.currency(symbol: '', decimalDigits: 0).format(payment.amount)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                ],
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Approved By:"),
                      pw.SizedBox(height: 10),
                      pw.Text(ceoName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text("MD/CEO"),
                    ],
                  ),
                  pw.Text("This is an electronically generated pay slip."),
                ],
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> generateAgreement({
    required Staff staff,
    required Branch branch,
    required String signingDate,
  }) async {
    final pdf = pw.Document();
    final isAbuja = branch.name.toLowerCase().contains('abuja');
    final companyName = isAbuja ? 'Brimarck Cleaning Services' : 'Clotheline Services';
    final ceoName = isAbuja ? 'Mrs Natalie Usigbe Izuwagbe' : 'Mr Martins Usigbe';
    final commencementDate = DateFormat('dd MMMM yyyy').format(staff.employmentDate);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Center(child: pw.Text(companyName.toUpperCase(), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 20),
            pw.Text(staff.name),
            pw.Text(staff.address ?? ""),
            pw.SizedBox(height: 20),
            pw.Text("Dear Mr/Mrs ${staff.name}"),
            pw.SizedBox(height: 5),
            pw.Center(child: pw.Text("CONTRACT AGREEMENT", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 10),
            pw.Text("We are pleased to offer you a contract as a ${staff.position} at $companyName. effective from $signingDate. You will be reporting directly to the management;"),
            pw.SizedBox(height: 10),
            pw.Text("Your key responsibilities will include:"),
            pw.Bullet(text: "Washing, drying, ironing, and folding clothes, linens, and other items as assigned."),
            pw.Bullet(text: "Ensuring proper use and care of laundry machines, detergents, and equipment."),
            pw.Bullet(text: "Maintaining cleanliness and orderliness in the laundry area."),
            pw.Bullet(text: "Assisting in any other related duties as may be reasonably assigned."),
            pw.SizedBox(height: 10),
            pw.Text("1) Your commencement date takes effect from $commencementDate."),
            pw.SizedBox(height: 5),
            pw.Text("2) Your accrued income will be a total sum of #720,000 per annum, payable at the end of each month, tax and other statutory deduction will be done at the source."),
            pw.SizedBox(height: 5),
            pw.Text("3) You will be on probation for a period of 3 months which will be subject to confirmation based on performance."),
            pw.SizedBox(height: 5),
            pw.Text("4) Your working days will be from monday to saturday, 8am to 6pm with an hour break."),
            pw.SizedBox(height: 5),
            pw.Text("5) A sum of N2,000 (Two Thousand Naira) will be deducted from your monthly salary. This amount will be refunded to you upon resignation only if you provide a minimum of 30 days written notice before leaving the company. However, this refund will not be given if You leave the company without giving the required 30 days’ notice, OR If your employment is terminated by the company for misconduct or non-performance."),
            pw.SizedBox(height: 5),
            pw.Text("6) You are required to give the company a minimum of 30 days’ written notice before resigning from your position. If you fail to provide the required 30 days’ notice, you will forfeit: The N2,000 refund, and Your salary for that month. The company reserves the right to terminate your employment at any time, in accordance with its policies and procedures."),
            pw.SizedBox(height: 5),
            pw.Text("7) Your work in the organization will be subjected to the rules and regulation of the organization as laid down in relations to conduct, discipline and other matters. you will always be alive to responsibilities and duties attached to your office and conduct yourself accordingly. you must effectively perform to ensure result."),
            pw.SizedBox(height: 5),
            pw.Text("8) During the period of your contract, you will have to maintain complete confidentiality about clients and the company. No confidential information shall be shared with anyone from outside your team or department sharing of confidential information outside the company will be considerd as a criminal offense."),
            pw.SizedBox(height: 20),
            pw.Text("Please confirm your acceptance of this contract by signing and returning the duplicate copy of this letter."),
            pw.SizedBox(height: 10),
            pw.Text("We look forward to a mutually beneficial working relationship."),
            pw.SizedBox(height: 20),
            pw.Text("Sincerely,"),
            pw.SizedBox(height: 10),
            pw.Text(ceoName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text("MD/CEO"),
            pw.Text(companyName),
            pw.SizedBox(height: 40),
            pw.Text("Acknowledgement & Acceptance", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text("I, ${staff.name}, have read and understood the terms of this contract and accept the position of a ${staff.position} under the conditions stated above."),
            pw.SizedBox(height: 10),
            pw.Text("Date: $signingDate"),
            pw.SizedBox(height: 20),
            if (staff.signature != null) ...[
               pw.Text("Signature:"),
               pw.SizedBox(height: 5),
               // We'll need to embed the signature image if it exists
               // For now, placeholder or name text
               pw.Text("${staff.name}", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 20)),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateIDCard({
    required Staff staff,
    required Branch branch,
  }) async {
    final pdf = pw.Document();
    final isAbuja = branch.name.toLowerCase().contains('abuja');
    final companyName = isAbuja ? 'Brimarck Cleaning Services' : 'Clotheline Services';
    
    // Colors
    final deepBlue = PdfColor.fromHex('#1A237E');
    final accentBlue = PdfColor.fromHex('#283593');
    
    // Load Images
    pw.ImageProvider? passportImage;
    if (staff.passportPhoto != null) {
      try { passportImage = await networkImage(staff.passportPhoto!); } catch (_) {}
    }

    pw.ImageProvider? signatureImage;
    if (staff.signature != null) {
      try { signatureImage = await networkImage(staff.signature!); } catch (_) {}
    }

    final format = PdfPageFormat(86 * PdfPageFormat.mm, 54 * PdfPageFormat.mm);
    final joinDate = DateFormat('dd.MM.yyyy').format(staff.employmentDate);
    final expireDate = DateFormat('dd.MM.yyyy').format(staff.employmentDate.add(const Duration(days: 365 * 2)));

    // PAGE 1: FRONT SIDE
    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // White Base
              pw.FullPage(ignoreMargins: true, child: pw.Container(color: PdfColors.white)),
              
              // Left Dark Geometric Section
              pw.Positioned(
                left: 0, top: 0, bottom: 0,
                width: format.width * 0.35,
                child: pw.Stack(
                  children: [
                    pw.Container(color: PdfColor.fromHex('#121212')),
                    pw.Positioned(
                      right: -20, top: 0, bottom: 0,
                      child: pw.Transform.rotate(
                        angle: 0.2,
                        child: pw.Container(width: 40, color: PdfColor.fromHex('#121212')),
                      ),
                    ),
                  ],
                ),
              ),

              // Vertical Dates Labels
              pw.Positioned(
                left: 8, bottom: 12,
                child: pw.Transform.rotate(
                  angle: 3.14159 / 2, // 90 degrees
                  child: pw.Row(
                    children: [
                      pw.Text("JOIN DATE: $joinDate", style: pw.TextStyle(color: PdfColors.white, fontSize: 5, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(width: 15),
                      pw.Text("EXPIRE DATE: $expireDate", style: pw.TextStyle(color: PdfColors.white, fontSize: 5, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
              ),

              // Geometric Photo Frame (Hexagon/Shield)
              pw.Positioned(
                left: format.width * 0.15,
                top: format.height * 0.2,
                child: pw.Container(
                  width: 65,
                  height: 75,
                  child: pw.Stack(
                    alignment: pw.Alignment.center,
                    children: [
                      // Accent Shape
                      pw.Transform.rotate(
                        angle: 0.1,
                        child: pw.Container(
                          width: 65, height: 75,
                          decoration: pw.BoxDecoration(color: deepBlue, borderRadius: pw.BorderRadius.circular(4)),
                        ),
                      ),
                      // Main Photo
                      pw.ClipRRect(
                        horizontalRadius: 4, verticalRadius: 4,
                        child: pw.Container(
                          width: 60, height: 70,
                          color: PdfColors.grey300,
                          child: passportImage != null 
                            ? pw.Image(passportImage, fit: pw.BoxFit.cover)
                            : pw.Center(child: pw.Text("PHOTO", style: pw.TextStyle(fontSize: 8))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main Info Section (Right)
              pw.Positioned(
                left: format.width * 0.42,
                top: 15, right: 10, bottom: 10,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(staff.name.toUpperCase(), style: pw.TextStyle(color: PdfColors.black, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    pw.Text(staff.position.toUpperCase(), style: pw.TextStyle(color: PdfColors.grey600, fontSize: 7, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                    
                    pw.SizedBox(height: 15),
                    
                    _buildIdRow("ID NO:", staff.staffId),
                    _buildIdRow("BRANCH:", branch.name.toUpperCase()),
                    _buildIdRow("EMAIL:", staff.email ?? "N/A"),
                    _buildIdRow("PHONE:", staff.phone),

                    pw.Spacer(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: pw.BoxDecoration(color: PdfColors.green50, borderRadius: pw.BorderRadius.circular(2)),
                          child: pw.Text("AUTHORIZED PERSONNEL", style: pw.TextStyle(color: PdfColors.green900, fontSize: 5, fontWeight: pw.FontWeight.bold)),
                        ),
                        // Small deep blue accent at bottom right
                        pw.Container(width: 15, height: 2, color: deepBlue),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // PAGE 2: BACK SIDE
    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              pw.FullPage(ignoreMargins: true, child: pw.Container(color: PdfColors.white)),
              
              // Right Geometric Section (Inverse of Front)
              pw.Positioned(
                right: 0, top: 0, bottom: 0,
                width: format.width * 0.25,
                child: pw.Stack(
                  children: [
                    pw.Container(color: PdfColor.fromHex('#121212')),
                    pw.Positioned(
                      left: -15, top: 0, bottom: 0,
                      child: pw.Transform.rotate(
                        angle: 0.2,
                        child: pw.Container(width: 30, color: PdfColor.fromHex('#121212')),
                      ),
                    ),
                    // Barcode Positioned vertically
                    pw.Positioned(
                      right: 8, top: 10, bottom: 10,
                      child: pw.Transform.rotate(
                        angle: 3.14159 / 2,
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.code128(),
                          data: staff.staffId,
                          width: 80,
                          height: 15,
                          color: PdfColors.white,
                          drawText: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // T&C Content
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(15, 12, format.width * 0.3, 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("TERMS & CONDITIONS", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: deepBlue)),
                    pw.SizedBox(height: 4),
                    _buildTcItem("This card is the property of $companyName."),
                    _buildTcItem("It must be carried at all times while on duty and presented upon request."),
                    _buildTcItem("Loss of this card must be reported to the HR department immediately."),
                    _buildTcItem("A replacement fee may apply for lost or damaged cards."),
                    _buildTcItem("If found, please return to any Clotheline branch or the nearest police station."),
                    
                    pw.Spacer(),
                    
                    // Staff Signature Lift
                    pw.Text("STAFF SIGNATURE", style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Container(
                      width: 60, height: 25,
                      child: signatureImage != null 
                        ? pw.Image(signatureImage, fit: pw.BoxFit.contain)
                        : pw.Text(staff.name, style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10, color: PdfColors.grey700)),
                    ),
                    pw.Container(width: 80, height: 0.5, color: PdfColors.grey400),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildIdRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.SizedBox(width: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 6, color: PdfColors.black)),
        ],
      ),
    );
  }

  static pw.Widget _buildTcItem(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(width: 2, height: 2, margin: const pw.EdgeInsets.only(top: 2, right: 3), color: PdfColors.black),
          pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.black))),
        ],
      ),
    );
  }
}
