//@renderpasses 1,2

//material uniforms

uniform mat3 m_TextureMatrix;

//renderer uniforms...

uniform mat4 r_ModelViewMatrix;
uniform mat4 r_ModelViewProjectionMatrix;
uniform mat3 r_ModelViewNormalMatrix;

#if MX2_RENDERPASS==1

uniform vec4 r_AmbientDiffuse;
uniform samplerCube r_EnvTexture;
uniform mat3 r_EnvMatrix;

//pbr varyings...

varying vec3 v_Translation;
varying vec3 v_Position;
varying vec2 v_TexCoord0;
varying vec3 v_Normal;
varying mat3 v_TanMatrix;

#endif

const float pi = 3.1415926535897932384626433832795;

float oldMod(float x, float y) {
	return x-y * floor(x/y);
}

mat4 oldInverse(mat4 m) {
	float
		a00 = m[0][0], a01 = m[0][1], a02 = m[0][2], a03 = m[0][3],
		a10 = m[1][0], a11 = m[1][1], a12 = m[1][2], a13 = m[1][3],
		a20 = m[2][0], a21 = m[2][1], a22 = m[2][2], a23 = m[2][3],
		a30 = m[3][0], a31 = m[3][1], a32 = m[3][2], a33 = m[3][3],

		b00 = a00 * a11 - a01 * a10,
		b01 = a00 * a12 - a02 * a10,
		b02 = a00 * a13 - a03 * a10,
		b03 = a01 * a12 - a02 * a11,
		b04 = a01 * a13 - a03 * a11,
		b05 = a02 * a13 - a03 * a12,
		b06 = a20 * a31 - a21 * a30,
		b07 = a20 * a32 - a22 * a30,
		b08 = a20 * a33 - a23 * a30,
		b09 = a21 * a32 - a22 * a31,
		b10 = a21 * a33 - a23 * a31,
		b11 = a22 * a33 - a23 * a32,

		det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06
	;

	return mat4(
		a11 * b11 - a12 * b10 + a13 * b09,
		a02 * b10 - a01 * b11 - a03 * b09,
		a31 * b05 - a32 * b04 + a33 * b03,
		a22 * b04 - a21 * b05 - a23 * b03,
		a12 * b08 - a10 * b11 - a13 * b07,
		a00 * b11 - a02 * b08 + a03 * b07,
		a32 * b02 - a30 * b05 - a33 * b01,
		a20 * b05 - a22 * b02 + a23 * b01,
		a10 * b10 - a11 * b08 + a13 * b06,
		a01 * b08 - a00 * b10 - a03 * b06,
		a30 * b04 - a31 * b02 + a33 * b00,
		a21 * b02 - a20 * b04 - a23 * b00,
		a11 * b07 - a10 * b09 - a12 * b06,
		a00 * b09 - a01 * b07 + a02 * b06,
		a31 * b01 - a30 * b03 - a32 * b00,
		a20 * b03 - a21 * b01 + a22 * b00
	) / det;
}

//@vertex

//vertex attribs....

attribute vec4 a_Position;

#if MX2_RENDERPASS==1 

attribute vec2 a_TexCoord0;
attribute vec3 a_Normal;
attribute vec4 a_Tangent;

#endif

void main(){

#if MX2_RENDERPASS==1

	// texture coord0
	v_TexCoord0=(m_TextureMatrix * vec3(a_TexCoord0,1.0)).st;

	// view space position
	v_Position=( r_ModelViewMatrix * a_Position ).xyz;

	// v_Translation=a_Position.xyz - vec3(r_ModelViewMatrix[0][2], r_ModelViewMatrix[1][2], r_ModelViewMatrix[2][2]);
	v_Translation=a_Position.xyz - oldInverse(r_ModelViewMatrix)[3].xyz;

	// viewspace normal
	v_Normal=r_ModelViewNormalMatrix * a_Normal;
	
	// viewspace tangent matrix
	v_TanMatrix[2]=v_Normal;
	v_TanMatrix[0]=r_ModelViewNormalMatrix * a_Tangent.xyz;
	v_TanMatrix[1]=cross( v_TanMatrix[0],v_TanMatrix[2] ) * a_Tangent.a;
	
#endif
	
	gl_Position=r_ModelViewProjectionMatrix * a_Position;
}

