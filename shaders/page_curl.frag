#include <flutter/runtime_effect.glsl>

#define pi 3.14159265358979323846
#define radius .1

// 着色器输入变量
uniform vec2 iResolution; // 渲染分辨率
uniform vec4 iMouse; // 鼠标位置和状态
uniform sampler2D preImage; // 上一页图片
uniform sampler2D frontImage; // 当前页图片
uniform sampler2D backImage; // 下一页图片

// 输出颜色变量
out vec4 fragColor;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    // 坐标系处理
    float aspect = iResolution.x / iResolution.y;
    vec2 uv = fragCoord * vec2(aspect, 1.) / iResolution.xy; // 归一化坐标（考虑宽高比）
    vec2 mouse = iMouse.xy * vec2(aspect, 1.) / iResolution.xy; // 归一化鼠标位置

    // 计算翻页方向
    vec2 mouseDir = normalize(abs(iMouse.zw) - iMouse.xy); // 鼠标移动方向
    vec2 origin = clamp(mouse - mouseDir * mouse.x / mouseDir.x, 0., 1.); // 翻页起点

    // 计算翻页距离
    float mouseDist = clamp(length(mouse - origin) +
                            (aspect - (abs(iMouse.z)/iResolution.x)*aspect)/mouseDir.x, 0., aspect/mouseDir.x);

    // 根据鼠标起点位置自动判断翻页方向
    float rightToLeftRatio = iMouse.x / iResolution.x; // 鼠标起点在右侧，则从右往左翻

    // 根据翻页方向调整参数
    vec2 origin;
    float mouseDist;

    if (rightToLeftRatio > 0.5) {
        // 从右向左翻页
        origin = clamp(mouse - mouseDir * mouse.x / mouseDir.x, 0., 1.); // 翻页起点
        mouseDist = clamp(length(mouse - origin) +
                          (aspect - (abs(iMouse.z)/iResolution.x)*aspect)/mouseDir.x, 0., aspect/mouseDir.x);
        if (mouseDir.x < 0.) {
            mouseDist = distance(mouse, origin);
        }
    } else {
        // 从左向右翻页
        origin = clamp(mouse - mouseDir * (aspect - mouse.x) / mouseDir.x, 0., vec2(aspect, 1.));
        mouseDist = clamp(length(mouse - origin) +
                          ((abs(iMouse.z)/iResolution.x)*aspect)/mouseDir.x, 0., aspect/mouseDir.x);
        if (mouseDir.x > 0.) {
            mouseDist = distance(mouse, origin);
        }
    }

    // 计算投影距离
    float proj = dot(uv - origin, mouseDir); // UV点在翻页方向上的投影
    float dist = proj - mouseDist; // 距离翻页线的有符号距离

    // 计算翻页上的对应点
    vec2 linePoint = uv - dist * mouseDir;

    // 根据翻页方向选择对应的纹理
    sampler2D frontTexture = isRightToLeft ? frontImage : preImage;
    sampler2D backTexture = isRightToLeft ? backImage : frontImage;

    // 背面区域（完全翻过去的页面）
    if (dist > radius) {
        fragColor = texture(backTexture, uv * vec2(1./aspect, 1.)); // 使用背面纹理
        fragColor.rgb *= pow(clamp(dist - radius, 0., 1.) * 1.5, .2); // 距离越远越暗
    }
    // 弯曲区域（正在翻页的部分）
    else if (dist >= 0.) {
        // 圆柱体映射：计算翻页曲面上对应的UV
        float theta = asin(dist / radius); // 计算角度
        vec2 p2 = linePoint + mouseDir * (pi - theta) * radius; // 映射点1
        vec2 p1 = linePoint + mouseDir * theta * radius; // 映射点2

        // 选择有效映射点
        uv = (p2.x <= aspect && p2.y <= 1. && p2.x > 0. && p2.y > 0.) ? p2 : p1;
        fragColor = texture(frontTexture, uv * vec2(1./aspect, 1.)); // 使用正面纹理
        fragColor.rgb *= pow(clamp((radius - dist)/radius, 0., 1.), .2); // 根据曲率调整亮度
    }
    // 正面区域（未翻页部分）
    else {
        // 处理翻页超过一半的情况
        vec2 p = linePoint + mouseDir * (abs(dist) + pi * radius);
        uv = (p.x <= aspect && p.y <= 1. && p.x > 0. && p.y > 0.) ? p : uv;
        fragColor = texture(frontTexture, uv * vec2(1./aspect, 1.)); // 使用正面纹理
    }
}