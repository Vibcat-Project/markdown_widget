import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/configs.dart';
import '../span_node.dart';

///Tag:  [MarkdownTag.code]
///the code textSpan
class CodeNode extends ElementNode {
  final CodeConfig codeConfig;
  final String text;

  CodeNode(this.text, this.codeConfig);

  @override
  InlineSpan build() => WidgetSpan(
      style: style,
      child: Container(
        padding: codeConfig.padding,
        decoration: codeConfig.decoration,
        child: Text.rich(TextSpan(text: text)),
      ));

  @override
  TextStyle get style => codeConfig.style.merge(parentStyle);
}

///config class for code, tag: code
class CodeConfig implements InlineConfig {
  final TextStyle style;
  final Decoration decoration;
  final EdgeInsets? padding;

  CodeConfig({
    this.style = const TextStyle(),
    this.padding,
    Decoration? decoration,
  }) : decoration = decoration ??
            BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Color(0xCCeff1f3),
            );

  static CodeConfig get darkConfig => CodeConfig(
          decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Color(0xCC555555),
      ));

  @nonVirtual
  @override
  String get tag => MarkdownTag.code.name;
}
