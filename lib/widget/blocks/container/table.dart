import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../config/configs.dart';
import '../../proxy_rich_text.dart';
import '../../span_node.dart';
import '../../widget_visitor.dart';

class TableConfig implements ContainerConfig {
  final Map<int, TableColumnWidth>? columnWidths;
  final TableColumnWidth? defaultColumnWidth;
  final TextDirection? textDirection;
  final TableBorder? border;
  final TableCellVerticalAlignment? defaultVerticalAlignment;
  final TextBaseline? textBaseline;
  final Decoration? headerRowDecoration;
  final Decoration? bodyRowDecoration;
  final TextStyle? headerStyle;
  final TextStyle? bodyStyle;
  final EdgeInsets headPadding;
  final EdgeInsets bodyPadding;
  final WidgetWrapper? wrapper;

  // 新增：是否启用自动滚动检测
  final bool enableAutoScroll;

  // 新增：最小表格宽度阈值
  final double minWidthThreshold;

  // 新增：每列的最大宽度限制
  final double maxColumnWidth;

  // 新增：每列的最小宽度限制
  final double minColumnWidth;

  // 新增：是否启用文本换行
  final bool enableTextWrap;

  const TableConfig({
    this.columnWidths,
    this.defaultColumnWidth,
    this.textDirection,
    this.border,
    this.defaultVerticalAlignment,
    this.textBaseline,
    this.headerRowDecoration,
    this.bodyRowDecoration,
    this.headerStyle,
    this.bodyStyle,
    this.wrapper,
    this.headPadding = const EdgeInsets.fromLTRB(8, 4, 8, 4),
    this.bodyPadding = const EdgeInsets.fromLTRB(8, 4, 8, 4),
    this.enableAutoScroll = true,
    this.minWidthThreshold = 600.0,
    this.maxColumnWidth = 200.0, // 每列最大宽度
    this.minColumnWidth = 50.0,  // 每列最小宽度
    this.enableTextWrap = true,  // 启用文本换行
  });

  @nonVirtual
  @override
  String get tag => MarkdownTag.table.name;
}

class TableNode extends ElementNode {
  final MarkdownConfig config;

  TableNode(this.config);

  TableConfig get tbConfig => config.table;

