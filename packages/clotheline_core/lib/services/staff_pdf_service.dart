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
    
    // Attempt to load photo and logo
    pw.ImageProvider? passportImage;
    if (staff.passportPhoto != null) {
      try {
        passportImage = await networkImage(staff.passportPhoto!);
      } catch (e) {
        print("Error loading passport image for PDF: $e");
      }
    }

    // ID Card dimensions: approx 86mm x 54mm (CR80 standard)
    final format = PdfPageFormat(86 * PdfPageFormat.mm, 54 * PdfPageFormat.mm);

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // 1. Background Design (Gradient/Pattern)
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                ),
              ),
              // Blue side bar
              pw.Positioned(
                left: 0, top: 0, bottom: 0,
                child: pw.Container(width: 25, color: PdfColors.blue900),
              ),
              // Diagonal accent
              pw.Positioned(
                right: -20, top: -20,
                child: pw.Transform.rotate(
                  angle: 0.5,
                  child: pw.Container(width: 80, height: 80, color: PdfColors.blue100),
                ),
              ),

              // 2. Content
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(35, 12, 12, 12),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Right Content
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(companyName.toUpperCase(), style: pw.TextStyle(color: PdfColors.blue900, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                          pw.Text("STAFF IDENTIFICATION", style: pw.TextStyle(color: PdfColors.grey700, fontSize: 6, letterSpacing: 1.2)),
                          pw.SizedBox(height: 10),
                          
                          pw.Text(staff.name.toUpperCase(), style: pw.TextStyle(color: PdfColors.black, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                          pw.Text(staff.position, style: pw.TextStyle(color: PdfColors.blue600, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          
                          pw.Spacer(),
                          
                          pw.Row(
                            children: [
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text("STAFF ID", style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                                  pw.Text(staff.staffId, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                ]
                              ),
                              pw.SizedBox(width: 20),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text("BRANCH", style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                                  pw.Text(branch.name.toUpperCase(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                ]
                              ),
                            ]
                          ),
                          pw.SizedBox(height: 5),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.green100,
                              borderRadius: pw.BorderRadius.circular(2),
                            ),
                            child: pw.Text("VERIFIED PERSONNEL", style: pw.TextStyle(color: PdfColors.green900, fontSize: 6, fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                    // Left Image
                    pw.Column(
                      children: [
                        pw.Container(
                          width: 55,
                          height: 65,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.blue900, width: 2),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.ClipRRect(
                            horizontalRadius: 2,
                            verticalRadius: 2,
                            child: passportImage != null 
                              ? pw.Image(passportImage, fit: pw.BoxFit.cover)
                              : pw.Center(child: pw.Text("PHOTO", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey))),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        if (staff.signature != null)
                           pw.Text("Signature Attached", style: pw.TextStyle(fontSize: 5, color: PdfColors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Bottom colored bar
              pw.Positioned(
                bottom: 0, left: 25, right: 0,
                child: pw.Container(height: 4, color: PdfColors.amber),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
