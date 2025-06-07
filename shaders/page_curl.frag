#include <flutter/runtime_effect.glsl>

uniform vec2 iResolution; // 渲染分辨率
uniform vec4 iMouse; // 鼠标位置和状态 xy: 鼠标位置, zw: 鼠标起始点击位置
uniform sampler2D iChannel0; // 正面纹理
uniform sampler2D iChannel1; // 背面纹理
uniform float iCurlDirection; // 翻页方向：1.0 表示从左向右翻页，-1.0 表示从右向左翻页

#define pi 3.14159265359 // 圆周率
#define radius 0.05 // 翻页曲率半径
#define shadowWidth 0.02 // 阴影宽度
#define TRACK_LINE_THICKNESS 0.002 // 轨道线的厚度

out vec4 fragColor;

/**
 * 计算阴影强度
 * @param targetPoint 目标点
 * @param aspect 宽高比
 * @return 返回阴影强度
 */
float calShadow(vec2 targetPoint, float aspect) {
    // 如果在页面上方
    if (targetPoint.y >= 1.0) {
        // 计算y方向和x方向的阴影
        return max(
            pow(clamp((targetPoint.y - 1.0) / shadowWidth, 0.0, 0.9), 0.2),
            pow(clamp((targetPoint.x - aspect) / shadowWidth, 0.0, 0.9), 0.2)
        );
    } else {
        // 计算y方向和x方向的阴影
        return max(
            pow(clamp((0.0 - targetPoint.y) / shadowWidth, 0.0, 0.9), 0.2),
            pow(clamp((targetPoint.x - aspect) / shadowWidth, 0.0, 0.9), 0.2)
        );
    }
}

/**
 * 旋转二维向量
 * @param v 输入向量
 * @param a 旋转角度
 * @return 旋转后的向量
 */
vec2 rotate(vec2 v, float a) {
    float s = sin(a); // 计算正弦
    float c = cos(a); // 计算余弦
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y); // 应用旋转矩阵
}

/**
 * 计算圆上的点
 * @param center 圆心
 * @param startPoint 起始点
 * @param currentRadius 当前半径
 * @param arcLength 弧长
 * @param clockwise 是否顺时针
 * @return 圆上的目标点
 */
vec2 pointOnCircle(vec2 center, vec2 startPoint, float currentRadius, float arcLength, bool clockwise) {
    float theta = arcLength / currentRadius; // 计算角度
    vec2 startVec = startPoint - center; // 起始向量
    startVec = normalize(startVec); // 归一化
    float rotationAngle = clockwise ? -theta : theta; // 判断旋转方向
    vec2 rotatedVec = rotate(startVec, rotationAngle); // 旋转向量
    vec2 endPoint = center + rotatedVec * currentRadius; // 得到终点
    return endPoint; // 返回终点
}

/**
 * 获取翻页起始角落位置
 * @param aspect 宽高比
 * @param curlDirection 翻页方向
 * @param mouseY 鼠标起点y坐标
 * @return 起始角落坐标
 */
vec2 getCornerFrom(float aspect, float curlDirection, float startMouseY) {
    // 根据鼠标在屏幕上半部分还是下半部分来决定起始角落
    float halfHeight = iResolution.y / 2.0; // 半屏高度

    if (curlDirection == -1.0) {
        // 从右往左翻页
        return startMouseY < halfHeight ? vec2(aspect, 0.0) : vec2(aspect, 1.0);
    } else {
        // 从左往右翻页
        return startMouseY < halfHeight ? vec2(0.0, 0.0) : vec2(0.0, 1.0);
    }
}

/**
 * 处理从右往左翻页的鼠标位置约束
 * @param mouse 鼠标坐标
 * @param cornerFrom 起始角落
 * @param aspect 宽高比
 * @return 约束后的鼠标坐标
 */
