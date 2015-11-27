uniform vec2 iResolution;
uniform float iGlobalTime;
uniform sampler2D tex;
uniform sampler2D tex2;
in vec2 uv;

struct Camera
{
	vec3 pos;
	vec3 dir;
} cam;

void main()
{
	float fov = 60.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	cam.pos = vec3(0,0,0);
	cam.dir = normalize(vec3( p.x, p.y, 1 ));

	vec4 res = gl_FragCoord;

	// res = raymarch(cam.pos, cam.dir);
	// res.xyz = (res.a==1.0) ? clamp(shading(res.xyz, cam.dir, getNormal(res.xyz)), 0.0, 1.0) : vec3(0);

	gl_FragColor = vec4(res.xyz, 1.0);
}