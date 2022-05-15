#version 130

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
attribute vec4 at_tangent;
attribute vec3 mc_Entity;

out vec4 vcolor;
out vec4 normal;
out vec3 worldpos;
out vec3 viewpos;
out mat3 tbn;
out vec2 uv0;
out vec2 uv1;

void main(){
	uv0 = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	uv1 = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	viewpos = (gl_ModelViewMatrix * gl_Vertex).xyz;
	worldpos = mat3(gbufferModelViewInverse) * viewpos + gbufferModelViewInverse[3].xyz;
	normal.xyz = normalize(gl_NormalMatrix * gl_Normal);
	normal.a = (mc_Entity.x == 1) ? 0.1 : 0.0;

	vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
	vec3 binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	tbn = transpose(mat3(tangent, binormal, normal.xyz));
	vcolor = gl_Color;

	vec3 worldpos2 = worldpos;
	worldpos2.y += (sin(frameTimeCounter * 3.0 + (worldpos2.x + cameraPosition.x) * 4.0) * 0.05 * cos(frameTimeCounter * 3.0 * 0.5) - 0.05);
	worldpos2.y += (cos(frameTimeCounter * 3.0 + (worldpos2.z + cameraPosition.z) * 0.3 * 4.0) * 0.05 - 0.05);
	gl_Position = gl_ProjectionMatrix * gbufferModelView * vec4(worldpos2, 1.0);
}
