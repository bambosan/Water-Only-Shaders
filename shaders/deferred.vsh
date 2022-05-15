#version 130
out vec2 uv0;
void main(){
	gl_Position = ftransform();
	uv0 = gl_MultiTexCoord0.xy;
}
