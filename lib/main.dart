import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_shader/shader_page_view.dart';

// 应用入口点
void main() {
  runApp(const MyApp());
}

// 应用的根 Widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter 着色器翻页效果', // 应用标题
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ), // 应用主题颜色
      ),
      // 将 ShaderDemoPage 设置为主页，并传入屏幕尺寸
      home: ShaderDemoPage(screenSize: MediaQuery.of(context).size),
    );
  }
}

// 着色器演示页面，是一个 StatefulWidget，因为其状态会随时间改变
class ShaderDemoPage extends StatefulWidget {
  const ShaderDemoPage({super.key, required this.screenSize});

  // 屏幕尺寸，由 MyApp 传入
  final Size screenSize;

  @override
  State<ShaderDemoPage> createState() => _ShaderDemoPageState();
}

// ShaderDemoPage 的状态管理类
class _ShaderDemoPageState extends State<ShaderDemoPage> {
  // 页面管理
  int _currentPageIndex = 0; // 当前显示的页面索引，会通过 ShaderPageView 的回调更新
  static const int _totalPages = 5; // 固定的总页面数量
  // 存储每个页面的 ui.Image 对象列表，初始化为 null
  final List<ui.Image?> _pageImages = List.filled(_totalPages, null);
  bool _imagesLoaded = false; // 标记图片是否已加载完成

  // 页面内容区域的边距
  static const double _pageMargin = 40.0;
  // 计算实际用于显示页面内容的尺寸（屏幕尺寸减去两边的边距）
  Size get _pageScreenSize => Size(
    widget.screenSize.width - _pageMargin * 2,
    widget.screenSize.height - _pageMargin * 2,
  );

  @override
  void initState() {
    super.initState();
    _loadImages(); // 初始化时加载所有页面图片
  }

  @override
  void didUpdateWidget(ShaderDemoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当依赖的 widget 更新时调用（例如屏幕尺寸变化）
    if (oldWidget.screenSize != widget.screenSize) {
      // 如果屏幕尺寸发生变化，重新加载图片
      // 假设图片内容生成依赖于 _pageScreenSize
      _loadImages();
    }
  }

  // 异步加载所有页面的图片内容
  Future<void> _loadImages() async {
    // 在加载图片前确保 _pageScreenSize 是最新的
    final currentDisplaySize = _pageScreenSize;
    // 如果显示尺寸为空（例如，在 widget 构建完成前），则不进行加载
    if (currentDisplaySize.isEmpty) return;

    // 定义5个页面的内容数据
    final pageContents = [
      {'title': '第一页', 'content': 'Hello Flutter!', 'color': Colors.white},
      {
        'title': '第二页',
        'content': 'Page 2\n着色器翻页效果',
        'color': Colors.lightBlue.shade50,
      },
      {
        'title': '第三页',
        'content': 'Page 3\n中间页面',
        'color': Colors.lightGreen.shade50,
      },
      {
        'title': '第四页',
        'content': 'Page 4\n倒数第二页',
        'color': Colors.orange.shade50,
      },
      {'title': '第五页', 'content': 'Page 5\n最后一页', 'color': Colors.pink.shade50},
    ];

    // 遍历每个页面，生成对应的 ui.Image
    for (int i = 0; i < _totalPages; i++) {
      final recorder = ui.PictureRecorder(); // 用于记录绘制操作
      final canvas = Canvas(recorder); // 获取画布
      // 设置段落样式
      final paragraphStyle = ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      );
      // 构建段落内容
      final builder = ui.ParagraphBuilder(paragraphStyle)
        ..pushStyle(ui.TextStyle(color: Colors.black)) // 设置文本颜色
        ..addText('${pageContents[i]['title']}\n${pageContents[i]['content']}');
      final paragraph = builder.build()
        ..layout(
          ui.ParagraphConstraints(width: currentDisplaySize.width),
        ); // 对段落进行布局

      // 绘制页面背景色
      canvas.drawRect(
        Rect.fromLTWH(
          0,
          0,
          currentDisplaySize.width,
          currentDisplaySize.height,
        ),
        Paint()
          ..isAntiAlias =
              true // 抗锯齿
          ..color = pageContents[i]['color'] as Color, // 页面背景色
      );
      // 绘制段落文本
      canvas.drawParagraph(paragraph, Offset(0, 100)); // 文本绘制的起始偏移

      // 结束记录并将绘制内容转换为 ui.Image
      final img = await recorder.endRecording().toImage(
        currentDisplaySize.width.toInt(), // 图片宽度
        currentDisplaySize.height.toInt(), // 图片高度
      );
      _pageImages[i] = img; // 存储生成的图片
    }

    // 如果 widget 仍然挂载，则更新状态以触发 UI 重建
    if (mounted) {
      setState(() {
        _imagesLoaded = true; // 标记图片已加载完成
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDisplaySize = _pageScreenSize; // 获取当前计算的页面显示尺寸
    return Scaffold(
      backgroundColor: Colors.grey[200], // 设置页面背景色
      body: Center(
        // 将内容居中显示
        child: Stack(
          // 使用 Stack 布局，允许子 widget 叠加
          alignment: Alignment.center, // Stack 内子 widget 对齐方式
          children: [
            // ShaderPageView 组件，用于显示和处理翻页效果
            if (_imagesLoaded &&
                currentDisplaySize.width > 0 &&
                currentDisplaySize.height > 0)
              ShaderPageView(
                // 使用 ValueKey 确保在 currentDisplaySize 变化时重建 ShaderPageView
                key: ValueKey(currentDisplaySize),
                images: _pageImages, // 传入已加载的图片列表
                pageSize: currentDisplaySize, // 传入计算好的页面尺寸
                initialPage: _currentPageIndex, // 初始显示的页面索引
                // 页面变化时的回调，用于更新 _currentPageIndex
                onPageChanged: (index) {
                  if (mounted) {
                    setState(() {
                      _currentPageIndex = index;
                    });
                  }
                },
              )
            else if (currentDisplaySize.isEmpty)
              // 如果屏幕尺寸为零，显示提示信息
              Center(child: Text("Screen size is zero, cannot display pages."))
            else
              // 如果图片未加载完成，显示加载指示器
              Center(child: const CircularProgressIndicator()),

            // 页面圆点指示器
            Positioned(
              bottom: 20, // 距离底部 20 像素
              child: Row(
                // 使用 Row 横向排列圆点
                mainAxisAlignment: MainAxisAlignment.center, // 圆点居中对齐
                children: List.generate(_totalPages, (index) {
                  // 生成 _totalPages 个圆点
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4), // 圆点间距
                    width: 8, // 圆点宽度
                    height: 8, // 圆点高度
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, // 圆形
                      // 当前页面索引对应的圆点显示为蓝色，其他为灰色
                      color: index == _currentPageIndex
                          ? Colors.blue
                          : Colors.grey.shade400,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
