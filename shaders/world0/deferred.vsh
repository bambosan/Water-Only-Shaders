#version 130
out vec2 texcoord;
void main(){
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;
}
