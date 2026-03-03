import 'package:csv/csv.dart';
void main() {
  final rows = [["Name", "Phone"], ["Martin", "123"]];
  String result = csv.encode(rows);
  print(result);
}