vec2 handleRightToLeftCurl(vec2 mouse, vec2 cornerFrom, float aspect) {
    vec2 startPoint = vec2(0.0, cornerFrom.y == 0.0 ? 0.0 : 1.0); // 起始点

    // 如果不是从中部开始，执行原来的逻辑
    if (distance(mouse.xy, startPoint) <= (aspect)) {
        return mouse; // 在允许范围内直接返回
    }
    vec2 vector = normalize(vec2(0.5, 0.5 * tan(pi / 3))); // 基准向量
    vec2 targetMouse = mouse.xy; // 目标鼠标
    vec2 v = targetMouse - startPoint; // 向量差
    float proj_length = dot(v, vector); // 投影长度
    vec2 targetMouse_proj = startPoint + proj_length * vector; // 投影点
    float base_line_distance = length(targetMouse_proj - targetMouse); // 到基准线距离
    float arc_distance = distance(targetMouse, startPoint) - aspect; // 到弧线距离
    float actual_distance = min(abs(base_line_distance), abs(arc_distance)); // 取较小距离
    vec2 currentMouse_arc_proj = startPoint + normalize(mouse - startPoint) * aspect; // 弧线上的映射点
    return pointOnCircle(startPoint, currentMouse_arc_proj, aspect, actual_distance / 2, mouse.y <= tan(pi / 3) * mouse.x); // 返回圆上的点
}

/**
 * 处理从左往右翻页的鼠标位置约束
 * @param mouse 鼠标坐标
 * @param cornerFrom 起始角落
 * @param aspect 宽高比
 * @return 约束后的鼠标坐标
 */
vec2 handleLeftToRightCurl(vec2 mouse, vec2 cornerFrom, float aspect) {
    vec2 startPoint = cornerFrom; // 直接使用cornerFrom作为起始点

    if (distance(mouse.xy, startPoint) <= aspect) {
        return mouse; // 在允许范围内直接返回
    }
    
    // 根据起始角落调整基准向量
    vec2 vector;
    bool clockwise;
    if (cornerFrom.y == 0.0) {
        // 从左上角开始，向右下方向
        vector = normalize(vec2(0.5, 0.5 * tan(pi / 3)));
        clockwise = mouse.y >= tan(pi / 3) * mouse.x;
    } else {
        // 从左下角开始，向右上方向
        vector = normalize(vec2(0.5, -0.5 * tan(pi / 3)));
        clockwise = mouse.y <= (1.0 - tan(pi / 3) * mouse.x);
    }
    
    vec2 targetMouse = mouse.xy; // 目标鼠标
    vec2 v = targetMouse - startPoint; // 向量差
    float proj_length = dot(v, vector); // 投影长度
    vec2 targetMouse_proj = startPoint + proj_length * vector; // 投影点
    float base_line_distance = length(targetMouse_proj - targetMouse); // 到基准线距离
    float arc_distance = distance(targetMouse, startPoint) - aspect; // 到弧线距离
    float actual_distance = min(abs(base_line_distance), abs(arc_distance)); // 取较小距离
    vec2 currentMouse_arc_proj = startPoint + normalize(mouse - startPoint) * aspect; // 弧线上的映射点
    return pointOnCircle(startPoint, currentMouse_arc_proj, aspect, actual_distance / 2, clockwise); // 返回圆上的点
}

/**
 * 获取鼠标方向向量
 * @param curlDirection 翻页方向
 * @param cornerFrom 起始角落
 * @param mouse 鼠标坐标
 * @param aspect 宽高比
 * @return 鼠标方向向量
 */
vec2 getMouseDirection(float curlDirection, vec2 cornerFrom, vec2 mouse, float aspect) {
    if (curlDirection == -1.0) {
        // 从右往左翻页
        return normalize(abs(cornerFrom * iResolution.xy / vec2(aspect, 1.0)) - mouse);
    } else {
        // 从左往右翻页
        vec2 corner = cornerFrom * iResolution.xy / vec2(aspect, 1.0);
        return normalize(mouse - corner);
    }
}

