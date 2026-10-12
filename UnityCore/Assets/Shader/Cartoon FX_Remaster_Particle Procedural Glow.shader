Shader "Cartoon FX/Remaster/Particle Procedural Glow" {
	Properties {
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Blend Source", Float) = 5
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Blend Destination", Float) = 10
		[Toggle(_CFXR_DISSOLVE)] _UseDissolve ("Enable Dissolve", Float) = 0
		[NoScaleOffset] _DissolveTex ("Dissolve Texture", 2D) = "gray" {}
		_DissolveSmooth ("Dissolve Smoothing", Range(0.0001, 0.5)) = 0.1
		[ToggleNoKeyword] _InvertDissolveTex ("Invert Dissolve Texture", Float) = 0
		[KeywordEnum(P0, P2, P4, P8)] _CFXR_GLOW_POW ("Apply Power of", Float) = 0
		_GlowMin ("Circle Min", Float) = 0
		_GlowMax ("Circle Max", Float) = 1
		_MaxValue ("Max Value", Float) = 10
		[Toggle(_CFXR_HDR_BOOST)] _HdrBoost ("Enable HDR Multiplier", Float) = 0
		_HdrMultiply ("HDR Multiplier", Float) = 2
		[Toggle(_FADING_ON)] _UseSP ("Soft Particles", Float) = 0
		_SoftParticlesFadeDistanceNear ("Near Fade", Float) = 0
		_SoftParticlesFadeDistanceFar ("Far Fade", Float) = 1
		[KeywordEnum(Off,On,CustomTexture)] _CFXR_DITHERED_SHADOWS ("Dithered Shadows", Float) = 0
		_ShadowStrength ("Shadows Strength Max", Range(0, 1)) = 1
		_DitherCustom ("Dithering 3D Texture", 3D) = "black" {}
	}
	
// Recovery approximation: basic particle texture/color/blending. Original effect source was unavailable.
SubShader {
 Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
 Cull Off ZWrite Off Blend [_SrcBlend] [_DstBlend]
 Pass {
  CGPROGRAM
  #pragma vertex vert
  #pragma fragment frag
  #include "UnityCG.cginc"
  sampler2D _MainTex; float4 _MainTex_ST; half _HdrMultiply; half _HdrBoost;
  struct appdata { float4 vertex:POSITION; float2 uv:TEXCOORD0; half4 color:COLOR; };
  struct v2f { float4 pos:SV_POSITION; float2 uv:TEXCOORD0; half4 color:COLOR; };
  v2f vert(appdata v) { v2f o; o.pos=UnityObjectToClipPos(v.vertex); o.uv=v.uv; o.color=v.color; return o; }
  half4 frag(v2f i):SV_Target { half4 color=i.color; color.a *= saturate(1.0-length(i.uv*2.0-1.0)); color.rgb *= lerp(1.0,_HdrMultiply,_HdrBoost); return color; }
  ENDCG
 }
}
}
