uniform float iGlobalTime;
varying vec2 uv;
uniform sampler2D tex0;
uniform sampler2D tex1;
uniform sampler2D tex2;

uniform float uFade;

	
vec3 line(vec2 p, float sx)
{
	float dy = 1.0 / (500.0 * abs(p.y - sx) * (1.0+0.5*sin(iGlobalTime*23)));
	return vec3(0.01, 0.8 * dy, 3.0 * dy);
}

void main()
{
	vec3 c;
	vec2 p = uv - 0.5;
	
	c += line(p, 0.5*p.x);
	c += line(p, -0.2*p.x+0.2);
	c += line(p, -p.x-0.1);
	c += line(p, 1.3*p.x+0.05);
	c += line(p, 1.1*p.x-0.25);
	c += line(p, -1.3*p.x+0.3);
	c += line(p, 0.05);
	c += line(p, -3*p.x);

	vec2 uvMove = vec2(min(uv.x*iGlobalTime*0.3, uv.x), uv.y);
	vec3 tCol = texture2D(tex1, uvMove);

	vec2 uvMove2 = vec2(min(uv.x*max((iGlobalTime-3.0), 0.0)*0.3, uv.x), uv.y);
	vec3 tCol2 = texture2D(tex2, uvMove2);

	// c = tCol.r > 0.2 ? vec3(1.0,1.0,1.0) : c;
	// if(iGlobalTime<8.0)
	c = tCol+tCol2;

	c.r = mix(c.r, 0.0, uFade);
	c.g = mix(c.g, 0.0, uFade);
	c.b = mix(c.b, 0.0, uFade);

	gl_FragColor = vec4(c, 1.0 );
}