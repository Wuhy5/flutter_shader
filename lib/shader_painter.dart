import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 着色器画布绘制器
/// 负责处理翻页效果的着色器渲染
class ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image frontImage;
  final ui.Image backImage;
  final Offset mousePos;
  final Offset mouseStart;
  final bool isDragging;
  final double animationProgress;

  Size _lastSize = Size.zero;

  ShaderPainter({
    required this.shader,
    required this.frontImage,
    required this.backImage,
    required this.mousePos,
    required this.mouseStart,
    required this.isDragging,
    this.animationProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _lastSize = size;

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

    // 判断翻页方向
    // 1.0 表示从左向右翻页，-1.0 表示从右向左翻页
    final iCurlDirection = mouseStart.dx > size.width / 2 ? -1.0 : 1.0;
    if (isDragging) {
      shader.setFloat(
        6,
        iCurlDirection > 0 ? 1.0 : -1.0, // 根据鼠标位置判断翻页方向
      ); // iCurlDirection
    } else {
      shader.setFloat(6, -1.0); // 默认从右向左翻页
    }

    // 设置动画进度（可用于更细致的动画控制）
    shader.setFloat(7, animationProgress); // iAnimationProgress

    // 绘制全屏矩形
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(ShaderPainter oldDelegate) {
    // 重新绘制条件：任何关键参数发生变化
    return oldDelegate.mousePos != mousePos ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.mouseStart != mouseStart ||
        oldDelegate._lastSize != _lastSize ||
        oldDelegate.frontImage != frontImage ||
        oldDelegate.backImage != backImage ||
        oldDelegate.animationProgress != animationProgress;
  }
}
