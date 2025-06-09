import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_shader/shader_painter.dart';
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

  // 页面管理
  int _currentPageIndex = 0;
  static const int _totalPages = 5;
  final List<ui.Image?> _pageImages = List.filled(_totalPages, null);

  ui.Image? _frontImage;
  ui.Image? _backImage;
  Size _currentSize = Size.zero;

  // 动画控制器（统一使用惯性动画）
  late AnimationController _flingController;
  late Animation<Offset> _offsetAnimation;

  // 动画起始和结束位置
  Offset _animationStartPosition = Offset.zero;
  Offset _animationEndPosition = Offset.zero;

  // 惯性动画相关
  Offset _velocity = Offset.zero;

  // 页面大小减去上下左右的40像素边距
  static const double _pageMargin = 40.0;
  Size get _pageScreenSize => Size(
    widget.screenSize.width - _pageMargin * 2,
    widget.screenSize.height - _pageMargin * 2,
  );

  // 最小动画速度（当检测速度过低时使用）
  static const double _minAnimationSpeed = 800.0;

  @override
  void initState() {
    super.initState();
    _currentSize = _pageScreenSize;

    // 初始化惯性动画控制器
    _flingController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _flingController,
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
    if (oldWidget.screenSize != _pageScreenSize) {
      _currentSize = _pageScreenSize;
      _loadImages();
    }
  }

  Future<void> _loadImages() async {
    // 创建5个不同的页面内容
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

    for (int i = 0; i < _totalPages; i++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paragraphStyle = ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      );
      final builder = ui.ParagraphBuilder(paragraphStyle)
        ..pushStyle(ui.TextStyle(color: Colors.black))
        ..addText('${pageContents[i]['title']}\n${pageContents[i]['content']}');
      final paragraph = builder.build()
        ..layout(ui.ParagraphConstraints(width: _pageScreenSize.width));

      canvas.drawRect(
        Rect.fromLTWH(0, 0, _pageScreenSize.width, _pageScreenSize.height),
        Paint()
          ..isAntiAlias = true
          ..color = pageContents[i]['color'] as Color,
      );
      canvas.drawParagraph(paragraph, Offset(0, 100));

      final img = await recorder.endRecording().toImage(
        _pageScreenSize.width.toInt(),
        _pageScreenSize.height.toInt(),
      );
      _pageImages[i] = img;
    }

    setState(() {
      _frontImage = _pageImages[_currentPageIndex];
      _backImage =
          _pageImages[_currentPageIndex + 1 < _totalPages
              ? _currentPageIndex + 1
              : _currentPageIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          // 着色器画布
          if (_frontImage != null && _backImage != null)
            GestureDetector(
              onPanStart: (details) {
                // 检查是否可以翻页
                if (!_canFlipPage(details.localPosition)) {
                  return; // 如果不能翻页，直接返回
                }
                // 如果正在动画中，先停止动画
                if (_isAnimating) {
                  _flingController.stop();
                  _isAnimating = false;
                }

                setState(() {
                  // 更新背景图片以显示正确的下一页
                  _updateBackImage(details.localPosition);
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
                if (!_isDragging) return; // 如果没有拖动
                // 计算速度
                _velocity = details.velocity.pixelsPerSecond;
                final speed = _velocity.distance;

                // 计算动画目标位置
                final targetPosition = _calculateAnimationTarget();

                // 如果速度过低，使用最小恒定速度
                final effectiveSpeed = speed < _minAnimationSpeed
                    ? _minAnimationSpeed
                    : speed;

                setState(() {
                  _isDragging = false;
                  _isAnimating = true;
                  _animationStartPosition = _dragPosition;
                  _animationEndPosition = targetPosition;
                });

                // 统一使用惯性动画
                _startFlingAnimation(targetPosition, effectiveSpeed);
              },
              child: ShaderBuilder(
                assetKey: 'shaders/page_curl.frag',
                (context, shader, child) => CustomPaint(
                  size: _pageScreenSize,
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
            Center(child: const CircularProgressIndicator()),

          // 页面圆点指示器
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalPages, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
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
    );
  }

  @override
  void dispose() {
    _flingController.dispose();
    super.dispose();
  }

  // 交换前后图片并更新页面索引
  void _swapImages() {
    final isCurlFromRight = _dragStart.dx > _currentSize.width / 2;

    if (isCurlFromRight) {
      // 从右往左翻页，前往下一页
      if (_currentPageIndex < _totalPages - 1) {
        _currentPageIndex++;
        _frontImage = _pageImages[_currentPageIndex];
        _backImage = _currentPageIndex < _totalPages - 1
            ? _pageImages[_currentPageIndex + 1]
            : _pageImages[_currentPageIndex];
      }
    } else {
      // 从左往右翻页，前往上一页
      if (_currentPageIndex > 0) {
        _currentPageIndex--;
        _frontImage = _pageImages[_currentPageIndex];
        _backImage = _currentPageIndex > 0
            ? _pageImages[_currentPageIndex - 1]
            : _pageImages[_currentPageIndex];
      }
    }
  }

  // 检查是否可以翻页
  bool _canFlipPage(Offset position) {
    final isCurlFromRight = position.dx > _currentSize.width / 2;

    if (isCurlFromRight) {
      // 从右往左翻页，检查是否有下一页
      return _currentPageIndex < _totalPages - 1;
    } else {
      // 从左往右翻页，检查是否有上一页
      return _currentPageIndex > 0;
    }
  }

  // 更新背景图片以显示正确的下一页
  void _updateBackImage(Offset startPosition) {
    final isCurlFromRight = startPosition.dx > _currentSize.width / 2;

    if (isCurlFromRight && _currentPageIndex < _totalPages - 1) {
      // 从右往左翻页，显示下一页
      _backImage = _pageImages[_currentPageIndex + 1];
    } else if (!isCurlFromRight && _currentPageIndex > 0) {
      // 从左往右翻页，显示上一页
      _backImage = _pageImages[_currentPageIndex - 1];
    }
    print(
      '更新背景图片，当前页: $_currentPageIndex, 翻页方向: ${isCurlFromRight ? '右向左' : '左向右'}',
    );
  }

  // 判断是否应该完成翻页
  bool _shouldCompletePage() {
    if (_dragStart == Offset.zero) return false;

    // 检查是否可以翻页
    if (!_canFlipPage(_dragStart)) return false;

    final dragDistance = (_dragPosition - _dragStart).distance;
    final screenDiagonal = math.sqrt(
      _currentSize.width * _currentSize.width +
          _currentSize.height * _currentSize.height,
    );

    // 基础距离判断 - 降低阈值使翻页更容易
    final distanceThreshold = screenDiagonal * 0.4;
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
    final isLargeDrag = dragDistance > screenDiagonal * 0.4;
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

  // 启动惯性动画（统一的动画方法）
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

    // 更新动画监听器
    _offsetAnimation = flingAnimation;
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
