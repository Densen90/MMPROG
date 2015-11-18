uniform vec2 iResolution;
uniform float iGlobalTime;
uniform sampler2D tex;
uniform sampler2D tex2;
in vec2 uv;

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
float textureLookup(vec2 uv)
{
	return texture(tex, uv/EXPANSION).r * HEIGHTSCALE - YSHIFT;
}

//increase ray with DELTA, make a texture lookup
//and compare to height, if we are inside, return position
bool raymarch(vec3 orig, vec3 dir, out float t, out float h)
{
	const float minT = 0.001;
	const float maxT = MAXDIST;
	float delt = DELTA;
	float out_t = 0.0;
	float in_t = 0.0;
	t = MAXDIST;

	//DELTA Marching
	for(float i=minT; i<maxT; i+=delt)
	{
		vec3 p = orig + i*dir;
		h = textureLookup(p.xz);
		if(h>p.y) 
		{
			// t = (i + (i-delt)) / 2.0;	//linear interpolation between this and last point
			// return true;
			out_t = i-delt;
			in_t = i;
			
			//Bisection Marching between outer and inner point
			vec3 p = orig + out_t*dir;
			const float maxSteps = 5.0;
			for(float j=1.0; j<maxSteps; j++)
			{
				t = (out_t+in_t)*0.5;
				p = orig + t*dir;
				h = textureLookup(p.xz);
				if(h>p.y) in_t = t;	//i have a hit, set new in_t
				else if(h<p.y) out_t = t;	//no hit, go further
			}
			return true;
		}
	}

	return false;
}

// Approximates the (normalized) gradient of the distance function at the given point.
// If p is near a surface, the function will approximate the surface normal.
vec3 getNormal(vec3 p)
{
	float h = 0.15;
	return normalize(vec3(
		textureLookup(p.xz - vec2(h, 0)) - textureLookup(p.xz + vec2(h, 0)),
		2.0*h,
		textureLookup(p.xz - vec2(0, h)) - textureLookup(p.xz + vec2(0, h))));
}

// calculate shadow, ro=origin, rd=dir
// look for nearest point when raymarching, factor k gives smoothnes, 2=smooth, 128=hard
// dl is distance to light, so only return if distance is smaller
float shadow(vec3 ro, vec3 rd)
{
	float t, h;
	bool hit = raymarch(ro, rd, t, h);
    return hit ? AMBIENT : 1.0;
}

//calculate ambient occlusion
float ambientOcclusion(vec3 p, vec3 n)
{
	float res = 0.0;
	float fac = 1.0;
	for(float i=0.0; i<AOSAMPLES; i++)
	{
		float distOut = i*0.3;	//go on normal ray AOSAMPLES times with factor 0.3
		float t, h;
		vec3 pos = (p + n*distOut);
		float dh = max(textureLookup(pos.xz)-p.y, 0.0);
		res += fac * dh;	//look for every step, how far the nearest object is
		fac *= 0.5;	//for every step taken on the normal ray, the fac decreases, so the shadow gets brighter
	}
	return 1.0 - clamp(res, 0.0, 1.0);
}

//calculatte the color, the shadow, the lighting for a position
vec3 shading(vec3 pos, vec3 n, float h)
{
	vec3 light = max(vec3(AMBIENT), dot(n, -lightDir));
	// vec3 light = vec3(h);
	// light *= diffuse;
	// light *= shadow(pos + 0.05*n, -lightDir);
	light += ambientOcclusion(pos, n) * AMBIENT;

	//coloring

	// light *= vec3(0.1, 0.4, 0.1);
	// float fac = clamp(dot(n, vec3(0,1,0)), 0.0, 1.0);
	// light *= (h<=-YSHIFT+0.005) ? vec3(0.2,0.2,0.7) : mix(vec3(0.57,0.53,0.43), vec3(0.41,0.67,0.33), pow(fac, 20.0));
	vec3 col = texture(tex2, pos.xz/EXPANSION);
	light *= col;
	return light;
}

vec3 background(vec3 dir)
{
	vec3 pos = vec3(sin(iGlobalTime*0.5), 0.1, cos(iGlobalTime*0.5));
	float sun = max(0.0, dot(dir, normalize(pos)));
	float sky = max(0.0, dot(dir, vec3(0.0, 1.0, 0.0)));
	float ground = max(0.0, -dot(dir, vec3(0.0, 1.0, 0.0)));
	return 
  (pow(sun, 256.0) + 0.2 * pow(sun, 2.0)) * vec3(2.0, 1.6, 1.0) +
  pow(sky, 1.0) * vec3(0.5, 0.6, 0.7);
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
		
		col.rgb = clamp((shading(pos.xyz, n, h)), 0.0, 1.0);
		// gl_FragColor = vec4(getNormal(pos), 1.0);

		vec3 refDir = normalize(reflect(cam.dir, n));
	}

	//fog
	float factor = t/MAXDIST;
	vec3 back = background(cam.dir);
	col = mix(col, back, pow(factor, FOGFACTOR));
	gl_FragColor = vec4(col.rgb, 1.0);
}