  @override
  InlineSpan build() {
    List<TableRow> rows = [];
    int cellCount = 0;
    List<List<String>> cellContents = []; // 存储所有单元格内容用于宽度计算

    for (var child in children) {
      if (child is THeadNode) {
        cellCount = child.cellCount;
        rows.addAll(child.rows);
        // 收集表头内容
        cellContents.addAll(_extractCellContents(child));
      } else if (child is TBodyNode) {
        rows.addAll(child.buildRows(cellCount));
        // 收集表体内容
        cellContents.addAll(_extractCellContents(child));
      }
    }

    // 计算列宽，考虑最大宽度限制
    Map<int, TableColumnWidth> finalColumnWidths = _calculateColumnWidths(cellCount, cellContents);

    final tableWidget = Table(
      columnWidths: finalColumnWidths,
      defaultColumnWidth: tbConfig.defaultColumnWidth ?? IntrinsicColumnWidth(),
      textBaseline: tbConfig.textBaseline,
      textDirection: tbConfig.textDirection,
      border: tbConfig.border ??
          TableBorder.all(
              color: parentStyle?.color ??
                  config.p.textStyle.color ??
                  Colors.grey),
      defaultVerticalAlignment: tbConfig.defaultVerticalAlignment ??
          TableCellVerticalAlignment.top, // 改为顶部对齐，适合多行文本
      children: rows,
    );

    // 如果禁用自动滚动，直接返回原始表格
    if (!tbConfig.enableAutoScroll) {
      return WidgetSpan(
          child: SizedBox(
            width: double.infinity,
            child: tbConfig.wrapper?.call(tableWidget) ?? tableWidget,
          ));
    }

    // 使用 LayoutBuilder 来获取可用宽度并决定是否需要滚动
    final adaptiveTableWidget = LayoutBuilder(
      builder: (context, constraints) {
        // 计算表格总宽度（考虑最大宽度限制）
        double calculatedTableWidth = _calculateTotalTableWidth(cellCount);

        // 判断是否需要滚动：当计算宽度超过可用宽度时
        bool needsScrolling = calculatedTableWidth > constraints.maxWidth;

        Widget finalTable = tbConfig.wrapper?.call(tableWidget) ?? tableWidget;

        if (needsScrolling) {
          // 需要滚动时包装在 SingleChildScrollView 中
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: calculatedTableWidth,
              ),
              child: finalTable,
            ),
          );
        } else {
          // 不需要滚动时直接返回表格
          return SizedBox(
            width: double.infinity,
            child: finalTable,
          );
        }
      },
    );

    return WidgetSpan(child: adaptiveTableWidget);
  }

  // 计算列宽，考虑最大宽度限制
  Map<int, TableColumnWidth> _calculateColumnWidths(int cellCount, List<List<String>> cellContents) {
    Map<int, TableColumnWidth> columnWidths = {};

    // 如果用户已经设置了列宽，优先使用用户设置
    if (tbConfig.columnWidths != null) {
      columnWidths.addAll(tbConfig.columnWidths!);
    }

    // 计算每列的理想宽度
    List<double> idealWidths = _calculateIdealColumnWidths(cellCount, cellContents);

    for (int i = 0; i < cellCount; i++) {
      // 如果用户没有为该列设置特定宽度，则使用计算出的宽度
      if (!columnWidths.containsKey(i)) {
        double idealWidth = idealWidths.isNotEmpty && i < idealWidths.length
            ? idealWidths[i]
            : tbConfig.minColumnWidth;

        // 限制在最小和最大宽度之间
        double constrainedWidth = idealWidth.clamp(tbConfig.minColumnWidth, tbConfig.maxColumnWidth);

        columnWidths[i] = FixedColumnWidth(constrainedWidth);
      }
    }

    return columnWidths;
  }

  // 计算每列的理想宽度
  List<double> _calculateIdealColumnWidths(int cellCount, List<List<String>> cellContents) {
    if (cellContents.isEmpty || cellCount == 0) {
      return List.filled(cellCount, tbConfig.minColumnWidth);
    }

    // 获取文本样式
    TextStyle headerStyle = tbConfig.headerStyle?.merge(parentStyle) ??
        parentStyle ??
        config.p.textStyle.copyWith(fontWeight: FontWeight.bold);

    TextStyle bodyStyle = tbConfig.bodyStyle?.merge(parentStyle) ??
        parentStyle ??
        config.p.textStyle;

    // 计算每列的最大宽度
    List<double> columnWidths = List.filled(cellCount, tbConfig.minColumnWidth);

    for (int rowIndex = 0; rowIndex < cellContents.length; rowIndex++) {
      List<String> row = cellContents[rowIndex];
      TextStyle currentStyle = rowIndex == 0 ? headerStyle : bodyStyle;

      for (int colIndex = 0; colIndex < row.length && colIndex < cellCount; colIndex++) {
        String cellText = row[colIndex];
        if (cellText.isNotEmpty) {
          // 计算文本的理想宽度，但不超过最大列宽
          double textWidth = _measureTextWidth(cellText, currentStyle, tbConfig.maxColumnWidth);
          columnWidths[colIndex] = math.max(columnWidths[colIndex], textWidth);
        }
      }
    }

    return columnWidths;
  }

  // 计算表格总宽度
  double _calculateTotalTableWidth(int cellCount) {
    double totalWidth = 0.0;

    // 计算所有列的宽度
    for (int i = 0; i < cellCount; i++) {
      totalWidth += tbConfig.maxColumnWidth; // 使用最大宽度进行计算
    }

    // 添加内边距和边框
    double paddingWidth = (tbConfig.headPadding.left + tbConfig.headPadding.right) * cellCount;
    double borderWidth = (cellCount + 1) * 1.0; // 边框宽度

    return totalWidth + paddingWidth + borderWidth;
  }

  // 提取单元格内容的辅助方法
  List<List<String>> _extractCellContents(ElementNode node) {
    List<List<String>> contents = [];

    for (var child in node.children) {
      if (child is TrNode) {
        List<String> rowContents = [];
        for (var cell in child.children) {
          String cellText = _extractTextFromCell(cell);
          rowContents.add(cellText);
        }
        contents.add(rowContents);
      }
    }

    return contents;
  }

  // 从单元格节点中提取文本内容
  String _extractTextFromCell(SpanNode cellNode) {
    try {
      // 尝试通过 build() 方法获取 InlineSpan
      InlineSpan span = cellNode.build();
      return _extractTextFromInlineSpan(span);
    } catch (e) {
      // 如果出错，返回空字符串
      return '';
    }
  }

  // 从 InlineSpan 中提取文本内容
  String _extractTextFromInlineSpan(InlineSpan span) {
    StringBuffer buffer = StringBuffer();

    if (span is TextSpan) {
      // 如果有直接的文本内容
      if (span.text != null) {
        buffer.write(span.text!);
      }
      // 如果有子节点
      if (span.children != null) {
        for (var child in span.children!) {
          buffer.write(_extractTextFromInlineSpan(child));
        }
      }
    } else if (span is WidgetSpan) {
      // 对于 WidgetSpan，我们无法直接提取文本，返回占位符
      buffer.write('[Widget]');
    }

    return buffer.toString();
  }

  // 测量文本宽度，考虑最大宽度限制
  double _measureTextWidth(String text, TextStyle style, double maxWidth) {
    if (text.isEmpty) return tbConfig.minColumnWidth;

    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: tbConfig.enableTextWrap ? null : 1, // 如果启用换行则不限制行数
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: maxWidth);

    // 如果启用了文本换行，返回实际所需的宽度（但不超过最大宽度）
    if (tbConfig.enableTextWrap) {
      return math.min(textPainter.width, maxWidth);
    } else {
      return textPainter.width;
    }
  }
}

