#version 130
/* DRAWBUFFERS:4 */
uniform sampler2D colortex0;
void main(){
	gl_FragData[0] = texelFetch(colortex0, ivec2(gl_FragCoord.xy), 0);
}
