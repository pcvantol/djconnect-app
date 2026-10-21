#include <metal_stdlib>
using namespace metal;

// Compile-time app shader. No server/model text, external library or URL can
// become GPU code. Every varying value comes from the closed native scene.
struct Uniforms {
    float4 resolutionTime; // pixels, continuous bounded visual clock, quality
    float4 composition;
    float4 paletteMotion;
    float4 shape; // depth, roughness, deformation, relative dynamics
};
struct VertexOut { float4 position [[position]]; float2 uv; };
vertex VertexOut vibeScapeVertex(uint id [[vertex_id]]) {
    float2 p = float2((id << 1) & 2, id & 2);
    return {float4(p * 2.0 - 1.0, 0, 1), p};
}
static float2x2 rotate2(float a) { float c = cos(a), s = sin(a); return float2x2(c,-s,s,c); }
static float smoothUnion(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b-a)/k, 0.0, 1.0);
    return mix(b,a,h) - k*h*(1.0-h);
}
static float field(float3 p, constant Uniforms &u) {
    float4 c = u.composition;
    float t = u.resolutionTime.z;
    p.xz = rotate2(c.w*6.28 + t*0.063) * p.xz;
    p.xy = rotate2(c.x*1.4 - 0.7 + 0.13*sin(t*0.071)) * p.xy;
    p.xz = rotate2(p.y*(0.35+c.y*0.9) + sin(t*0.11)*0.17) * p.xz;
    float deform = u.shape.z;
    p += deform*0.14*sin(p.yzx*2.1 + float3(t*0.17,t*0.13,t*0.11));
    // A continuous sculptural field, rather than a preset/animation carousel:
    // asymmetric elliptic ribbons meld with a displaced, tapered liquid spine.
    float3 q = p;
    q.y *= 0.67 + c.z*0.45;
    float ring = length(float2(length(q.xy) - (0.87+c.x*0.26), q.z)) - (0.17+c.z*0.10);
    float3 r = p - float3(0.35-c.y*0.7,0.13,-0.20);
    r.yz = rotate2(0.45+c.x*1.9) * r.yz;
    float second = length(float2(length(r.xy)-0.70, r.z)) - (0.13+c.w*0.13);
    float3 spine = p - float3(sin(p.y*1.7+t*0.09)*0.35,0,0.18);
    spine.y = max(abs(spine.y)-1.1,0.0);
    float liquid = length(spine*float3(1,1,1.2))-(0.18+c.y*0.19);
    float3 v = p - float3(-0.36+c.z*0.4,-0.28,0.15);
    v.xz = rotate2(0.6+c.w*2.1)*v.xz;
    float third = length(float2(length(v.yz)-(0.45+c.z*0.4),v.x))-(0.10+c.x*0.11);
    // A continuous distance offset introduces/removes an additional interwoven
    // ribbon without a discrete preset switch or camera cut.
    third += (1.0-c.w)*1.2;
    return smoothUnion(smoothUnion(smoothUnion(ring,second,0.30+deform*0.18), liquid, 0.32),third,0.24);
}
static float3 environment(float3 r, float3 tint, float roughness) {
    float3 col = mix(float3(0.004,0.006,0.013), float3(0.11,0.15,0.22), smoothstep(-0.6,0.9,r.y));
    float width = mix(100.0,14.0,roughness);
    float top = pow(max(dot(r,normalize(float3(-0.5,0.8,0.5))),0.0),width);
    float strip = pow(max(dot(r,normalize(float3(0.9,0.2,0.4))),0.0),width*0.55);
    float edge = pow(max(dot(r,normalize(float3(-0.8,-0.3,-0.4))),0.0),width*0.40);
    col += top*float3(3.5,3.3,3.0) + strip*(1.8*tint+0.35) + edge*float3(0.6,0.9,1.5);
    float ceiling = smoothstep(0.42,0.50,r.y)*(1.0-smoothstep(0.60,0.75,abs(r.x)));
    float side = smoothstep(0.30,0.40,r.x)*(1.0-smoothstep(0.50,0.62,r.x))*(1.0-smoothstep(0.5,0.65,abs(r.y)));
    col += ceiling*float3(2.1,2.15,2.2)+side*(tint*2.0+0.3);
    // Wide continuous studio panels create coherent metallic reflections.
    col += smoothstep(0.84,0.89,abs(r.x))*smoothstep(-0.5,0.1,r.y)*0.35;
    return col;
}
fragment float4 vibeScapeFragment(VertexOut in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 uv = (in.uv*2.0-1.0)*float2(u.resolutionTime.x/u.resolutionTime.y,1.0);
    float time = u.resolutionTime.z;
    float3 tint = u.paletteMotion.xyz;
    float3 eye = float3(sin(time*0.021)*0.22,cos(time*0.017)*0.13,4.3+u.shape.x*0.5);
    float3 ray = normalize(float3(uv*1.05,-2.6));
    float d = 0.0; float distance = 0.0;
    int steps = u.resolutionTime.w > 0.5 ? 96 : 56;
    for(int i=0; i<steps; ++i) {
        d=field(eye+ray*distance,u);
        if(d<0.0025 || distance>8.0) break;
        distance += max(d*0.55,0.001);
    }
    float vignette = exp(-dot(uv,uv)*0.32);
    float3 color = mix(float3(0.002,0.003,0.007),tint*0.025,vignette);
    if(d<0.006 && distance<8.0) {
        float3 p=eye+ray*distance;
        const float e=0.002;
        float3 n=normalize(float3(field(p+float3(e,0,0),u)-field(p-float3(e,0,0),u),
                                 field(p+float3(0,e,0),u)-field(p-float3(0,e,0),u),
                                 field(p+float3(0,0,e),u)-field(p-float3(0,0,e),u)));
        float fresnel=pow(1.0-max(dot(n,-ray),0.0),5.0);
        float occlusion=clamp(field(p+n*0.18,u)/0.18,0.20,1.0);
        float3 reflected=environment(reflect(ray,n),tint,u.shape.y);
        float3 metal=mix(float3(0.72,0.76,0.82),tint,0.32);
        color=reflected*mix(metal,float3(1),fresnel)*occlusion;
        color+=tint*0.035*max(dot(n,normalize(float3(-0.5,0.8,0.6))),0.0);
        color=mix(color,float3(0.015,0.02,0.04),smoothstep(4.0,8.0,distance)*0.20);
    }
    color=color/(color+0.85);
    return float4(pow(max(color,float3(0)),float3(1.0/2.2)),1);
}