class THeadNode extends ElementNode {
  final MarkdownConfig config;
  final WidgetVisitor visitor;

  THeadNode(this.config, this.visitor);

  List<TableRow> get rows => List.generate(children.length, (index) {
    final trChild = children[index] as TrNode;
    return TableRow(
        decoration: config.table.headerRowDecoration,
        children: List.generate(trChild.children.length, (index) {
          final currentTh = trChild.children[index];
          return _buildTableCell(
            currentTh,
            config.table.headPadding,
            isHeader: true,
          );
        }));
  });

  Widget _buildTableCell(SpanNode cellNode, EdgeInsets padding, {bool isHeader = false}) {
    Widget content = ProxyRichText(
      cellNode.build(),
      richTextBuilder: visitor.richTextBuilder,
    );

    // 如果启用了文本换行，使用固定宽度容器
    if (config.table.enableTextWrap) {
      content = Container(
        constraints: BoxConstraints(
          maxWidth: config.table.maxColumnWidth,
          minWidth: config.table.minColumnWidth,
        ),
        child: content,
      );
    }

    return Padding(
      padding: padding,
      child: isHeader ? Center(child: content) : content,
    );
  }

  int get cellCount => (children.first as TrNode).children.length;

  @override
  TextStyle? get style =>
      config.table.headerStyle?.merge(parentStyle) ??
          parentStyle ??
          config.p.textStyle.copyWith(fontWeight: FontWeight.bold);
}

class TBodyNode extends ElementNode {
  final MarkdownConfig config;
  final WidgetVisitor visitor;

  TBodyNode(this.config, this.visitor);

