/*
	スペクトラム表示シェーダー by あるる（きのもと 結衣） @arlez80
	Spectrum Displaying Shader by KINOMOTO Yui

	MIT License
*/
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tex;
uniform float hz0;
uniform float hz1;
uniform float hz2;
uniform float hz3;
uniform float hz4;
uniform float hz5;
uniform float hz6;
uniform float hz7;
uniform float hz8;
uniform float hz9;
uniform float hz10;
uniform float hz11;
uniform float hz12;
uniform float hz13;
uniform float hz14;
uniform float hz15;
uniform float hz16;
uniform float hz17;
uniform float hz18;
uniform float hz19;
uniform float hz20;
uniform float hz21;
uniform float hz22;
uniform float hz23;
uniform float hz24;
uniform float hz25;
uniform float hz26;
uniform float hz27;
uniform float hz28;
uniform float hz29;
uniform float hz30;
uniform float hz31;

void fragment( )
{
	float p = UV.x * 32.0;
	float f = mix( hz0, hz1, clamp( p, 0.0, 1.0 ) );
	f = mix( f, hz2, clamp( p - 1.0, 0.0, 1.0 ) );
	f = mix( f, hz3, clamp( p - 2.0, 0.0, 1.0 ) );
	f = mix( f, hz4, clamp( p - 3.0, 0.0, 1.0 ) );
	f = mix( f, hz5, clamp( p - 4.0, 0.0, 1.0 ) );
	f = mix( f, hz6, clamp( p - 5.0, 0.0, 1.0 ) );
	f = mix( f, hz7, clamp( p - 6.0, 0.0, 1.0 ) );
	f = mix( f, hz8, clamp( p - 7.0, 0.0, 1.0 ) );
	f = mix( f, hz9, clamp( p - 8.0, 0.0, 1.0 ) );
	f = mix( f, hz10, clamp( p - 9.0, 0.0, 1.0 ) );
	f = mix( f, hz11, clamp( p - 10.0, 0.0, 1.0 ) );
	f = mix( f, hz12, clamp( p - 11.0, 0.0, 1.0 ) );
	f = mix( f, hz13, clamp( p - 12.0, 0.0, 1.0 ) );
	f = mix( f, hz14, clamp( p - 13.0, 0.0, 1.0 ) );
	f = mix( f, hz15, clamp( p - 14.0, 0.0, 1.0 ) );
	f = mix( f, hz16, clamp( p - 15.0, 0.0, 1.0 ) );
	f = mix( f, hz17, clamp( p - 16.0, 0.0, 1.0 ) );
	f = mix( f, hz18, clamp( p - 17.0, 0.0, 1.0 ) );
	f = mix( f, hz19, clamp( p - 18.0, 0.0, 1.0 ) );
	f = mix( f, hz20, clamp( p - 19.0, 0.0, 1.0 ) );
	f = mix( f, hz21, clamp( p - 20.0, 0.0, 1.0 ) );
	f = mix( f, hz22, clamp( p - 21.0, 0.0, 1.0 ) );
	f = mix( f, hz23, clamp( p - 22.0, 0.0, 1.0 ) );
	f = mix( f, hz24, clamp( p - 23.0, 0.0, 1.0 ) );
	f = mix( f, hz25, clamp( p - 24.0, 0.0, 1.0 ) );
	f = mix( f, hz26, clamp( p - 25.0, 0.0, 1.0 ) );
	f = mix( f, hz27, clamp( p - 26.0, 0.0, 1.0 ) );
	f = mix( f, hz28, clamp( p - 27.0, 0.0, 1.0 ) );
	f = mix( f, hz29, clamp( p - 28.0, 0.0, 1.0 ) );
	f = mix( f, hz30, clamp( p - 29.0, 0.0, 1.0 ) );
	f = mix( f, hz31, clamp( p - 30.0, 0.0, 1.0 ) );

	COLOR = texture( tex, vec2( UV.x, 0.0 ) ) * float( 1.0 - UV.y < f );
}