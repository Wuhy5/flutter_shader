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
      home: ShaderDemoPage(screenSize: MediaQuery.of(context).size),
    );
  }
}

class ShaderDemoPage extends StatefulWidget {
  const ShaderDemoPage({super.key, required this.screenSize});

  final Size screenSize;

  @override
  State<ShaderDemoPage> createState() => _ShaderDemoPageState();
}

class _ShaderDemoPageState extends State<ShaderDemoPage> {
  Offset _dragPosition = Offset.zero;
  Offset _dragStart = Offset.zero;

  bool _isDragging = false;

  ui.Image? _frontImage;
  ui.Image? _backImage;
  Size _currentSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _currentSize = widget.screenSize;
    _loadImages();
  }

  @override
  void didUpdateWidget(ShaderDemoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 检查屏幕尺寸是否变化
    if (oldWidget.screenSize != widget.screenSize) {
      _currentSize = widget.screenSize;
      _loadImages();
    }
  }

  Future<void> _loadImages() async {
    // 使用文本绘制两个图片
    final recorder1 = ui.PictureRecorder();
    final canvas1 = Canvas(recorder1);
    final paragraphStyle = ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontWeight: FontWeight.bold,
      fontSize: 20,
    );
    final builder1 = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(ui.TextStyle(color: Colors.black))
      ..addText('第一页\nHello Flutter!');
    final paragraph1 = builder1.build()
      ..layout(ui.ParagraphConstraints(width: widget.screenSize.width));
    canvas1.drawRect(
      Rect.fromLTWH(0, 0, widget.screenSize.width, widget.screenSize.height),
      Paint()
        ..isAntiAlias = true
        ..color = Colors.white,
    );
    canvas1.drawParagraph(paragraph1, Offset(0, 100));
    final img1 = await recorder1.endRecording().toImage(
      widget.screenSize.width.toInt(),
      widget.screenSize.height.toInt(),
    );

    final recorder2 = ui.PictureRecorder();
    final canvas2 = Canvas(recorder2);
    final builder2 = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(ui.TextStyle(color: Colors.black))
      ..addText('第二页\nPage 2');
    final paragraph2 = builder2.build()
      ..layout(ui.ParagraphConstraints(width: widget.screenSize.width));
    canvas2.drawRect(
      Rect.fromLTWH(0, 0, widget.screenSize.width, widget.screenSize.height),
      Paint()
        ..isAntiAlias = true
        ..color = Colors.lightBlue.shade50,
    );
    canvas2.drawParagraph(paragraph2, Offset(0, 100));
    final img2 = await recorder2.endRecording().toImage(
      widget.screenSize.width.toInt(),
      widget.screenSize.height.toInt(),
    );

    setState(() {
      _frontImage = img1;
      _backImage = img2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 着色器画布
          if (_frontImage != null && _backImage != null)
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
                  _dragPosition = Offset.zero;
                  _dragStart = Offset.zero;
                });
              },
              child: ShaderBuilder(
                assetKey: 'shaders/page_curl.frag',
                (context, shader, child) => CustomPaint(
                  size: widget.screenSize,
                  painter: ShaderPainter(
                    shader: shader,
                    frontImage: _frontImage!,
                    backImage: _backImage!,
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
        ],
      ),
    );
  }
}

class ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image frontImage;
  final ui.Image backImage;
  final Offset mousePos;
  final Offset mouseStart;
  final bool isDragging;
  Size lastSize = Size.zero;

  ShaderPainter({
    required this.shader,
    required this.frontImage,
    required this.backImage,
    required this.mousePos,
    required this.mouseStart,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    lastSize = size;

    // 设置着色器输入参数
    shader.setFloat(0, size.width); // iResolution.x
    shader.setFloat(1, size.height); // iResolution.y

    // 设置鼠标位置
    shader.setFloat(2, isDragging ? mousePos.dx : size.width); // iMouse.x
    shader.setFloat(3, isDragging ? mousePos.dy : 0); // iMouse.y
    shader.setFloat(4, isDragging ? mouseStart.dx : size.width); // iMouse.z
    shader.setFloat(5, isDragging ? mouseStart.dy : 0.0); // iMouse.w

    // 设置前后图片
    shader.setImageSampler(0, frontImage); // iFrontImage
    shader.setImageSampler(1, backImage); // iBackImage

    // 判断是否从左向右翻页或从右向左翻页
    // 1.0 表示从左向右翻页，-1.0 表示从右向左翻页
    final iCurlDirection = mouseStart.dx > size.width / 2 ? -1.0 : 1.0;
    if (isDragging) {
      shader.setFloat(
        6,
        iCurlDirection > 0 ? 1.0 : -1.0, // 根据鼠标位置判断翻页方向
      ); // iCurlDirection
    } else {
      shader.setFloat(6, -1.0); // 默认从左向右翻页
    }

    // 绘制全屏矩形
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    print(
      '绘制着色器，鼠标位置: $mousePos, 起始位置: $mouseStart, 是否拖动: $isDragging , 翻页方向: ${iCurlDirection > 0 ? '左向右' : '右向左'}',
    );
  }

  @override
  bool shouldRepaint(ShaderPainter oldDelegate) {
    // 重新绘制条件：鼠标位置、拖动状态、起始位置或大小发生变化
    return oldDelegate.mousePos != mousePos ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.mouseStart != mouseStart ||
        oldDelegate.lastSize != lastSize ||
        oldDelegate.frontImage != frontImage ||
        oldDelegate.backImage != backImage;
  }
}