  List<TableRow> buildRows(int cellCount) {
    return List.generate(children.length, (index) {
      final child = children[index] as TrNode;
      final List<Widget> widgets = List.generate(cellCount, (index) => Container());

      for (var i = 0; i < child.children.length; ++i) {
        var c = child.children[i];
        widgets[i] = _buildTableCell(c, config.table.bodyPadding);
      }

      return TableRow(
          decoration: config.table.bodyRowDecoration,
          children: widgets);
    });
  }

  Widget _buildTableCell(SpanNode cellNode, EdgeInsets padding) {
    Widget content = ProxyRichText(
      cellNode.build(),
      richTextBuilder: visitor.richTextBuilder,
    );

    // 如果启用了文本换行，使用固定宽度容器
    if (config.table.enableTextWrap) {
      content = Container(
        constraints: BoxConstraints(
          maxWidth: config.table.maxColumnWidth,
          minWidth: config.table.minColumnWidth,
        ),
        child: content,
      );
    }

    return Padding(
      padding: padding,
      child: content,
    );
  }

  @override
  TextStyle? get style =>
      config.table.bodyStyle?.merge(parentStyle) ??
          parentStyle ??
          config.p.textStyle;
}

class TrNode extends ElementNode {
  @override
  TextStyle? get style => parentStyle;
}

class ThNode extends ElementNode {
  @override
  TextStyle? get style => parentStyle;
}

class TdNode extends ElementNode {
  final Map<String, String> attribute;
  final WidgetVisitor visitor;

  TdNode(this.attribute, this.visitor);

  @override
  InlineSpan build() {
    final align = attribute['align'] ?? '';
    InlineSpan result = childrenSpan;

    if (align.contains('left')) {
      result = WidgetSpan(
          child: Align(
              alignment: Alignment.centerLeft,
              child: ProxyRichText(
                childrenSpan,
                richTextBuilder: visitor.richTextBuilder,
              )));
    } else if (align.contains('center')) {
      result = WidgetSpan(
          child: Align(
              alignment: Alignment.center,
              child: ProxyRichText(
                childrenSpan,
                richTextBuilder: visitor.richTextBuilder,
              )));
    } else if (align.contains('right')) {
      result = WidgetSpan(
          child: Align(
              alignment: Alignment.centerRight,
              child: ProxyRichText(
                childrenSpan,
                richTextBuilder: visitor.richTextBuilder,
              )));
    }
    return result;
  }

  @override
  TextStyle? get style => parentStyle;
}

