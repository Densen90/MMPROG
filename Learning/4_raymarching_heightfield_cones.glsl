uniform vec2 iResolution;
uniform float iGlobalTime;
uniform sampler2D tex;
uniform sampler2D tex2;
in vec2 uv;

#define MAXSTEPS 1024
#define DELTA 0.1
#define AMBIENT 0.2
#define HEIGHTSCALE 3.0
#define YSHIFT 1.0
#define EXPANSION 50.0
#define PI 3.14159
#define FOGFACTOR 3.0
#define MAXDIST 50.0
#define AOSAMPLES 5.0

vec3 lightDir = normalize(vec3(0,-0.5,-1));
const vec3 diffuse = vec3(1, 1, 1);

struct Camera
{
	vec3 pos;
	vec3 dir;
} cam;

// Rotation / Translation of a point p with rotation r
vec3 rotate( vec3 p, vec3 r )
{
	r.x *= PI/180.0;
	r.y *= PI/180.0;
	r.z *= PI/180.0;

	mat3 xRot = mat3 (	1,	0,				0,
						0,	cos(r.x),	-sin(r.x),
						0,	sin(r.x),	cos(r.x) );
	mat3 yRot = mat3 ( 	cos(r.y),		0,	sin(r.y),
						0,					1,	0,
						-sin(r.y),		0,	cos(r.y) );
	mat3 zRot = mat3 (	cos(r.z),	-sin(r.z),	0,
						sin(r.z),	cos(r.z),	0,
						0,				0,				1 );
	return xRot * yRot * zRot * p;
}

//make a texture lookup on the heightfield
vec3 textureLookup(in sampler2D texture,in vec2 uv, in float hscale = 1.0, in float yshift = 0.0)
{
	return texture2D(texture, uv/EXPANSION) * hscale - yshift;
}

//increase ray with DELTA, make a texture lookup
//and compare to height, if we are inside, return position
bool raymarch(vec3 orig, vec3 dir, out float t, out float h)
{
	t = MAXDIST;
	float totalDist = 0.0;
	for(float i=0.0; i<MAXSTEPS; i++)
	{
		vec3 p = orig + totalDist*dir;
		float alpha = textureLookup(tex, p.xz).r;
		float height = textureLookup(tex, p.xz, HEIGHTSCALE, YSHIFT).g;
		if(height>p.y) return true;

		float c = p.y - height;
		float beta = dot(dir, vec3(0,-1,0));
		float gamma = PI - alpha - beta;
		float addDist = c * sin(alpha)/sin(gamma); //http://www.arndt-bruenner.de/mathe/scripts/Dreiecksberechnung.htm#WSW
		totalDist += abs(addDist);

		h = height;
		t = totalDist;

		if(abs(addDist) < 0.001) return true;
	}

	return false;
}

// Approximates the (normalized) gradient of the distance function at the given point.
// If p is near a surface, the function will approximate the surface normal.
vec3 getNormal(vec3 p)
{
	float h = 0.9;
	return normalize(vec3(
		textureLookup(tex, p.xz - vec2(h, 0), HEIGHTSCALE, YSHIFT).r - textureLookup(tex, p.xz + vec2(h, 0), HEIGHTSCALE, YSHIFT).r,
		2.0*h,
		textureLookup(tex, p.xz - vec2(0, h), HEIGHTSCALE, YSHIFT).r - textureLookup(tex, p.xz + vec2(0, h), HEIGHTSCALE, YSHIFT).r));
}

void main()
{
	float fov = 60.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	// float camHeight = textureLookup(vec2(10, iGlobalTime*5.0));
	float camHeight = 5.0;
	cam.pos = vec3(10,camHeight+0.5,iGlobalTime*5.0);
	cam.dir = rotate( normalize(vec3( p.x, p.y, 1 )), vec3(-20,0,0));

	lightDir = rotate(lightDir, vec3(0,mod(-iGlobalTime*(360.0/(2.0*PI))*0.5,360.0), 0));

	float t, h;
	vec3 col;

	if(raymarch(cam.pos, cam.dir, t, h))
	{
		vec3 pos = cam.pos + t*cam.dir;
		vec3 n = getNormal(pos);
		
		// col.rgb = clamp((shading(pos.xyz, n, h)), 0.0, 1.0);
		// gl_FragColor = vec4(getNormal(pos), 1.0);

		// vec3 refDir = normalize(reflect(cam.dir, n));

		col = vec4(h/HEIGHTSCALE);
		col = textureLookup(tex2, pos.xz).rgb;
		col *= max(vec3(AMBIENT), dot(n, -lightDir));
		// col = texture(tex2, pos.xz/EXPANSION).rgb;
	}
	else col = vec4(0.3,0.2,0.2,1.0);

	vec3 back = vec3(0.3,0.5,0.2);

	float factor = t/MAXDIST;
	// col = mix(col, back, pow(factor, FOGFACTOR));
	gl_FragColor = vec4(col.rgb, 1.0);
}