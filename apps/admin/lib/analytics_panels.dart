import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'formatters.dart';
import 'localized_calendar.dart';
import 'order_api.dart';

/// Financial panels consume the same authorized snapshot as the report totals.
class AdminAnalyticsPanels extends StatelessWidget {
  const AdminAnalyticsPanels({
    super.key,
    required this.analytics,
    this.products = const [],
  });
  final AdminAnalytics analytics;
  final List<AdminProductProfitability> products;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final sales = _DailySalesChart(analytics.dailySales);
      final states = _OrderStatesChart(analytics.orderStates);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (box.maxWidth >= 820)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: sales),
                const SizedBox(width: 16),
                Expanded(child: states),
              ],
            )
          else ...[
            sales,
            const SizedBox(height: 16),
            states,
          ],
          if (products.isNotEmpty) ...[
            const SizedBox(height: 16),
            _BestSellers(products),
          ],
        ],
      );
    },
  );
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });
  final String title, subtitle;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AdminColors.heading,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AdminColors.subtle),
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    ),
  );
}

class _DailySalesChart extends StatefulWidget {
  const _DailySalesChart(this.sales);
  final List<AdminDailySales> sales;
  @override
  State<_DailySalesChart> createState() => _DailySalesChartState();
}

class _DailySalesChartState extends State<_DailySalesChart> {
  bool profit = false;
  int? selected;
  @override
  void didUpdateWidget(covariant _DailySalesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sales != widget.sales) selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.sales]..sort((a, b) => a.day.compareTo(b.day));
    // Fill unsold days between the first and last paid order, never invent sales.
    final byDay = {for (final d in sorted) d.day: d};
    final days = <AdminDailySales>[];
    if (sorted.isNotEmpty) {
      for (
        var day = sorted.first.day;
        !day.isAfter(sorted.last.day);
        day = day.add(const Duration(days: 1))
      ) {
        days.add(
          byDay[day] ??
              AdminDailySales(
                day: day,
                orderCount: 0,
                revenue: 0,
                netProfit: 0,
              ),
        );
      }
    }
    final values = days
        .map((d) => (profit ? d.netProfit : d.revenue).toDouble())
        .toList();
    final index = days.isEmpty
        ? null
        : (selected ?? days.length - 1).clamp(0, days.length - 1);
    final current = index == null ? null : days[index];
    final locale = Localizations.localeOf(context);
    return _ChartCard(
      title: 'روند فروش و سود',
      subtitle: 'از اولین تا آخرین فروش بازه • تفکیک روزانه به وقت UTC • ریال',
      action: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('فروش'),
            selected: !profit,
            onSelected: (_) => setState(() => profit = false),
          ),
          ChoiceChip(
            label: const Text('سود'),
            selected: profit,
            onSelected: (_) => setState(() => profit = true),
          ),
        ],
      ),
      child: days.isEmpty
          ? const SizedBox(
              height: 230,
              child: Center(
                child: Text('هنوز فروش پرداخت‌شده‌ای در این بازه نیست.'),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${formatCalendarDate(current!.day, locale)} • ${formatPersianInteger(current.orderCount)} سفارش • ${formatPersianNumber(profit ? current.netProfit : current.revenue)} ریال',
                  style: const TextStyle(
                    color: AdminColors.heading,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 160,
                  child: LayoutBuilder(
                    builder: (context, box) => MouseRegion(
                      onHover: (event) => setState(
                        () => selected =
                            (event.localPosition.dx /
                                    box.maxWidth *
                                    days.length)
                                .floor()
                                .clamp(0, days.length - 1),
                      ),
                      child: GestureDetector(
                        onTapDown: (event) => setState(
                          () => selected =
                              (event.localPosition.dx /
                                      box.maxWidth *
                                      days.length)
                                  .floor()
                                  .clamp(0, days.length - 1),
                        ),
                        child: Semantics(
                          label:
                              'نمودار روزانه؛ با انتخاب تاریخ زیر، جزئیات فروش نمایش داده می‌شود',
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _SalesPainter(
                              values,
                              index!,
                              profit
                                  ? AdminColors.success
                                  : AdminColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      formatCalendarDate(days.first.day, locale),
                      style: const TextStyle(fontSize: 10),
                    ),
                    Text(
                      formatCalendarDate(days.last.day, locale),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: index,
                  key: ValueKey('${profit}_$index'),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'جزئیات روز'),
                  items: [
                    for (var i = 0; i < days.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(formatCalendarDate(days[i].day, locale)),
                      ),
                  ],
                  onChanged: (i) => setState(() => selected = i),
                ),
              ],
            ),
    );
  }
}

class _SalesPainter extends CustomPainter {
  _SalesPainter(this.values, this.selected, this.color);
  final List<double> values;
  final int selected;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final low = math.min(0.0, values.reduce(math.min));
    final high = math.max(1.0, values.reduce(math.max));
    double y(double v) =>
        size.height - 8 - (v - low) / (high - low) * (size.height - 16);
    double x(int i) => values.length == 1
        ? size.width / 2
        : 8 + i / (values.length - 1) * (size.width - 16);
    final grid = Paint()
      ..color = AdminColors.border
      ..strokeWidth = .6;
    for (var i = 0; i < 4; i++) {
      final dy = 8 + i * (size.height - 16) / 3;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), grid);
    }
    final path = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }
    final fill = Path.from(path)
      ..lineTo(x(values.length - 1), y(0))
      ..lineTo(x(0), y(0))
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: .12));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawLine(
      Offset(x(selected), 0),
      Offset(x(selected), size.height),
      grid,
    );
    canvas.drawCircle(
      Offset(x(selected), y(values[selected])),
      5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SalesPainter old) =>
      old.values != values || old.selected != selected || old.color != color;
}

