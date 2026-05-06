import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:lumox/ui/theme/theme_ui_values.dart';

class StreakCard extends StatefulWidget {
  final int completedDays;
  final int additionalShownDays;
  final int maxCompletedDaysShown;
  
  const StreakCard({
    super.key,
    required this.completedDays, this.additionalShownDays = 8, this.maxCompletedDaysShown = 5,
  });

  @override
  State<StreakCard> createState() => _StreakCardState();
}
class _StreakCardState extends State<StreakCard> {
  late ScrollController _scrollController;
  final double _itemHeight = 100.0;
  
  bool expanded = false;
  
  bool _isDoneExpanding = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setInitialScroll());
  }

  @override
  void didUpdateWidget(covariant StreakCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completedDays != widget.completedDays ||
        oldWidget.additionalShownDays != widget.additionalShownDays ||
        oldWidget.maxCompletedDaysShown != widget.maxCompletedDaysShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _setInitialScroll());
    }
  }

  void _setInitialScroll() {
    final height = expanded ? 400.0 : 200.0;

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_computeOffset(height));
    }
  }

  int _computeFirstShownDay() {
    final int lastDay = widget.completedDays;
    final int completedWindowStart = (lastDay - widget.maxCompletedDaysShown).clamp(0, lastDay);
    return completedWindowStart;
  }

  int _computeTotalItems(int firstShownDay) {
    final int completedShown = widget.completedDays - firstShownDay;
    return completedShown + widget.additionalShownDays;
  }

  double _computeOffset(double viewportHeight) {
    final firstShownDay = _computeFirstShownDay();
    final totalItems = _computeTotalItems(firstShownDay);

    final currentIndex = widget.completedDays - firstShownDay;

    final maxScrollExtent =
    math.max(0.0, (totalItems * _itemHeight) - viewportHeight);

    final targetOffset =
        (currentIndex * _itemHeight) - (viewportHeight / 2) + (_itemHeight / 2);

    return targetOffset.clamp(0.0, maxScrollExtent);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int firstShownDay = _computeFirstShownDay();
    final int totalItems = _computeTotalItems(firstShownDay);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isDoneExpanding = false;
            expanded = !expanded;
          });
          
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final height = expanded ? 400.0 : 200.0;
            
            await _scrollController.animateTo(
              _computeOffset(height),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
            await Future.delayed(const Duration(milliseconds: 1000));
            if(!mounted) return;
            setState(() {
              _isDoneExpanding = true;
            });
          });
        },
        child: AnimatedContainer(
          height: expanded ? 400 : 200.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(scrollbars: _isDoneExpanding && expanded),
              child: ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.symmetric(vertical: 20),
                physics: expanded ? BouncingScrollPhysics() : NeverScrollableScrollPhysics(),
                itemCount: totalItems,
                itemBuilder: (context, index) {
                  final day = firstShownDay + index + 1; 
                  final isCompleted = day <= widget.completedDays;
                  final isCurrent = day == widget.completedDays + 1;
                  final isPrevCompleted = (day - 1) <= widget.completedDays && (day - 1) > 0;
                      
                  return StreakItem(
                    index: index,
                    day: day,
                    isCompleted: isCompleted,
                    isCurrent: isCurrent,
                    isPrevCompleted: isPrevCompleted,
                    itemHeight: _itemHeight,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StreakItem extends StatelessWidget {
  final int index;
  final int day;
  final bool isCompleted;
  final bool isCurrent;
  final bool isPrevCompleted;
  final double itemHeight;

  const StreakItem({
    super.key,
    required this.index,
    required this.day,
    required this.isCompleted,
    required this.isCurrent,
    required this.isPrevCompleted,
    required this.itemHeight,
  });
  
  double _getOffsetX(int idx) {
    return math.sin(idx * 0.8) * 80.0;
  }

  @override
  Widget build(BuildContext context) {
    final double currentX = _getOffsetX(index);
    final double prevX = index > 0 ? _getOffsetX(index - 1) : currentX;
    final double nextX = _getOffsetX(index + 1);

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final Color cardColor = isCompleted
        ? colors.primaryContainer
        : (isCurrent ? colors.secondaryContainer : colors.surface);

    final Color textColor = colors.onInverseSurface;
    final Color textColorDark = colors.onSurface;

    return SizedBox(
      height: itemHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            height: itemHeight,
            child: CustomPaint(
              painter: PathPainter(
                currentX: currentX,
                prevX: prevX,
                nextX: nextX,
                isCompleted: isCompleted,
                isPrevCompleted: isPrevCompleted,
                isFirst: index == 0 && !isPrevCompleted,
              ),
            ),
          ),

          Transform.translate(
            offset: Offset(currentX, 0),
            child: Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(0.5)
                ..rotateZ(-0.3),
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(context.uiRadiusXl),
                  border: Border.all(color: Colors.black87, width: 2.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black87,
                      offset: Offset(-5, 7),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "$day",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: textColorDark,
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: textColorDark,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Text(
                          "today",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    if (isCompleted)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(Icons.check, color: Colors.black87, size: 20),
                      )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PathPainter extends CustomPainter {
  final double currentX;
  final double prevX;
  final double nextX;
  final bool isCompleted;
  final bool isPrevCompleted;
  final bool isFirst;

  PathPainter({
    required this.currentX,
    required this.prevX,
    required this.nextX,
    required this.isCompleted,
    required this.isPrevCompleted,
    required this.isFirst,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;

    final paint = Paint()
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.miter;
    
    if (!isFirst) {
      paint.color = isPrevCompleted ? const Color(0xFF4ADE80) : Colors.black26;
      final pathBottom = Path()
        ..moveTo(centerX + currentX, size.height / 2)
        ..lineTo(centerX + (currentX + prevX) / 2, size.height);
      canvas.drawPath(pathBottom, paint);
    }

    paint.color = isCompleted ? const Color(0xFF4ADE80) : Colors.black26;
    final pathTop = Path()
      ..moveTo(centerX + currentX, size.height / 2)
      ..lineTo(centerX + (currentX + nextX) / 2, 0);
    canvas.drawPath(pathTop, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}