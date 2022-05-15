#version 130
/* DRAWBUFFERS:4
const bool colortex4Clear = false;*/

uniform sampler2D colortex0;
in vec2 uv0;
void main(){
	gl_FragData[0] = vec4(texture2D(colortex0, uv0).rgb, 1.0);
}