const _states = <String, String>{
  'AwaitingPayment': 'در انتظار پرداخت',
  'Paid': 'پرداخت‌شده',
  'Preparing': 'در حال آماده‌سازی',
  'Shipped': 'ارسال‌شده',
  'Delivered': 'تحویل‌شده',
  'Cancelled': 'لغوشده',
  'Expired': 'منقضی‌شده',
  'PaymentFailed': 'پرداخت ناموفق',
};
const _chartColors = [
  AdminColors.primary,
  AdminColors.success,
  AdminColors.info,
  AdminColors.amber,
  AdminColors.primaryLight,
  AdminColors.coral,
  AdminColors.subtle,
];

class _OrderStatesChart extends StatelessWidget {
  const _OrderStatesChart(this.states);
  final List<AdminOrderStateCount> states;
  @override
  Widget build(BuildContext context) {
    final total = states.fold<int>(0, (sum, s) => sum + s.count);
    return _ChartCard(
      title: 'وضعیت سفارش‌ها',
      subtitle: 'تمام سفارش‌های ایجادشده در بازهٔ انتخابی',
      child: Column(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(150, 150),
                  painter: _DonutPainter(
                    states.map((s) => s.count.toDouble()).toList(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatPersianInteger(total),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.heading,
                      ),
                    ),
                    const Text('سفارش', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (total == 0) const Text('سفارشی در این بازه ثبت نشده است.'),
          for (var i = 0; i < states.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: _chartColors[i % _chartColors.length],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _states[states[i].state] ?? states[i].state,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(formatPersianInteger(states[i].count)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..color = AdminColors.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16,
      );
      return;
    }
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      canvas.drawArc(
        rect,
        start,
        math.max(0, sweep - .025),
        false,
        Paint()
          ..color = _chartColors[i % _chartColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.values != values;
}

class _BestSellers extends StatelessWidget {
  const _BestSellers(this.products);
  final List<AdminProductProfitability> products;
  @override
  Widget build(BuildContext context) {
    final sorted = [...products]
      ..sort((a, b) => b.unitsSold.compareTo(a.unitsSold));
    final shown = sorted.take(6).toList();
    final max = shown.fold<int>(1, (n, p) => math.max(n, p.unitsSold));
    return _ChartCard(
      title: 'محصولات پرفروش',
      subtitle: 'بر اساس تعداد واحد فروخته‌شده در بازهٔ انتخابی',
      child: Column(
        children: [
          for (final p in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 160,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.productTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          p.variantLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AdminColors.subtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: p.unitsSold / max,
                        minHeight: 10,
                        color: AdminColors.primary,
                        backgroundColor: AdminColors.primarySoft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(formatPersianInteger(p.unitsSold)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
