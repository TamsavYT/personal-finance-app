import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/analytics_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/icon_helper.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalyticsProvider>().loadAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: Consumer<AnalyticsProvider>(
        builder: (context, analytics, child) {
          if (analytics.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () async => analytics.loadAnalytics(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMonthSelector(context, analytics),
                  const SizedBox(height: 16),
                  _buildSummaryCards(analytics),
                  const SizedBox(height: 24),
                  _buildCategoryPieChart(analytics),
                  const SizedBox(height: 24),
                  _buildMonthlyTrendChart(analytics),
                  const SizedBox(height: 24),
                  _buildBudgetStatus(analytics),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context, AnalyticsProvider analytics) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            int newMonth = analytics.selectedMonth - 1;
            int newYear = analytics.selectedYear;
            if (newMonth < 1) {
              newMonth = 12;
              newYear--;
            }
            analytics.setMonth(newMonth, newYear);
          },
        ),
        Text(
          DateFormatter.formatMonth(analytics.selectedMonth, analytics.selectedYear),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            int newMonth = analytics.selectedMonth + 1;
            int newYear = analytics.selectedYear;
            if (newMonth > 12) {
              newMonth = 1;
              newYear++;
            }
            analytics.setMonth(newMonth, newYear);
          },
        ),
      ],
    );
  }

  Widget _buildSummaryCards(AnalyticsProvider analytics) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Income',
            analytics.totalIncome,
            Colors.green,
            Icons.arrow_downward,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Expense',
            analytics.totalExpense,
            Colors.red,
            Icons.arrow_upward,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Balance',
            analytics.totalIncome - analytics.totalExpense,
            Colors.teal,
            Icons.account_balance_wallet,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.formatCurrencyShort(amount),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPieChart(AnalyticsProvider analytics) {
    if (analytics.categoryExpenses.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: Text('No expenses this month')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Expenses by Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 60,
                  sections: analytics.categoryExpenses.map((data) {
                    final colorHex = data['color'] as String;
                    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                    return PieChartSectionData(
                      color: color,
                      value: (data['total'] as num).toDouble(),
                      title: '',
                      radius: 30,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ...analytics.categoryExpenses.map((data) {
              final colorHex = data['color'] as String;
              final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
              final amount = (data['total'] as num).toDouble();
              final percentage = (amount / analytics.totalExpense) * 100;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(data['categoryName'])),
                    Text('${percentage.toStringAsFixed(1)}%'),
                    const SizedBox(width: 16),
                    Text(CurrencyFormatter.formatCurrency(amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTrendChart(AnalyticsProvider analytics) {
    if (analytics.monthlyTrend.isEmpty) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monthly Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxY(analytics.monthlyTrend),
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                          if (value >= 0 && value < 12) {
                            return Text(months[value.toInt()], style: const TextStyle(fontSize: 10));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: analytics.monthlyTrend.map((data) {
                    return BarChartGroupData(
                      x: (data['month'] as int) - 1,
                      barRods: [
                        BarChartRodData(toY: (data['income'] as num).toDouble(), color: Colors.green, width: 8),
                        BarChartRodData(toY: (data['expense'] as num).toDouble(), color: Colors.red, width: 8),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getMaxY(List<Map<String, dynamic>> trendData) {
    double max = 0;
    for (var data in trendData) {
      if ((data['income'] as num).toDouble() > max) max = (data['income'] as num).toDouble();
      if ((data['expense'] as num).toDouble() > max) max = (data['expense'] as num).toDouble();
    }
    return max > 0 ? max * 1.2 : 100;
  }

  Widget _buildBudgetStatus(AnalyticsProvider analytics) {
    if (analytics.budgetStatus.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: Text('No budgets set')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Budget Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...analytics.budgetStatus.map((budget) {
              final spent = (budget['spent'] as num).toDouble();
              final limit = (budget['budgetLimit'] as num).toDouble();
              final percentage = (budget['percentage'] as num).toDouble();
              
              Color progressColor = Colors.green;
              if (percentage > 90) progressColor = Colors.red;
              else if (percentage > 70) progressColor = Colors.orange;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(budget['categoryName']),
                        Text('${CurrencyFormatter.formatCurrency(spent)} / ${CurrencyFormatter.formatCurrencyShort(limit)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0,
                      backgroundColor: Colors.grey[300],
                      color: progressColor,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
