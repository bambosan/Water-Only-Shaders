#ifdef GBUFFERS_WATER
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
attribute vec4 at_tangent;
attribute vec3 mc_Entity;

out vec3 viewPos;
out vec3 worldPos;
out vec4 normal;
out mat3 tbnMatrix;
#endif

#if defined(GBUFFERS_WATER) || defined(GBUFFERS_SKYBASIC)
out float starData;
#endif

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;

#if defined(GBUFFERS_WATER) || defined(GBUFFERS_SKYBASIC)
	starData = float(glcolor.r == glcolor.g && glcolor.g == glcolor.b && glcolor.r > 0.0);
#endif
	vec4 pos = ftransform();
	
#ifdef GBUFFERS_WATER
	viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
	worldPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
	normal.xyz = normalize(gl_NormalMatrix * gl_Normal);
	normal.a = float(mc_Entity.x == 1);

	vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
	vec3 binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	tbnMatrix = transpose(mat3(tangent, binormal, normal.xyz));

	vec3 worldPos2 = worldPos;
	if(normal.a > 0.0){
		worldPos2.y += (sin(frameTimeCounter * 3.0 + (worldPos2.x + cameraPosition.x) * 4.0) * 0.05);
	}
	pos = gl_ProjectionMatrix * gbufferModelView * vec4(worldPos2, 1.0);
#endif

	gl_Position = pos;
}