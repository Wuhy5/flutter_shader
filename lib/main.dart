import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

import 'shader_page_view.dart';
import 'shader_painter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter 着色器翻页效果',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ShaderDemoPage(),
    );
  }
}

class ShaderDemoPage extends StatefulWidget {
  const ShaderDemoPage({super.key});

  @override
  State<ShaderDemoPage> createState() => _ShaderDemoPageState();
}

class _ShaderDemoPageState extends State<ShaderDemoPage>
    with TickerProviderStateMixin {

  // 创建页面内容
  List<Widget> get _pages => [
    _buildPageContent(
      title: '第一页',
      content: 'Hello Flutter!\n\n这是着色器翻页效果的演示',
      color: Colors.white,
    ),
    _buildPageContent(
      title: '第二页',
      content: '优化的动画\n\n更流畅的手势响应',
      color: Colors.lightBlue.shade50,
    ),
    _buildPageContent(
      title: '第三页',
      content: '物理模拟\n\n自然的翻页动效',
      color: Colors.lightGreen.shade50,
    ),
    _buildPageContent(
      title: '第四页',
      content: '高性能渲染\n\n60fps 丝滑体验',
      color: Colors.orange.shade50,
    ),
    _buildPageContent(
      title: '第五页',
      content: '最后一页\n\n感谢体验！',
      color: Colors.pink.shade50,
    ),
  ];

  Widget _buildPageContent({
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black54,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Flutter 着色器翻页效果'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(40.0),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ShaderPageView(
            shaderAsset: 'shaders/page_curl.frag',
            children: _pages,
            animationDuration: const Duration(milliseconds: 350),
            animationCurve: Curves.easeOutQuart,
            pageMargin: 0.0,
            onPageChanged: (index) {
              setState(() {
                _currentPageIndex = index;
              });
            },
          ),
        ),
      ),
    );
  }
}
