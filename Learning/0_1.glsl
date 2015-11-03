uniform vec2 iResolution;
uniform float iGlobalTime;

bool drawCircle(vec2 uv, vec2 pos, float rad);

void main()
{
	vec2 uv = gl_FragCoord.xy / iResolution.xy;
	//uv = mod(uv*8, 1.0);
	float ratio = iResolution.y/iResolution.x;
	float move = 0.05*ratio;
	float rad = move*mod(cos(iGlobalTime*4)+1.2, 2.2);
	bool b = false;
	float uvx, uvy;

	for(float i=0.0; i<=10.0; i++)
	{
		uvx = mod(iGlobalTime*0.25, 1.0-2.0*move+i/10.0)+move-i/10.0;
		uvy = (sin((uvx-move)*10.0)/4.0)+0.5;
		vec2 pos = vec2(uvx, uvy);
		b = drawCircle(vec2(uv.x, uv.y*ratio), pos, rad);
		if(b) break;
	}
	gl_FragColor = b ? vec4(uvx, uvy, uvx/uvy, 1.0) : vec4(1.0,1.0,1.0,1.0);
}

bool drawCircle(vec2 uv, vec2 pos, float rad)
{
	return length(uv-pos)<=rad;
}