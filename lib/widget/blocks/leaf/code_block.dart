import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:highlight/highlight.dart' as hi;
import 'package:markdown_widget/markdown_widget.dart';
import 'package:markdown/markdown.dart' as m;

///Tag: [MarkdownTag.pre]
///
///An indented code block is composed of one or more indented chunks separated by blank lines
///A code fence is a sequence of at least three consecutive backtick characters (`) or tildes (~)
class CodeBlockNode extends ElementNode {
  CodeBlockNode(this.element, this.preConfig, this.visitor);

  String get content => element.textContent;
  final PreConfig preConfig;
  final m.Element element;
  final WidgetVisitor visitor;

  @override
  InlineSpan build() {
    String? language = preConfig.language;
    try {
      final languageValue =
          (element.children?.first as m.Element).attributes['class']!;
      language = languageValue.split('-').last;
    } catch (e) {
      language = null;
      debugPrint('get language error:$e');
    }
    final splitContents = content
        .trim()
        .split(visitor.splitRegExp ?? WidgetVisitor.defaultSplitRegExp);
    if (splitContents.last.isEmpty) splitContents.removeLast();
    final codeBuilder = preConfig.builder;
    if (codeBuilder != null) {
      return WidgetSpan(child: codeBuilder.call(content, language ?? ''));
    }
    final widget = Container(
      decoration: preConfig.decoration,
      margin: preConfig.margin,
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: preConfig.codeBlockTitleDecoration,
            margin: preConfig.codeBlockTitleMargin,
            padding: preConfig.codeBlockTitlePadding,
            child: Row(
              children: [
                Expanded(
                    child: Text(
                  language ?? preConfig.language,
                  style: preConfig.codeBlockTitleTextStyle,
                )),
                Container(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        preConfig.codeBlockTitleCopyIcon,
                        size: preConfig.codeBlockTitleTextStyle.fontSize,
                        color: preConfig.codeBlockTitleTextStyle.color,
                      ),
                      SizedBox(
                        width: 4,
                      ),
                      Text(
                        preConfig.codeBlockTitleCopyText,
                        style: preConfig.codeBlockTitleTextStyle,
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          Container(
            padding: preConfig.codeBlockBodyPadding,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(splitContents.length, (index) {
                  final currentContent = splitContents[index];
                  return ProxyRichText(
                    TextSpan(
                      children: highLightSpans(
                        currentContent,
                        language: language ?? preConfig.language,
                        theme: preConfig.theme,
                        textStyle: style,
                        styleNotMatched: preConfig.styleNotMatched,
                      ),
                    ),
                    richTextBuilder: visitor.richTextBuilder,
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
    return WidgetSpan(
        child:
            preConfig.wrapper?.call(widget, content, language ?? '') ?? widget);
  }

  @override
  TextStyle get style => preConfig.codeBlockBodyTextStyle.merge(parentStyle);
}

///transform code to highlight code
List<InlineSpan> highLightSpans(
  String input, {
  String? language,
  bool autoDetectionLanguage = false,
  Map<String, TextStyle> theme = const {},
  TextStyle? textStyle,
  TextStyle? styleNotMatched,
  int tabSize = 8,
}) {
  return convertHiNodes(
      hi.highlight
          .parse(input.trimRight(),
              language: autoDetectionLanguage ? null : language,
              autoDetection: autoDetectionLanguage)
          .nodes!,
      theme,
      textStyle,
      styleNotMatched);
}

List<TextSpan> convertHiNodes(
  List<hi.Node> nodes,
  Map<String, TextStyle> theme,
  TextStyle? style,
  TextStyle? styleNotMatched,
) {
  List<TextSpan> spans = [];
  var currentSpans = spans;
  List<List<TextSpan>> stack = [];

  void traverse(hi.Node node, TextStyle? parentStyle) {
    final nodeStyle = parentStyle ?? theme[node.className ?? ''];
    final finallyStyle = (nodeStyle ?? styleNotMatched)?.merge(style);
    if (node.value != null) {
      currentSpans.add(node.className == null
          ? TextSpan(text: node.value, style: finallyStyle)
          : TextSpan(text: node.value, style: finallyStyle));
    } else if (node.children != null) {
      List<TextSpan> tmp = [];
      currentSpans.add(TextSpan(children: tmp, style: finallyStyle));
      stack.add(currentSpans);
      currentSpans = tmp;

      for (var n in node.children!) {
        traverse(n, nodeStyle);
        if (n == node.children!.last) {
          currentSpans = stack.isEmpty ? spans : stack.removeLast();
        }
      }
    }
  }

  for (var node in nodes) {
    traverse(node, null);
  }
  return spans;
}

///config class for pre
class PreConfig implements LeafConfig {
  final Decoration decoration;
  final EdgeInsetsGeometry margin;

  final EdgeInsetsGeometry codeBlockBodyPadding;
  final TextStyle codeBlockBodyTextStyle;

  /// CodeBlock container title
  final EdgeInsetsGeometry codeBlockTitlePadding;
  final Decoration? codeBlockTitleDecoration;
  final EdgeInsetsGeometry codeBlockTitleMargin;
  final TextStyle codeBlockTitleTextStyle;
  final IconData codeBlockTitleCopyIcon;
  final String codeBlockTitleCopyText;

  /// the [styleNotMatched] is used to set a default TextStyle for code that does not match any theme.
  final TextStyle? styleNotMatched;
  final CodeWrapper? wrapper;
  final CodeBuilder? builder;

  ///see package:flutter_highlight/themes/
  final Map<String, TextStyle> theme;
  final String language;

  const PreConfig({
    this.decoration = const BoxDecoration(
      color: Color(0xffeff1f3),
      borderRadius: BorderRadius.all(Radius.circular(8.0)),
    ),
    this.margin = const EdgeInsets.symmetric(vertical: 8.0),
    this.codeBlockTitlePadding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.codeBlockTitleDecoration,
    this.codeBlockTitleMargin = const EdgeInsets.all(0),
    this.codeBlockTitleTextStyle = const TextStyle(fontSize: 12),
    this.codeBlockTitleCopyIcon = Icons.copy,
    this.codeBlockTitleCopyText = 'Copy',
    this.codeBlockBodyPadding = const EdgeInsets.fromLTRB(16, 8, 16, 12),
    this.codeBlockBodyTextStyle = const TextStyle(fontSize: 14),
    this.styleNotMatched,
    this.theme = a11yLightTheme,
    this.language = 'dart',
    this.wrapper,
    this.builder,
  }) : assert(builder == null || wrapper == null);

  static PreConfig get darkConfig => const PreConfig(
        decoration: BoxDecoration(
          color: Color(0xff555555),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        theme: a11yDarkTheme,
      );

  ///copy by other params
  PreConfig copy({
    Decoration? decoration,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? codeBlockBodyPadding,
    TextStyle? codeBlockBodyTextStyle,
    EdgeInsetsGeometry? codeBlockTitlePadding,
    Decoration? codeBlockTitleDecoration,
    EdgeInsetsGeometry? codeBlockTitleMargin,
    TextStyle? codeBlockTitleTextStyle,
    IconData? codeBlockTitleCopyIcon,
    String? codeBlockTitleCopyText,
    TextStyle? styleNotMatched,
    CodeWrapper? wrapper,
    CodeBuilder? builder,
    Map<String, TextStyle>? theme,
    String? language,
  }) {
    return PreConfig(
      decoration: decoration ?? this.decoration,
      margin: margin ?? this.margin,
      codeBlockBodyPadding: codeBlockBodyPadding ?? this.codeBlockBodyPadding,
      codeBlockBodyTextStyle:
          codeBlockBodyTextStyle ?? this.codeBlockBodyTextStyle,
      codeBlockTitlePadding:
          codeBlockTitlePadding ?? this.codeBlockTitlePadding,
      codeBlockTitleDecoration: codeBlockTitleDecoration,
      codeBlockTitleMargin: codeBlockTitleMargin ?? this.codeBlockTitleMargin,
      codeBlockTitleTextStyle:
          codeBlockTitleTextStyle ?? this.codeBlockTitleTextStyle,
      codeBlockTitleCopyIcon:
          codeBlockTitleCopyIcon ?? this.codeBlockTitleCopyIcon,
      codeBlockTitleCopyText:
          codeBlockTitleCopyText ?? this.codeBlockTitleCopyText,
      styleNotMatched: styleNotMatched ?? this.styleNotMatched,
      wrapper: wrapper ?? this.wrapper,
      builder: builder ?? this.builder,
      theme: theme ?? this.theme,
      language: language ?? this.language,
    );
  }

  @nonVirtual
  @override
  String get tag => MarkdownTag.pre.name;
}

typedef CodeWrapper = Widget Function(
  Widget child,
  String code,
  String language,
);

typedef CodeBuilder = Widget Function(String code, String language);