// import 'dart:math' as math;
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import '../../../config/configs.dart';
// import '../../proxy_rich_text.dart';
// import '../../span_node.dart';
// import '../../widget_visitor.dart';
//
// class TableConfig implements ContainerConfig {
//   final Map<int, TableColumnWidth>? columnWidths;
//   final TableColumnWidth? defaultColumnWidth;
//   final TextDirection? textDirection;
//   final TableBorder? border;
//   final TableCellVerticalAlignment? defaultVerticalAlignment;
//   final TextBaseline? textBaseline;
//   final Decoration? headerRowDecoration;
//   final Decoration? bodyRowDecoration;
//   final TextStyle? headerStyle;
//   final TextStyle? bodyStyle;
//   final EdgeInsets headPadding;
//   final EdgeInsets bodyPadding;
//   final WidgetWrapper? wrapper;
//
//   // 新增：是否启用自动滚动检测
//   final bool enableAutoScroll;
//
//   // 新增：最小表格宽度阈值
//   final double minWidthThreshold;
//
//   const TableConfig({
//     this.columnWidths,
//     this.defaultColumnWidth,
//     this.textDirection,
//     this.border,
//     this.defaultVerticalAlignment,
//     this.textBaseline,
//     this.headerRowDecoration,
//     this.bodyRowDecoration,
//     this.headerStyle,
//     this.bodyStyle,
//     this.wrapper,
//     this.headPadding = const EdgeInsets.fromLTRB(8, 4, 8, 4),
//     this.bodyPadding = const EdgeInsets.fromLTRB(8, 4, 8, 4),
//     this.enableAutoScroll = true,
//     this.minWidthThreshold = 600.0,
//   });
//
//   @nonVirtual
//   @override
//   String get tag => MarkdownTag.table.name;
// }
//
// class TableNode extends ElementNode {
//   final MarkdownConfig config;
//
//   TableNode(this.config);
//
//   TableConfig get tbConfig => config.table;
//
//   @override
//   InlineSpan build() {
//     List<TableRow> rows = [];
//     int cellCount = 0;
//     List<List<String>> cellContents = []; // 存储所有单元格内容用于宽度计算
//
//     for (var child in children) {
//       if (child is THeadNode) {
//         cellCount = child.cellCount;
//         rows.addAll(child.rows);
//         // 收集表头内容
//         cellContents.addAll(_extractCellContents(child));
//       } else if (child is TBodyNode) {
//         rows.addAll(child.buildRows(cellCount));
//         // 收集表体内容
//         cellContents.addAll(_extractCellContents(child));
//       }
//     }
//
//     final tableWidget = Table(
//       columnWidths: tbConfig.columnWidths,
//       defaultColumnWidth: tbConfig.defaultColumnWidth ?? IntrinsicColumnWidth(),
//       textBaseline: tbConfig.textBaseline,
//       textDirection: tbConfig.textDirection,
//       border: tbConfig.border ??
//           TableBorder.all(
//               color: parentStyle?.color ??
//                   config.p.textStyle.color ??
//                   Colors.grey),
//       defaultVerticalAlignment: tbConfig.defaultVerticalAlignment ??
//           TableCellVerticalAlignment.middle,
//       children: rows,
//     );
//
//     // 如果禁用自动滚动，直接返回原始表格
//     if (!tbConfig.enableAutoScroll) {
//       return WidgetSpan(
//           child: SizedBox(
//         width: double.infinity,
//         child: tbConfig.wrapper?.call(tableWidget) ?? tableWidget,
//       ));
//     }
//
//     // 使用 LayoutBuilder 来获取可用宽度并决定是否需要滚动
//     final adaptiveTableWidget = LayoutBuilder(
//       builder: (context, constraints) {
//         // 精确计算表格需要的宽度
//         double calculatedTableWidth = _calculateTableWidth(
//           context,
//           cellContents,
//           cellCount,
//         );
//
//         // 判断是否需要滚动：当计算宽度超过可用宽度时
//         bool needsScrolling = calculatedTableWidth > constraints.maxWidth;
//
//         Widget finalTable = tbConfig.wrapper?.call(tableWidget) ?? tableWidget;
//
//         if (needsScrolling) {
//           // 需要滚动时包装在 SingleChildScrollView 中
//           return SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: ConstrainedBox(
//               constraints: BoxConstraints(
//                 minWidth: calculatedTableWidth,
//               ),
//               child: finalTable,
//             ),
//           );
//         } else {
//           // 不需要滚动时直接返回表格
//           return SizedBox(
//             width: double.infinity,
//             child: finalTable,
//           );
//         }
//       },
//     );
//
//     return WidgetSpan(child: adaptiveTableWidget);
//   }
//
//   // 提取单元格内容的辅助方法
//   List<List<String>> _extractCellContents(ElementNode node) {
//     List<List<String>> contents = [];
//
//     for (var child in node.children) {
//       if (child is TrNode) {
//         List<String> rowContents = [];
//         for (var cell in child.children) {
//           String cellText = _extractTextFromCell(cell);
//           rowContents.add(cellText);
//         }
//         contents.add(rowContents);
//       }
//     }
//
//     return contents;
//   }
//
//   // 从单元格节点中提取文本内容
//   String _extractTextFromCell(SpanNode cellNode) {
//     try {
//       // 尝试通过 build() 方法获取 InlineSpan
//       InlineSpan span = cellNode.build();
//       return _extractTextFromInlineSpan(span);
//     } catch (e) {
//       // 如果出错，返回空字符串
//       return '';
//     }
//   }
//
//   // 从 InlineSpan 中提取文本内容
//   String _extractTextFromInlineSpan(InlineSpan span) {
//     StringBuffer buffer = StringBuffer();
//
//     if (span is TextSpan) {
//       // 如果有直接的文本内容
//       if (span.text != null) {
//         buffer.write(span.text!);
//       }
//       // 如果有子节点
//       if (span.children != null) {
//         for (var child in span.children!) {
//           buffer.write(_extractTextFromInlineSpan(child));
//         }
//       }
//     } else if (span is WidgetSpan) {
//       // 对于 WidgetSpan，我们无法直接提取文本，返回占位符
//       buffer.write('[Widget]');
//     }
//
//     return buffer.toString();
//   }
//
//   // 精确计算表格宽度
//   double _calculateTableWidth(
//     BuildContext context,
//     List<List<String>> cellContents,
//     int cellCount,
//   ) {
//     if (cellContents.isEmpty || cellCount == 0) {
//       return _estimateTableWidth(cellCount);
//     }
//
//     // 获取文本样式
//     TextStyle headerStyle = tbConfig.headerStyle?.merge(parentStyle) ??
//         parentStyle ??
//         config.p.textStyle.copyWith(fontWeight: FontWeight.bold);
//
//     TextStyle bodyStyle = tbConfig.bodyStyle?.merge(parentStyle) ??
//         parentStyle ??
//         config.p.textStyle;
//
//     // 计算每列的最大宽度
//     List<double> columnWidths = List.filled(cellCount, 0.0);
//
//     for (int rowIndex = 0; rowIndex < cellContents.length; rowIndex++) {
//       List<String> row = cellContents[rowIndex];
//       TextStyle currentStyle =
//           rowIndex == 0 ? headerStyle : bodyStyle; // 假设第一行是表头
//
//       for (int colIndex = 0;
//           colIndex < row.length && colIndex < cellCount;
//           colIndex++) {
//         String cellText = row[colIndex];
//         if (cellText.isNotEmpty) {
//           double textWidth = _measureTextWidth(cellText, currentStyle);
//           columnWidths[colIndex] = math.max(columnWidths[colIndex], textWidth);
//         }
//       }
//     }
//
//     // 添加内边距和边框
//     double paddingWidth =
//         (tbConfig.headPadding.left + tbConfig.headPadding.right);
//     double borderWidth = 1.0; // 边框宽度
//
//     double totalWidth = 0.0;
//     for (double colWidth in columnWidths) {
//       // 每列至少要有一个最小宽度
//       double finalColWidth = math.max(colWidth, 50.0) + paddingWidth;
//       totalWidth += finalColWidth;
//     }
//
//     // 添加所有列的边框宽度
//     totalWidth += (cellCount + 1) * borderWidth;
//
//     return totalWidth;
//   }
//
//   // 测量文本宽度
//   double _measureTextWidth(String text, TextStyle style) {
//     if (text.isEmpty) return 0.0;
//
//     final TextPainter textPainter = TextPainter(
//       text: TextSpan(text: text, style: style),
//       maxLines: 1,
//       textDirection: TextDirection.ltr,
//     );
//
//     textPainter.layout();
//     return textPainter.width;
//   }
//
//   // 估算表格宽度的辅助方法
//   double _estimateTableWidth(int cellCount) {
//     // 基础估算：每列最小宽度 + 边框 + 内边距
//     double baseCellWidth = 120.0; // 每列最小宽度
//     double paddingWidth =
//         (tbConfig.headPadding.left + tbConfig.headPadding.right) * cellCount;
//     double borderWidth = (cellCount + 1) * 1.0; // 假设边框宽度为1
//
//     // 如果有自定义列宽，使用自定义配置来估算
//     if (tbConfig.columnWidths != null && tbConfig.columnWidths!.isNotEmpty) {
//       double totalWidth = 0.0;
//       for (int i = 0; i < cellCount; i++) {
//         final columnWidth = tbConfig.columnWidths![i];
//         if (columnWidth is FixedColumnWidth) {
//           totalWidth += columnWidth.value;
//         } else if (columnWidth is FlexColumnWidth) {
//           totalWidth += baseCellWidth * columnWidth.value;
//         } else {
//           totalWidth += baseCellWidth; // 默认宽度
//         }
//       }
//       return totalWidth + paddingWidth + borderWidth;
//     }
//
//     return (baseCellWidth * cellCount) + paddingWidth + borderWidth;
//   }
// }
//
// class THeadNode extends ElementNode {
//   final MarkdownConfig config;
//   final WidgetVisitor visitor;
//
//   THeadNode(this.config, this.visitor);
//
//   List<TableRow> get rows => List.generate(children.length, (index) {
//         final trChild = children[index] as TrNode;
//         return TableRow(
//             decoration: config.table.headerRowDecoration,
//             children: List.generate(trChild.children.length, (index) {
//               final currentTh = trChild.children[index];
//               return Center(
//                 child: Padding(
//                     padding: config.table.headPadding,
//                     child: ProxyRichText(
//                       currentTh.build(),
//                       richTextBuilder: visitor.richTextBuilder,
//                     )),
//               );
//             }));
//       });
//
//   int get cellCount => (children.first as TrNode).children.length;
//
//   @override
//   TextStyle? get style =>
//       config.table.headerStyle?.merge(parentStyle) ??
//       parentStyle ??
//       config.p.textStyle.copyWith(fontWeight: FontWeight.bold);
// }
//
// class TBodyNode extends ElementNode {
//   final MarkdownConfig config;
//   final WidgetVisitor visitor;
//
//   TBodyNode(this.config, this.visitor);
//
//   List<TableRow> buildRows(int cellCount) {
//     return List.generate(children.length, (index) {
//       final child = children[index] as TrNode;
//       final List<Widget> widgets =
//           List.generate(cellCount, (index) => Container());
//       for (var i = 0; i < child.children.length; ++i) {
//         var c = child.children[i];
//         widgets[i] = Padding(
//             padding: config.table.bodyPadding,
//             child: ProxyRichText(
//               c.build(),
//               richTextBuilder: visitor.richTextBuilder,
//             ));
//       }
//       return TableRow(
//           decoration: config.table.bodyRowDecoration, children: widgets);
//     });
//   }
//
//   @override
//   TextStyle? get style =>
//       config.table.bodyStyle?.merge(parentStyle) ??
//       parentStyle ??
//       config.p.textStyle;
// }
//
// class TrNode extends ElementNode {
//   @override
//   TextStyle? get style => parentStyle;
// }
//
// class ThNode extends ElementNode {
//   @override
//   TextStyle? get style => parentStyle;
// }
//
// class TdNode extends ElementNode {
//   final Map<String, String> attribute;
//   final WidgetVisitor visitor;
//
//   TdNode(this.attribute, this.visitor);
//
//   @override
//   InlineSpan build() {
//     final align = attribute['align'] ?? '';
//     InlineSpan result = childrenSpan;
//     if (align.contains('left')) {
//       result = WidgetSpan(
//           child: Align(
//               alignment: Alignment.centerLeft,
//               child: ProxyRichText(
//                 childrenSpan,
//                 richTextBuilder: visitor.richTextBuilder,
//               )));
//     } else if (align.contains('center')) {
//       result = WidgetSpan(
//           child: Align(
//               alignment: Alignment.center,
//               child: ProxyRichText(
//                 childrenSpan,
//                 richTextBuilder: visitor.richTextBuilder,
//               )));
//     } else if (align.contains('right')) {
//       result = WidgetSpan(
//           child: Align(
//               alignment: Alignment.centerRight,
//               child: ProxyRichText(
//                 childrenSpan,
//                 richTextBuilder: visitor.richTextBuilder,
//               )));
//     }
//     return result;
//   }
//
//   @override
//   TextStyle? get style => parentStyle;
// }
