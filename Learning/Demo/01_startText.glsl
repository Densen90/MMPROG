uniform float iGlobalTime;
varying vec2 uv;
uniform sampler2D tex0;
uniform sampler2D tex1;
uniform sampler2D tex2;

uniform float uFade;

	
vec3 line(vec2 p, float sx)
{
	float dy = 1.0 / (500.0 * abs(p.y - sx) * (1.0+0.5*sin(iGlobalTime*22)));
	return vec3(0.3, 1.8 * dy, 8.0 * dy);
}

void main()
{
	vec3 c;

	vec2 uvMove = vec2(min(uv.x*iGlobalTime*0.4, uv.x), uv.y);
	vec3 tCol = texture2D(tex1, uvMove);

	vec2 uvMove2 = vec2(min(uv.x*max((iGlobalTime-3.9), 0.0)*0.3, uv.x), uv.y);
	vec3 tCol2 = texture2D(tex2, uvMove2);

	c = tCol+tCol2;

	c.r = mix(c.r, 0.0, uFade);
	c.g = mix(c.g, 0.0, uFade);
	c.b = mix(c.b, 0.0, uFade);

	gl_FragColor = vec4(c, 1.0 );
}