/**
 * 获取翻页辅助计算起点
 * @param curlDirection 翻页方向
 * @param mouse 鼠标坐标
 * @param mouseDir 鼠标方向
 * @param aspect 宽高比
 * @return 辅助起点
 */
vec2 getCurlOrigin(float curlDirection, vec2 mouse, vec2 mouseDir, float aspect) {
    if (curlDirection == -1.0) {
        // 从右往左翻页
        return clamp(mouse - mouseDir * mouse.x / mouseDir.x, 0.0, 1.0);
    } else {
        // 从左往右翻页
        return clamp(mouse - mouseDir * (mouse.x - aspect) / mouseDir.x, 0.0, 1.0);
    }
}

/**
 * 计算背面区域的颜色
 * @param uv 纹理坐标
 * @param dist 距离
 * @param aspect 宽高比
 * @return 背面颜色
 */
vec4 calculateBacksideColor(vec2 uv, float dist, float aspect) {
    vec4 color = texture(iChannel1, uv * vec2(1.0 / aspect, 1.0)); // 采样背面纹理
    color.rgb *= pow(clamp(dist - radius, 0.0, 1.0) * 1.5, 0.2); // 调整亮度
    return color; // 返回颜色
}

/**
 * 计算翻页弯曲区域的颜色
 * @param uv 纹理坐标
 * @param curlAxisLinePoint 翻页轴线点
 * @param mouseDir 鼠标方向
 * @param dist 距离
 * @param aspect 宽高比
 * @return 弯曲区域颜色
 */
vec4 calculateCurlColor(vec2 uv, vec2 curlAxisLinePoint, vec2 mouseDir, float dist, float aspect) {
    float theta = asin(dist / radius); // 计算角度
    vec2 p2 = curlAxisLinePoint + mouseDir * (pi - theta) * radius; // 计算p2点
    vec2 p1 = curlAxisLinePoint + mouseDir * theta * radius; // 计算p1点
    if (p2.x <= aspect && p2.y <= 1.0 && p2.x > 0.0 && p2.y > 0.0) {
        vec4 color = texture(iChannel0, p2 * vec2(1.0 / aspect, 1.0)); // 采样正面纹理
        color.rgb = mix(color.rgb, vec3(1.0), 0.25); // 混合高光
        color.rgb *= pow(clamp((radius - dist) / radius, 0.0, 1.0), 0.2); // 调整亮度
        return color; // 返回颜色
    } else {
        vec4 color = texture(iChannel0, p1 * vec2(1.0 / aspect, 1.0)); // 采样正面纹理
        if (p2.x <= aspect + shadowWidth && p2.y <= 1.0 + shadowWidth && p2.x > 0.0 - shadowWidth && p2.y > 0.0 - shadowWidth) {
            float shadow = calShadow(p2, aspect); // 计算阴影
            color = vec4(color.r * shadow, color.g * shadow, color.b * shadow, color.a); // 应用阴影
        }
        return color; // 返回颜色
    }
}

/**
 * 计算正面区域的颜色
 * @param uv 纹理坐标
 * @param curlAxisLinePoint 翻页轴线点
 * @param mouseDir 鼠标方向
 * @param dist 距离
 * @param aspect 宽高比
 * @return 正面颜色
 */
vec4 calculateFrontColor(vec2 uv, vec2 curlAxisLinePoint, vec2 mouseDir, float dist, float aspect) {
    vec2 p = curlAxisLinePoint + mouseDir * (abs(dist) + pi * radius); // 计算映射点
    if (p.x <= aspect && p.y <= 1.0 && p.x > 0.0 && p.y > 0.0) {
        vec4 color = texture(iChannel0, p * vec2(1.0 / aspect, 1.0)); // 采样正面纹理
        color.rgb = mix(color.rgb, vec3(1.0), 0.25); // 混合高光
        return color; // 返回颜色
    } else {
        vec4 color = texture(iChannel0, uv * vec2(1.0 / aspect, 1.0)); // 采样正面纹理
        if (p.x <= aspect + shadowWidth && p.y <= 1.0 + shadowWidth && p.x > 0.0 - shadowWidth && p.y > 0.0 - shadowWidth) {
            float shadow = calShadow(p, aspect); // 计算阴影
            color = vec4(color.r * shadow, color.g * shadow, color.b * shadow, color.a); // 应用阴影
        }
        return color; // 返回颜色
    }
}

