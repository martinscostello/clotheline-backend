import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/staff_model.dart';
import '../models/branch_model.dart';

class StaffPdfService {
  static Future<void> generatePaySlip({
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

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateAgreement({
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

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateIDCard({
    required Staff staff,
    required Branch branch,
  }) async {
    final pdf = pw.Document();
    final isAbuja = branch.name.toLowerCase().contains('abuja');
    final companyName = isAbuja ? 'Brimarck Cleaning Services' : 'Clotheline Services';
    
    // ID Card dimensions: approx 85mm x 55mm
    final format = PdfPageFormat(86 * PdfPageFormat.mm, 54 * PdfPageFormat.mm);

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.blue900,
              border: pw.Border.all(color: PdfColors.white, width: 2),
            ),
            padding: const pw.EdgeInsets.all(10),
            child: pw.Row(
              children: [
                pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 50,
                      height: 60,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Center(child: pw.Text("PHOTO", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey))),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text("ID: ${staff.staffId}", style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(companyName, style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Divider(color: PdfColors.white, thickness: 1),
                      pw.Text(staff.name.toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text(staff.position, style: pw.TextStyle(color: PdfColors.amber, fontSize: 10)),
                      pw.Spacer(),
                      pw.Text("BRANCH: ${branch.name}", style: pw.TextStyle(color: PdfColors.white, fontSize: 8)),
                      pw.Text("VERIFIED STAFF", style: pw.TextStyle(color: PdfColors.greenAccent, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}
