import 'dart:math' as math;
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

class _ShaderDemoPageState extends State<ShaderDemoPage>
    with TickerProviderStateMixin {
  Offset _dragPosition = Offset.zero;
  Offset _dragStart = Offset.zero;

  bool _isDragging = false;
  bool _isAnimating = false;

  ui.Image? _frontImage;
  ui.Image? _backImage;
  Size _currentSize = Size.zero;

  // 动画控制器
  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;

  // 动画起始和结束位置
  Offset _animationStartPosition = Offset.zero;
  Offset _animationEndPosition = Offset.zero;

  // 惯性动画相关
  Offset _velocity = Offset.zero;
  late AnimationController _flingController;

  @override
  void initState() {
    super.initState();
    _currentSize = widget.screenSize;

    // 初始化动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    // 初始化惯性动画控制器
    _flingController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.fastOutSlowIn,
          ),
        );
    _offsetAnimation.addListener(() {
      if (_isAnimating) {
        _dragPosition = _offsetAnimation.value;
        // 使用markNeedsPaint来避免重建整个widget
        if (mounted) {
          setState(() {});
        }
      }
    });
    _offsetAnimation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _handleAnimationComplete();
      }
    });

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
                // 如果正在动画中，先停止动画
                if (_isAnimating) {
                  _animationController.stop();
                  _flingController.stop();
                  _isAnimating = false;
                }

                setState(() {
                  _isDragging = true;
                  _dragStart = details.localPosition;
                  _dragPosition = details.localPosition;
                  _velocity = Offset.zero;
                });
              },
              onPanUpdate: (details) {
                if (!_isAnimating) {
                  // 只在非动画状态下更新
                  setState(() {
                    _dragPosition = details.localPosition;
                  });
                }
              },
              onPanEnd: (details) {
                // 计算速度
                _velocity = details.velocity.pixelsPerSecond;

                // 计算动画目标位置
                final targetPosition = _calculateAnimationTarget();
                final distance = (targetPosition - _dragPosition).distance;

                // 根据速度和距离调整动画参数
                final speed = _velocity.distance;
                final shouldUseFling = speed > 500 && distance > 50;

                setState(() {
                  _isDragging = false;
                  _isAnimating = true;
                  _animationStartPosition = _dragPosition;
                  _animationEndPosition = targetPosition;
                });

                if (shouldUseFling) {
                  // 使用惯性动画
                  _startFlingAnimation(targetPosition, speed);
                } else {
                  // 使用普通动画
                  _startNormalAnimation(targetPosition, distance);
                }
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
                    isDragging: _isDragging || _isAnimating,
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

  @override
  void dispose() {
    _animationController.dispose();
    _flingController.dispose();
    super.dispose();
  }

  // 交换前后图片
  void _swapImages() {
    final temp = _frontImage;
    _frontImage = _backImage;
    _backImage = temp;
  }

  // 判断是否应该完成翻页
  bool _shouldCompletePage() {
    if (_dragStart == Offset.zero) return false;

    final dragDistance = (_dragPosition - _dragStart).distance;
    final screenDiagonal = math.sqrt(
      _currentSize.width * _currentSize.width +
          _currentSize.height * _currentSize.height,
    );

    // 基础距离判断 - 降低阈值使翻页更容易
    final distanceThreshold = screenDiagonal * 0.2;
    final hasEnoughDistance = dragDistance > distanceThreshold;

    // 速度判断 - 如果速度足够快，进一步降低距离要求
    final speed = _velocity.distance;
    final hasEnoughSpeed = speed > 600;
    final speedBasedDistance = hasEnoughSpeed
        ? distanceThreshold * 0.5
        : distanceThreshold;

    // 方向判断 - 确保拖拽方向与翻页方向一致
    final dragDirection = _dragPosition - _dragStart;
    final isCurlFromRight = _dragStart.dx > _currentSize.width / 2;
    final isCorrectDirection = isCurlFromRight
        ? dragDirection.dx < 0
        : dragDirection.dx > 0;

    // 增加渐进式判断：如果拖拽距离很大，即使方向稍有偏差也允许翻页
    final isLargeDrag = dragDistance > screenDiagonal * 0.3;
    final finalDirectionCheck = isCorrectDirection || isLargeDrag;

    return finalDirectionCheck &&
        (hasEnoughDistance ||
            (hasEnoughSpeed && dragDistance > speedBasedDistance));
  }

  // 计算动画目标位置
  Offset _calculateAnimationTarget() {
    if (_shouldCompletePage()) {
      // 完成翻页，计算最终位置
      final isCurlFromRight = _dragStart.dx > _currentSize.width / 2;
      final halfHeight = _currentSize.height / 2;

      // 判断起点是否在Y轴中点附近
      final isNearVerticalCenter =
          (_dragStart.dy - halfHeight).abs() < halfHeight * 0.3; // 30%容差

      if (isNearVerticalCenter) {
        // 起点在Y轴中点附近，终点设为对应边界的中点
        if (isCurlFromRight) {
          // 从右往左翻页，移动到左边界中点
          return Offset(0, halfHeight);
        } else {
          // 从左往右翻页，移动到右边界中点
          return Offset(_currentSize.width, halfHeight);
        }
      } else {
        // 起点不在Y轴中点，终点设为对应的对角点
        if (isCurlFromRight) {
          // 从右往左翻页，移动到左边界对角点
          final targetY = _dragStart.dy < halfHeight
              ? 0.0
              : _currentSize.height;
          return Offset(0, targetY);
        } else {
          // 从左往右翻页，移动到右边界对角点
          final targetY = _dragStart.dy < halfHeight
              ? 0.0
              : _currentSize.height;
          return Offset(_currentSize.width, targetY);
        }
      }
    } else {
      // 回到起始位置
      return _dragStart;
    }
  }

  // 启动惯性动画
  void _startFlingAnimation(Offset targetPosition, double speed) {
    // 根据速度动态调整动画时长，更快的速度用更长的时间来减速
    final baseDuration = math.max(
      250,
      math.min(600, (1200 * 400 / speed).round()),
    );
    final duration = Duration(milliseconds: baseDuration);

    _flingController.duration = duration;

    final flingAnimation =
        Tween<Offset>(
          begin: _animationStartPosition,
          end: _animationEndPosition,
        ).animate(
          CurvedAnimation(
            parent: _flingController,
            curve: Curves.fastOutSlowIn, // 更自然的缓动曲线
          ),
        );

    flingAnimation.addListener(() {
      if (_isAnimating && mounted) {
        _dragPosition = flingAnimation.value;
        setState(() {});
      }
    });

    flingAnimation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _handleAnimationComplete();
      }
    });

    _flingController.forward(from: 0.0);
  }

  // 启动普通动画
  void _startNormalAnimation(Offset targetPosition, double distance) {
    // 根据距离动态调整动画时长，让短距离动画更快完成
    final baseDuration = math.max(120, math.min(400, (distance * 1.5).round()));
    final duration = Duration(milliseconds: baseDuration);

    _animationController.duration = duration;

    _offsetAnimation =
        Tween<Offset>(
          begin: _animationStartPosition,
          end: _animationEndPosition,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: distance > 150 ? Curves.fastOutSlowIn : Curves.easeInCubic,
          ),
        );

    _animationController.forward(from: 0.0);
  }

  // 处理动画完成
  void _handleAnimationComplete() {
    setState(() {
      _isAnimating = false;
      // 动画完成后重置状态
      if (_shouldCompletePage()) {
        // 翻页完成，交换前后图片
        _swapImages();
      }
      _dragPosition = Offset.zero;
      _dragStart = Offset.zero;
      _velocity = Offset.zero;
    });
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
    shader.setFloat(1, size.height); // iResolution.y    // 设置鼠标位置
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
