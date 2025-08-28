import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as m;
import 'package:markdown_widget/markdown_widget.dart';

/// 定义行内 LaTeX 语法, e.g., $E=mc^2$
class InlineLatexSyntax extends m.InlineSyntax {
  InlineLatexSyntax() : super(r'\$([^\$]+)\$');

  @override
  bool onMatch(m.InlineParser parser, Match match) {
    final content = match.group(1)!.trim();
    // 创建一个自定义的 Element 节点
    // 标签为 'latex', 内容为 TextNode
    parser.addNode(m.Element.text('latex', content));
    return true;
  }
}

/// 定义块级 LaTeX 语法, e.g., $$...$$
class BlockLatexSyntax extends m.BlockSyntax {
  @override
  RegExp get pattern =>
      RegExp(r'^\$\$(.*?)\$\$$', multiLine: true, dotAll: true);

  const BlockLatexSyntax();

  @override
  m.Node parse(m.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content)!;
    final content = match.group(1)!.trim();
    parser.advance();
    // 创建一个自定义的 Element 节点
    final element = m.Element.text('latexBlock', content);
    return element;
  }
}

/// 创建一个自定义的 SpanNode 来渲染 LaTeX
class LatexNode extends SpanNode {
  final String content;
  final bool isBlock; // 用于区分是行内公式还是块级公式

  LatexNode(this.content, this.isBlock);

  @override
  InlineSpan build() {
    // 使用 flutter_math_fork 库的 Math widget 来渲染
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Math.tex(
        content,
        // 块级公式使用 display 样式，更大一些
        // 行内公式使用 text 样式，与普通文本融合
        mathStyle: isBlock ? MathStyle.display : MathStyle.text,
        // 继承父节点的文本样式
        textStyle: parentStyle,
        // 渲染失败时的回退
        onErrorFallback: (err) {
          return Text(
            isBlock ? '\$\$$content\$\$' : '\$$content\$ ',
            style: parentStyle?.copyWith(color: Colors.red),
          );
        },
      ),
    );
  }
}

/// 这是最关键的“胶水”部分
/// 它将我们自定义的标签 'latex' 和 'latexBlock' 与我们的渲染节点 LatexNode 连接起来
final List<SpanNodeGeneratorWithTag> latexGenerators = [
  // 行内公式的生成器
  SpanNodeGeneratorWithTag(
    tag: 'latex',
    generator: (e, config, visitor) => LatexNode(e.textContent, false),
  ),
  // 块级公式的生成器
  SpanNodeGeneratorWithTag(
    tag: 'latexBlock',
    generator: (e, config, visitor) => LatexNode(e.textContent, true),
  ),
];