//@fragment

#if MX2_RENDERPASS==1

void main0( vec3 color,vec3 emissive,float metalness,float roughness,float occlusion,vec3 normal ){

	normal=normalize( v_TanMatrix * normal );

	vec3 color0=vec3( 0.04,0.04,0.04 );
	
	vec3 diffuse=color * (1.0-metalness);
	
	vec3 specular=(color-color0) * metalness + color0;
	
	vec3 rvec=r_EnvMatrix * reflect( v_Position,normal );
	
	float lod=textureCube( r_EnvTexture,rvec,10.0 ).a * 255.0 - 10.0;
	
	if( lod>0.0 ) lod=textureCube( r_EnvTexture,rvec ).a * 255.0;
	
	vec3 env=pow( textureCube( r_EnvTexture,rvec,max( roughness*10.0-lod,0.0 ) ).rgb,vec3( 2.2 ) );

	vec3 vvec=normalize( -v_Position );
	
	float ndotv=max( dot( normal,vvec ),0.0 );
	
	vec3 fschlick=specular + (1.0-specular) * pow( 1.0-ndotv,5.0 ) * (1.0-roughness);

	vec3 ambdiff=diffuse * r_AmbientDiffuse.rgb;
		
	vec3 ambspec=env * fschlick;

	gl_FragData[0]=vec4( min( (ambdiff+ambspec) * occlusion + emissive,8.0 ),1.0 );

	gl_FragData[1]=vec4( color,metalness );
	
	gl_FragData[2]=vec4( normal * 0.5 + 0.5,roughness );
}

#endif

#if MX2_RENDERPASS==1

uniform sampler2D m_ColorTexture;
uniform vec4 m_ColorFactor;

uniform sampler2D m_EmissiveTexture;
uniform vec4 m_EmissiveFactor;

uniform sampler2D m_MetalnessTexture;
uniform float m_MetalnessFactor;

uniform sampler2D m_RoughnessTexture;
uniform float m_RoughnessFactor;

uniform sampler2D m_OcclusionTexture;

uniform sampler2D m_NormalTexture;

uniform float r_Time;

#endif

void main(){

#if MX2_RENDERPASS==1

	vec2 uv = normalize(v_Translation*vec3(-1.0,3.0,1.0)).zx*2.5;

	vec2 uv_back = uv + r_Time/16.0;
	uv_back.s = oldMod(uv_back.s, 1.0)*0.5+0.5;

	vec2 uv_front = uv + r_Time/8.0;
	uv_front.s = oldMod(uv_front.s, 1.0)*0.5;

	uv = texture2D( m_EmissiveTexture,uv_front ).r>0.0?uv_front:uv_back;

	vec3 color=pow( texture2D( m_ColorTexture,uv ).rgb,vec3( 2.2 ) ) * m_ColorFactor.rgb;
	
	vec3 emissive=pow( texture2D( m_EmissiveTexture,uv ).rgb,vec3( 1.8 ) ) * m_EmissiveFactor.rgb;
	
	float metalness=texture2D( m_MetalnessTexture,uv ).b * m_MetalnessFactor;
	
	float roughness=texture2D( m_RoughnessTexture,uv ).g * m_RoughnessFactor;
	
	float occlusion=texture2D( m_OcclusionTexture,uv ).r;

	vec3 normal=texture2D( m_NormalTexture,uv ).xyz * 2.0 - 1.0;
	
	main0( color,emissive,metalness,roughness,occlusion,normal );
	
//	gl_FragColor=vec4( 1.0,0.5,0.0,1.0 );	
	
#else

	gl_FragColor=vec4( vec3( gl_FragCoord.z ),1.0 );

#endif

}
