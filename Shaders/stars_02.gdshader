shader_type canvas_item;

#define iResolution 1.0/SCREEN_PIXEL_SIZE
#define iChannelResolution 1.0/TEXTURE_PIXEL_SIZE
#define fragColor COLOR
#define iTime TIME
uniform sampler2D iChannel0;
uniform float zoom : hint_range(0.1, 50.0, 0.1) = 1.0;
uniform float NUM_LAYERS = 7.;
uniform float brightness1 : hint_range(0.0, 1.1, 0.1) = 1.0;
uniform float brightness2 : hint_range(-20.0, 50.0, 0.1) = 0.5;
uniform float brightness3 : hint_range(-10.0, 20.0, 0.1) = 0.5;
uniform float twinkle = 1.0;
uniform float star_rays = 1.0;
uniform float speed : hint_range(0.0, 100.0, 0.1) = 1.0;
uniform vec3 color1 = vec3(0.498, 0.588, 1.128);
uniform vec3 color2 = vec3(0.303, 0.388, 0.273);
uniform vec3 color3 = vec3(1.763, 0.938, 0.787);
uniform vec3 color4 = vec3(-2.982, 1.818, 1.948);
uniform vec2 adjust_queue = vec2(123.34,456.821);
#define Threshold 0.1
#define iMouse vec4(0.0)
//(0.0+iMouse.y/iResolution.y*1.0)
#define Intensity 1.5
//(2.0-iMouse.x/iResolution.x*2.0)
#define BlurSize 3.0
//(6.0-iMouse.x/iResolution.x*6.0)

vec3 palette (float t){
 vec3 a = color1;
 vec3 b = color2;
 vec3 c = color3;
 vec3 d = color4;
 
 return a + b * cos (6.28318*(c*t+d) );
}

mat2 Rot(float a){
    float s= sin(a), c=cos(a);
    return mat2(vec2(c,-s),vec2(s,c));
}

float Hash21(vec2 p){
    p = fract(p* adjust_queue);
    p += dot(p,p+45.32);
    return fract(p.x*p.y);
}

float Star (vec2 uv, float size, float baseRotation) {
    float d = length(uv) * star_rays;
    float m = 0.
    // inverted circle
    +smoothstep(.12,0.15,d)/7. * (size)
    // glow
    +0.01/d *(size*brightness2 +brightness3);
    // circle
    // rotate 45 deg
    uv *= Rot(baseRotation);
    float rays = 0.;
    rays += (max(0.,1.-abs(pow(abs(uv.x),1.8)*uv.y*30000.))) ;
    
    // rotate 45 deg
    uv *= Rot(3.14159/4.);
    rays += (max(0.,1.-abs(uv.x*uv.y* 3000.))) * .7 ;
    m*= smoothstep(1.,0.2,d);
    m+= rays* smoothstep(1.,0.2,d/(size));
    
    return m;
}

vec3 StarLayer(vec2 uv) {
        vec3 col = vec3(0);

        vec2 gv = fract(uv) -.5;
        vec2 id = floor(uv);

        for(int y=-1;y<=1;y++){
            for(int x=-1;x<=1;x++){
                vec2 offset = vec2(float(x),float(y));
                float n = Hash21(id+offset); // random between 0 and 1
                float size = fract (n*149.1)
                * (sin(iTime*0.3 * twinkle +n *48.123)*.5+1.);
                float star = Star(-offset + gv-(vec2(n,fract(n*34.))-0.5),smoothstep(.4,1.,size),-3.14159/10.);
                vec3 color = palette(star/3. +iTime * 0.3 + fract(n*9438.7));
                col += star*color;
            }
        }
        return col;
    }

vec4 Bloom (vec2 Coord, in sampler2D Tex, in float MipBias, vec2 iChanRes){
	vec2 TexelSize = MipBias/iChanRes.xy;
    
    vec4  Color = texture(Tex, Coord, MipBias);
    Color += texture(Tex, Coord + vec2(TexelSize.x,0.0), MipBias);    	
    Color += texture(Tex, Coord + vec2(-TexelSize.x,0.0), MipBias);    	
    Color += texture(Tex, Coord + vec2(0.0,TexelSize.y), MipBias);    	
    Color += texture(Tex, Coord + vec2(0.0,-TexelSize.y), MipBias);    	
    Color += texture(Tex, Coord + vec2(TexelSize.x,TexelSize.y), MipBias);    	
    Color += texture(Tex, Coord + vec2(-TexelSize.x,TexelSize.y), MipBias);    	
    Color += texture(Tex, Coord + vec2(TexelSize.x,-TexelSize.y), MipBias);    	
    Color += texture(Tex, Coord + vec2(-TexelSize.x,-TexelSize.y), MipBias);    

    return Color/9.0;

}

vec4 Blend(vec4 color, vec4 highlight){
    return 1.0-(1.0-color)*(1.0-highlight*Intensity); //Screen Blend Mode
}

void fragment()
{
    vec2 uv = UV;
    float t = iTime *0.02;
    
    vec2 M = 4.*UV;
     uv += M*.4;
    vec3 col = vec3(0);
    
    for(float i=0.; i<1.; i+= 1./NUM_LAYERS){
        float depth = fract (i + t * speed);
        float scale = mix(10. * zoom,1.,depth);
        col+= StarLayer(uv*scale+i*400.3 -M-t)*
        // fade
        smoothstep(1.,.9 * brightness1,depth)*depth;
    }
	//vec2 mappedUV = uv*vec2(0.5,1.)+0.5;
    //vec4 inColor = texture(iChannel0,mappedUV);
    //vec4 Highlight = clamp(Bloom(mappedUV,iChannel0, BlurSize, iChannelResolution)-Threshold,0.0,1.0)*1.0/(1.0-Threshold);
    //
    //col = col + inColor.xyz;
    //col  = (col+ Blend(inColor, Highlight).xyz);
    //(col+ Blend(inColor, Highlight).xyz)/2.;
    fragColor = vec4(col,1.0);
}