import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../providers/report_provider.dart';
import '../../../../utils/currency_formatter.dart';
import '../../../../widgets/glass/GlassContainer.dart';

class RevenueChart extends StatelessWidget {
  const RevenueChart({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.70,
      child: GlassContainer(
        opacity: 0.1,
        padding: const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),
        child: Consumer<ReportProvider>(
           builder: (context, provider, _) {
             if (provider.isLoading) return const Center(child: CircularProgressIndicator());
             
             final analytics = provider.analytics;
             if (analytics == null) return const Center(child: Text("Unable to load chart data", style: TextStyle(color: Colors.white54))); 
             
             final List<dynamic> chartData = analytics['chart'] ?? [];
             if (chartData.isEmpty) return const Center(child: Text("No Data for Chart", style: TextStyle(color: Colors.white54)));

             // Convert to Spots
             // _id is "YYYY-MM-DD". We map day of month or index as X
             List<FlSpot> spots = [];
             for (int i = 0; i < chartData.length; i++) {
                final val = chartData[i]['amount'] / 100.0; // Naira
                spots.add(FlSpot(i.toDouble(), val));
             }

             return LineChart(
               LineChartData(
                 gridData: FlGridData(
                   show: true,
                   drawVerticalLine: false,
                   horizontalInterval: 10000, // Dynamic?
                   getDrawingHorizontalLine: (value) {
                     return const FlLine(
                       color: Colors.white10,
                       strokeWidth: 1,
                     );
                   },
                 ),
                 titlesData: FlTitlesData(
                   show: true,
                   rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                   topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                   bottomTitles: AxisTitles(
                     sideTitles: SideTitles(
                       showTitles: true,
                       reservedSize: 30,
                       interval: 1,
                       getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < chartData.length) {
                             // Show every 3rd label or so to avoid crowding
                             if (chartData.length > 7 && index % 2 != 0) return const SizedBox.shrink();
                             
                             String dateStr = chartData[index]['_id'] ?? "";
                             // Format: 2024-02-18 -> 18/02
                             final parts = dateStr.split('-');
                             if (parts.length == 3) {
                               return Padding(
                                 padding: const EdgeInsets.only(top: 8.0),
                                 child: Text("${parts[2]}/${parts[1]}", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                               );
                             }
                          }
                          return const Text('');
                       },
                     ),
                   ),
                   leftTitles: AxisTitles(
                     sideTitles: SideTitles(
                       showTitles: true,
                       interval: 50000, // Dynamic?
                       getTitlesWidget: (value, meta) {
                         // Simplify: 50k, 1M
                         return Text(CurrencyFormatter.compact(value), style: const TextStyle(color: Colors.white54, fontSize: 10), textAlign: TextAlign.left);
                       },
                       reservedSize: 42,
                     ),
                   ),
                 ),
                 borderData: FlBorderData(
                   show: false,
                 ),
                 minX: 0,
                 maxX: (spots.length - 1).toDouble(),
                 minY: 0,
                 lineBarsData: [
                   LineChartBarData(
                     spots: spots,
                     isCurved: true,
                     gradient: const LinearGradient(
                       colors: [AppTheme.primaryColor, Colors.cyanAccent],
                     ),
                     barWidth: 3,
                     isStrokeCapRound: true,
                     dotData: const FlDotData(show: false),
                     belowBarData: BarAreaData(
                       show: true,
                       gradient: LinearGradient(
                         colors: [AppTheme.primaryColor.withOpacity(0.3), Colors.transparent],
                         begin: Alignment.topCenter,
                         end: Alignment.bottomCenter,
                       ),
                     ),
                   ),
                 ],
               ),
             );
           },
        ),
      ),
    );
  }
}