/**
 * 绘制限制轨道圆
 * @param uv 纹理坐标
 * @param center 圆心
 * @param arcRadius 圆弧��径
 * @param aspect 宽高比
 * @return 是否在轨道线上
 */
bool drawTrackCircle(vec2 uv, vec2 center, float arcRadius, float aspect) {
    float dist = distance(uv, center);
    return abs(dist - arcRadius) < TRACK_LINE_THICKNESS;
}

/**
 * 主函数，计算每个像素的颜色
 */
void main() {
    vec2 fragCoord = FlutterFragCoord().xy; // 获取像素坐标
    float aspect = iResolution.x / iResolution.y; // 计算宽高比
    vec2 uv = fragCoord * vec2(aspect, 1.) / iResolution.xy; // 归一化纹理坐标

    // 获取翻页起始角落位置（注意：iMouse.w是初始触摸点的y坐标）
    vec2 cornerFrom = getCornerFrom(aspect, iCurlDirection, iMouse.w);

    // 归一化鼠标坐标
    vec2 mouse = iMouse.xy * vec2(aspect, 1.0) / iResolution.xy;    // 确定翻页轨迹的起始点
    vec2 trackStartPoint;
    if (iCurlDirection == -1.0) {
        // 从右往左翻页，轨道圆中心在左侧
        trackStartPoint = vec2(0.0, cornerFrom.y);
        mouse = handleRightToLeftCurl(mouse, cornerFrom, aspect); // 右往左翻页约束
    } else {
        // 从左往右翻页，轨道圆中心就是起始角落
        trackStartPoint = cornerFrom;
        mouse = handleLeftToRightCurl(mouse, cornerFrom, aspect); // 左往右翻页约束
    }

    vec2 iMouseXY = mouse * iResolution.xy / vec2(aspect, 1.0); // 更新鼠标坐标

    vec2 mouseDir = getMouseDirection(iCurlDirection, cornerFrom, iMouseXY, aspect); // 获取鼠标方向向量

    vec2 origin = getCurlOrigin(iCurlDirection, mouse, mouseDir, aspect); // 获取翻页辅助计算起点

    float mouseDist = distance(mouse, origin); // 计算辅助距离

    float proj = dot(uv - origin, mouseDir); // 投影
    float dist = proj - mouseDist; // 距离
    vec2 curlAxisLinePoint = uv - dist * mouseDir; // 翻页轴线点

    float actualDist = distance(mouse, cornerFrom); // 页脚跟随触摸点
    if (actualDist >= pi * radius) {
        float params = (actualDist - pi * radius) / 2; // 计算参数
        curlAxisLinePoint += params * mouseDir; // 调整轴线点
        dist -= params; // 调整距离
    }

    // 计算翻页的圆柱体映射点并选择合适的纹理
    if (dist > radius) {
        fragColor = calculateBacksideColor(uv, dist, aspect); // 背面区域
    } else if (dist >= 0.0) {
        fragColor = calculateCurlColor(uv, curlAxisLinePoint, mouseDir, dist, aspect); // 弯曲区域
    } else {
        fragColor = calculateFrontColor(uv, curlAxisLinePoint, mouseDir, dist, aspect); // 正面区域
    }

    // 绘制限制轨道圆 - 用绿色显示轨道
    if (drawTrackCircle(uv, trackStartPoint, aspect, aspect)) {
        fragColor = vec4(0.0, 1.0, 0.0, 1.0); // 绿色轨道线
    }
}