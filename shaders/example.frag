// 数学常量
#define pi 3.14159265359
#define radius .1 // 翻页曲率半径

// 着色器输入变量
uniform vec2 iResolution; // 渲染分辨率
uniform vec4 iMouse; // 鼠标位置和状态
uniform sampler2D iChannel0; // 正面纹理
uniform sampler2D iChannel1; // 背面纹理

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
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

    // 处理特殊方向情况
    if (mouseDir.x < 0.) {
        mouseDist = distance(mouse, origin);
    }

    // 计算投影距离
    float proj = dot(uv - origin, mouseDir); // UV点在翻页方向上的投影
    float dist = proj - mouseDist; // 距离翻页线的有符号距离

    // 计算翻页上的对应点
    vec2 linePoint = uv - dist * mouseDir;

    // 背面区域（完全翻过去的页面）
    if (dist > radius) {
        fragColor = texture(iChannel1, uv * vec2(1./aspect, 1.)); // 使用背面纹理
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
        fragColor = texture(iChannel0, uv * vec2(1./aspect, 1.)); // 使用正面纹理
        fragColor.rgb *= pow(clamp((radius - dist)/radius, 0., 1.), .2); // 根据曲率调整亮度
    }
    // 正面区域（未翻页部分）
    else {
        // 处理翻页超过一半的情况
        vec2 p = linePoint + mouseDir * (abs(dist) + pi * radius);
        uv = (p.x <= aspect && p.y <= 1. && p.x > 0. && p.y > 0.) ? p : uv;
        fragColor = texture(iChannel0, uv * vec2(1./aspect, 1.)); // 使用正面纹理
    }
}