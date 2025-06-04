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

  ui.Image? _frontImage;
  ui.Image? _backImage;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    // 使用文本绘制两个图片
    // 使用文本绘制两个图片
    final recorder1 = ui.PictureRecorder();
    final canvas1 = Canvas(recorder1);
    canvas1.drawColor(Colors.yellow, ui.BlendMode.src);
    final textStyle = ui.TextStyle(color: Colors.black, fontSize: 48);
    final paragraphStyle = ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontWeight: FontWeight.bold,
      fontSize: 48,
    );
    final builder1 = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText('第一页\nHello Flutter!');
    final paragraph1 = builder1.build()
      ..layout(ui.ParagraphConstraints(width: 300));
    canvas1.drawRect(
      Rect.fromLTWH(0, 0, 300, 300),
      Paint()..color = Colors.white,
    );
    canvas1.drawParagraph(paragraph1, Offset(0, 100));
    final img1 = await recorder1.endRecording().toImage(300, 300);

    final recorder2 = ui.PictureRecorder();
    final canvas2 = Canvas(recorder2);
    final builder2 = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText('第二页\nPage 2');
    final paragraph2 = builder2.build()
      ..layout(ui.ParagraphConstraints(width: 300));
    canvas2.drawRect(
      Rect.fromLTWH(0, 0, 300, 300),
      Paint()..color = Colors.lightBlue.shade50,
    );
    canvas2.drawParagraph(paragraph2, Offset(0, 100));
    final img2 = await recorder2.endRecording().toImage(300, 300);

    setState(() {
      _frontImage = img1;
      _backImage = img2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('着色器翻页效果'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
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
                  });
                },
                child: ShaderBuilder(
                  assetKey: 'shaders/page_curl.frag',
                  (context, shader, child) => CustomPaint(
                    size: Size(300, 300),
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
            const SizedBox(height: 20),
            const Text('从右侧边缘向左拖动来查看翻页效果'),
          ],
        ),
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
    // 设置着色器输入参数
    shader.setFloat(0, size.width); // iResolution.x
    shader.setFloat(1, size.height); // iResolution.y

    // 设置鼠标位置
    shader.setFloat(2, mousePos.dx); // iMouse.x
    shader.setFloat(3, mousePos.dy); // iMouse.y
    shader.setFloat(4, isDragging ? mouseStart.dx : 0.0); // iMouse.z
    shader.setFloat(5, isDragging ? mouseStart.dy : 0.0); // iMouse.w

    // 设置前后图片
    shader.setImageSampler(0, frontImage); // iFrontImage
    shader.setImageSampler(1, backImage); // iBackImage
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
