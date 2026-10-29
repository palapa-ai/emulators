import 'package:flutter/widgets.dart';

extension WidgetLayout on Widget {
  Widget expanded({int flex = 1}) => Expanded(flex: flex, child: this);

  Widget centered() => Center(child: this);

  Widget filled() => Positioned.fill(child: this);
}
