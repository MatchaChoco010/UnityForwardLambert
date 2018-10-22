Shader "ForwardLambert"
{
  Properties
  {
    _MainTex ("Texture", 2D) = "white" {}
  }
  SubShader
  {
    Pass
    {
      Name "ShadowCast"
      Tags {"LightMode" = "ShadowCaster"}

      CGPROGRAM
      #pragma vertex vert
      #pragma fragment frag
      #pragma multi_compile_shadowcaster

      #include "UnityCG.cginc"

      struct v2f {
        // V2F_SHADOW_CASTER;
        float4 pos : SV_POSITION;
        #if defined(SHADOWS_CUBE) && !defined(SHADOWS_CUBE_IN_DEPTH_TEX)
          float3 vec : TEXCOORD0;
        #endif
      };

      void vert(in appdata_base v, out v2f o)
      {
        // TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
        #if defined(SHADOWS_CUBE) && !defined(SHADOWS_CUBE_IN_DEPTH_TEX)
          o.vec = mul(unity_ObjectToWorld, v.vertex).xyz - _LightPositionRange.xyz;
          o.pos = UnityObjectToClipPos(v.vertex);
        #else
          o.pos = UnityClipSpaceShadowCasterPos(v.vertex, v.normal);
          o.pos = UnityApplyLinearShadowBias(o.pos);
        #endif
      }

      float4 frag(v2f i) : SV_Target
      {
        // SHADOW_CASTER_FRAGMENT(i)
        #if defined(SHADOWS_CUBE) && !defined(SHADOWS_CUBE_IN_DEPTH_TEX)
          return UnityEncodeCubeShadowDepth ((length(i.vec) + unity_LightShadowBias.x) * _LightPositionRange.w);
        #else
          return 0;
        #endif
      }
      ENDCG
    }
    Pass
    {
      Tags { "LightMode"="ForwardBase"}

      CGPROGRAM
      #pragma vertex vert
      #pragma fragment frag
      #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap

      #include "UnityCG.cginc"
      #include "Lighting.cginc"
      #include "AutoLight.cginc"

      struct appdata
      {
        float4 vertex : POSITION;
        float3 normal : NORMAL;
        float2 uv : TEXCOORD0;
        float2 texcoord1: TEXCOORD1;
      };

      struct v2f
      {
        float4 pos : SV_POSITION;
        float2 uv : TEXCOORD0;
        float3 worldNormal : TEXCOORD1;
        float3 worldPos : TEXCOORD2;
        #if UNITY_SHOULD_SAMPLE_SH
          float3 sh: TEXCOORD3;
        #endif
        #ifdef UNITY_HALF_PRECISION_FRAGMENT_SHADER_REGISTERS
          UNITY_LIGHTING_COORDS(4,5)
        #else
          UNITY_SHADOW_COORDS(4)
        #endif
      };

      sampler2D _MainTex;
      float4 _MainTex_ST;

      void vert (in appdata v, out v2f o)
      {
        UNITY_INITIALIZE_OUTPUT(v2f, o);

        o.pos = UnityObjectToClipPos(v.vertex);
        o.worldNormal = UnityObjectToWorldNormal(v.normal);
        o.worldPos = mul(unity_ObjectToWorld, v.vertex);
        o.uv = TRANSFORM_TEX(v.uv, _MainTex);

        #if UNITY_SHOULD_SAMPLE_SH && !UNITY_SAMPLE_FULL_SH_PER_PIXEL
          o.sh = 0;
          #ifdef VERTEXLIGHT_ON
            o.sh += Shade4PointLights(
              unity_4LightPosX0,
              unity_4LightPosY0,
              unity_4LightPosZ0,
              unity_LightColor[0].rgb,
              unity_LightColor[1].rgb,
              unity_LightColor[2].rgb,
              unity_LightColor[3].rgb,
              unity_4LightAtten0,
              o.worldPos,
              o.worldNormal);
          #endif
          o.sh = ShadeSHPerVertex (o.worldNormal, o.sh);
        #endif

        UNITY_TRANSFER_LIGHTING(o,v.texcoord1.xy);
      }

      void frag (in v2f i, out fixed4 col : SV_Target)
      {
        float3 lightDir = _WorldSpaceLightPos0.xyz;
        float3 normal = normalize(i.worldNormal);
        float NL = dot(normal, lightDir);

        UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);

        float3 baseColor = tex2D(_MainTex, i.uv);
        float3 lightColor = _LightColor0;


        #if UNITY_SHOULD_SAMPLE_SH
          float3 sh = ShadeSHPerPixel(normal, i.sh, i.worldPos);
          col = fixed4(baseColor * lightColor * max(NL, 0) * attenuation + sh, 1);
        #else
          col = fixed4(baseColor * lightColor * max(NL, 0) * attenuation, 1);
        #endif
      }
      ENDCG
    }
    Pass
    {
      Tags { "LightMode"="ForwardAdd"}
      ZWrite Off
      Blend One One

      CGPROGRAM
      #pragma vertex vert
      #pragma fragment frag
      #pragma multi_compile_fwdadd_fullshadows

      #include "UnityCG.cginc"
      #include "Lighting.cginc"
      #include "AutoLight.cginc"

      struct appdata
      {
        float4 vertex : POSITION;
        float3 normal : NORMAL;
        float2 uv : TEXCOORD0;
        float2 texcoord1: TEXCOORD1;
      };

      struct v2f
      {
        float4 pos : SV_POSITION;
        float2 uv : TEXCOORD0;
        float3 worldNormal : TEXCOORD1;
        float3 worldPos : TEXCOORD2;
        UNITY_LIGHTING_COORDS(3,4)
      };

      sampler2D _MainTex;
      float4 _MainTex_ST;

      void vert (in appdata v, out v2f o)
      {
        UNITY_INITIALIZE_OUTPUT(v2f, o);

        o.pos = UnityObjectToClipPos(v.vertex);
        o.worldNormal = UnityObjectToWorldNormal(v.normal);
        o.worldPos = mul(unity_ObjectToWorld, v.vertex);
        o.uv = TRANSFORM_TEX(v.uv, _MainTex);

        UNITY_TRANSFER_LIGHTING(o,v.texcoord1.xy);
      }

      void frag (in v2f i, out fixed4 col : SV_Target)
      {
        #ifndef USING_DIRECTIONAL_LIGHT
          fixed3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
        #else
          fixed3 lightDir = _WorldSpaceLightPos0.xyz;
        #endif
        float3 normal = normalize(i.worldNormal);
        float NL = dot(normal, lightDir);

        UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);

        float3 baseColor = tex2D(_MainTex, i.uv);
        float3 lightColor = _LightColor0;

        col = fixed4(baseColor * lightColor * max(NL, 0) * attenuation, 0);
      }
      ENDCG
    }
  }
}
