import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

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

class _ShaderDemoPageState extends State<ShaderDemoPage> {
  Offset _dragPosition = Offset.zero;
  Offset _dragStart = Offset.zero;
  bool _isDragging = false;
  int _totalPages = 8;
  int _pageIndex = 1;
  List<ui.Image> _pages = [];
  bool _isTurnNext = true;
  bool _isTurnPrev = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    // 使用文本绘制8个图片
    for (int i = 0; i < _totalPages; i++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()
        ..color = Colors.primaries[i % Colors.primaries.length]
        ..style = PaintingStyle.fill;

      // 绘制一个填充矩形作为示例图片
      canvas.drawRect(Rect.fromLTWH(0, 0, 300, 400), paint);

      // 绘制文本
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Page ${i + 1}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(150 - textPainter.width / 2, 150 - textPainter.height / 2),
      );

      // 将绘制的内容转换为图片
      final picture = recorder.endRecording();
      final image = await picture.toImage(300, 400);
      _pages.add(image);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 着色器画布
          if (_pages.isNotEmpty)
            GestureDetector(
              onPanStart: (details) {
                setState(() {
                  _isDragging = true;
                  _dragStart = details.localPosition;
                  _dragPosition = details.localPosition;
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  _dragPosition = details.localPosition;
                });
              },
              onPanEnd: (details) {
                setState(() {
                  _isDragging = false;
                });
              },
              child: ShaderBuilder(
                assetKey: 'shaders/page_curl.frag',
                (context, shader, child) => CustomPaint(
                  size: Size(300, 400),
                  painter: ShaderPainter(
                    shader: shader,
                    preImage: _isTurnPrev ? _pages[_pageIndex - 1] : null,
                    frontImage: _pages[_pageIndex],
                    backImage: _isTurnNext ? _pages[_pageIndex + 1] : null,
                    mousePos: _dragPosition,
                    mouseStart: _dragStart,
                    isDragging: _isDragging,
                  ),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            )
          else
            const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text('从右侧边缘向左拖动来查看翻页效果'),
        ],
      ),
    );
  }
}

class ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image? preImage;
  final ui.Image frontImage;
  final ui.Image? backImage;
  final Offset mousePos;
  final Offset mouseStart;
  final bool isDragging;

  ShaderPainter({
    required this.shader,
    this.preImage,
    required this.frontImage,
    this.backImage,
    required this.mousePos,
    required this.mouseStart,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 设置着色器输入参数
    shader.setFloat(0, size.width); // iResolution.x
    shader.setFloat(1, size.height); // iResolution.y

    // 设置鼠标位置
    shader.setFloat(2, mousePos.dx); // iMouse.x
    shader.setFloat(3, mousePos.dy); // iMouse.y
    shader.setFloat(4, isDragging ? mouseStart.dx : 0.0); // iMouse.z
    shader.setFloat(5, isDragging ? mouseStart.dy : 0.0); // iMouse.w

    // 设置图片
    if (preImage != null) {
      shader.setImageSampler(0, preImage!); // iPreImage
    }
    shader.setImageSampler(1, frontImage); // iBackImage
    if (backImage != null) {
      shader.setImageSampler(2, backImage!); // iFrontImage
    }
    // 绘制全屏矩形
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    print('Mouse Position: ${mousePos.dx}, ${mousePos.dy}');
  }

  @override
  bool shouldRepaint(ShaderPainter oldDelegate) {
    // 重新绘制条件：鼠标位置、拖动状态或起始位置发生变化
    print(
      'Repainting: ${oldDelegate.mousePos != mousePos}, '
      '${oldDelegate.isDragging != isDragging}, '
      '${oldDelegate.mouseStart != mouseStart}',
    );
    return oldDelegate.mousePos != mousePos ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.mouseStart != mouseStart;
  }
}
