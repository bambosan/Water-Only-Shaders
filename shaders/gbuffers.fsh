/* RENDERTARGETS: 0, 1 */

#define WATER_WAVE_SCALE 0.6 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define WATER_WAVE_SPEED 0.3 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define WATER_NORMAL_STRENGTH 2.5 //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0]
#define WATER_NORMAL_OFFSET 0.2 //[0.05 0.06 0.07 0.08 0.09 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define WATER_TRANSPARENCY 0.8 //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 1.0]
#define WATER_BRIGHTNESS 0.3 //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 1.0]

#ifdef GBUFFERS_SKYBASIC
	uniform mat4 gbufferModelView;
	uniform mat4 gbufferProjectionInverse;
	uniform vec3 fogColor;
	uniform vec3 skyColor;
	uniform float viewHeight;
	uniform float viewWidth;

	in float starData;
#else
	#ifndef GBUFFERS_BASIC
		uniform sampler2D lightmap;
		uniform sampler2D texture;

		#ifdef GBUFFERS_ENTITIES
			uniform vec4 entityColor;
		#endif

		#if defined(GBUFFERS_WATER) || defined(GBUFFERS_HAND_WATER)
			uniform vec3 cameraPosition;
			uniform float frameTimeCounter;

			// https://github.com/robobo1221/robobo1221Shaders/tree/master/shaders/lib/fragment
			float calcWave(vec2 coord, float wavelength, float movement, vec2 wavedir, float waveamp, float wavestepness){
				float k = 6.28318531 / wavelength;
				float x = sqrt(19.6 * k) * movement - (k * dot(wavedir, coord));
				float wave = sin(x) * 0.5 + 0.5;
				return waveamp * pow(wave, wavestepness);
			}

			float trochoidalWave(vec2 coord){
				float wavelength = 10.0;
				float movement = frameTimeCounter * WATER_WAVE_SPEED;
				float waveamp = 0.1;
				float wavestepness = 0.6;
				vec2 wavedir = vec2(1.0, 0.5);
				float waves = 0.0;
				#define rotate2d(r) mat2(cos(r), -sin(r), sin(r), cos(r))

				for(int i = 0; i < 10; ++i){
					waves += calcWave(coord, wavelength, movement, wavedir, waveamp, wavestepness);
					wavelength *= 0.7;
					waveamp *= 0.62;
					wavestepness *= 1.03;
					wavedir *= rotate2d(0.5);
					movement *= 1.1;
				}
				#undef rotate2d
				return waves;
			}

			vec3 waterNormal(vec3 position){
				vec2 posxz = position.xz * WATER_WAVE_SCALE;

				float height0 = trochoidalWave(posxz);
				float height1 = trochoidalWave(posxz + vec2(WATER_NORMAL_OFFSET, 0.0));
				float height2 = trochoidalWave(posxz + vec2(0.0, WATER_NORMAL_OFFSET));

				float xDirection = (height0 - height1);
				float yDirection = (height0 - height2);

				vec3 normalMap = normalize(vec3(xDirection, yDirection, 1.0));
					normalMap = normalMap * WATER_NORMAL_STRENGTH + vec3(0.0, 0.0, 1.0 - WATER_NORMAL_STRENGTH);
				return (normalMap * 0.5 + 0.5);
			}

			// https://aras-p.info/texts/CompactNormalStorage.html
			vec2 encodeNormal(vec3 n){
				float f = sqrt(n.z * 8.0 + 8.0);
				return n.xy / f + 0.5;
			}

			in mat3 tbnMatrix;
			in vec4 normal;
			in vec3 worldPos;

		#endif

		in vec2 lmcoord;
		in vec2 texcoord;
	#endif
#endif

in vec4 vcolor;

void main(){
#if defined(GBUFFERS_SKYBASIC)
	if(starData > 0.5){
		gl_FragData[0].rgb = vcolor.rgb;
	} else {
		vec4 viewPos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0, 1.0, 1.0);
			viewPos = gbufferProjectionInverse * viewPos;
		gl_FragData[0].rgb = mix(fogColor, skyColor, max(dot(viewPos.xyz, gbufferModelView[1].xyz), 0.0));
	}
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, 0.0);

#elif defined(GBUFFERS_BASIC)
	gl_FragData[0] = vcolor;
#else

	gl_FragData[0] = texture2D(texture, texcoord) * vcolor;

	#ifdef GBUFFERS_ENTITIES
		gl_FragData[0].rgb = mix(gl_FragData[0].rgb, entityColor.rgb, entityColor.a);
	#endif

	#if !defined(GBUFFERS_BEACON_BEAM) && !defined(GBUFFERS_CLOUDS) && !defined(GBUFFERS_SKYTEXTURED) && !defined(GBUFFERS_SPIDEREYES) && !defined(GBUFFERS_SKYBASIC)
		gl_FragData[0].rgb *= texture2D(lightmap, lmcoord).rgb;
	#endif

	#if defined(GBUFFERS_WATER) || defined(GBUFFERS_HAND_WATER)
		vec3 normalMap = normal.xyz;
		if(normal.a > 0.0){
			normalMap = waterNormal(worldPos + cameraPosition);
			normalMap = normalMap * 2.0 - 1.0;
			normalMap = normalize(normalMap * tbnMatrix);
			
			gl_FragData[0].rgb *= WATER_BRIGHTNESS;
			gl_FragData[0].a *= WATER_TRANSPARENCY;
		}
		gl_FragData[1] = vec4(encodeNormal(normalMap), normal.a, 1.0);
	#else
		gl_FragData[1] = vec4(0.0, 0.0, 0.0, 0.0);
	#endif
#endif
}