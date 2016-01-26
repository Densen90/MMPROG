uniform float iGlobalTime;
uniform vec2 iResolution;
uniform vec3 iMouse;

// Robert Cupisz 2013
// Creative Commons Attribution-ShareAlike 3.0 Unported
//
// Bits of code taken from Inigo Quilez, including fbm(), impulse()
// and friends, sdCone() and friends; also box() by Simon Green.

#define INF 1.0e38
#define ROOFPOS vec3(0,-1,0.01)
#define PI 3.14159
#define EPSILON 0.001

const vec3 boxPos = vec3(-0.5,0.5,0);

float hash (float n)
{
	return fract(sin(n)*43758.5453);
}

float noise (in vec3 x)
{
	vec3 p = floor(x);
	vec3 f = fract(x);

	f = f*f*(3.0-2.0*f);

	float n = p.x + p.y*57.0 + 113.0*p.z;

	float res = mix(mix(mix( hash(n+  0.0), hash(n+  1.0),f.x),
						mix( hash(n+ 57.0), hash(n+ 58.0),f.x),f.y),
					mix(mix( hash(n+113.0), hash(n+114.0),f.x),
						mix( hash(n+170.0), hash(n+171.0),f.x),f.y),f.z);
	return res;
}

float fbm (vec3 p)
{
	float f;
	f  = 0.5000*noise( p ); p = p*2.02;
	f += 0.2500*noise( p ); p = p*2.03;
	f += 0.1250*noise( p ); //p = m*p*2.01;
	//f += 0.0625*noise( p );
	return f;
}

float box(vec3 org, vec3 dir, vec3 size, out float far)
{
	// compute intersection of ray with all six bbox planes
	vec3 invR = 1.0 / dir;
	vec3 tbot = invR * (-0.5*size - org);
	vec3 ttop = invR * (0.5*size - org);
	
	// re-order intersections to find smallest and largest on each axis
	vec3 tmin = min (ttop, tbot);
	vec3 tmax = max (ttop, tbot);
	
	// find the largest tmin and the smallest tmax
	vec2 t0 = max (tmin.xx, tmin.yz);
	float near;
	near = max (t0.x, t0.y);
	t0 = min (tmax.xx, tmax.yz);
	far = min (t0.x, t0.y);

	// check for hit
	return near < far && far > 0.0 ? near : INF;
}

float box(vec3 org, vec3 dir, vec3 size)
{
	float far;
	return box(org, dir, size, far);
}

mat2 rot(float angle)
{
	float c = cos(angle);
	float s = sin(angle);
	return mat2(c,-s,s,c);
}

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

float roof(vec3 ro, vec3 rd)
{
	float hit = -ro.y/rd.y;
	// An offset, so that shadow rays starting from the roof don't
	// think they're unoccluded
	if (hit < -0.1)
		return INF;
	
	// We've hit the plane. If we've hit the window, but
	// not the beams, return no hit.
	vec2 pos = ro.xz + hit*rd.xz;
	vec2 window = abs(pos) - 0.81;
	// single beams
	//vec2 beams = 0.02 - abs(pos);
	// double beams
	vec2 beams = 0.015 - abs(mod(pos, 0.54) - 0.27);
	if (max(max(window.x, window.y), max(beams.x, beams.y)) < 0.0)
		return INF;

	return hit;
}

float intersect (vec3 ro, vec3 rd)
{
	float hit = INF;
	
	// box
	hit = min(hit, box (ro + boxPos, rd, vec3(0.4,0.4,0.4)));
	mat2 m = rot(3.5);
	
	// roof
	vec3 rorot = ro + ROOFPOS;
	vec3 rdrot = rd;
	// reuse the previous rotation matrix
	rorot.xy = m*rorot.xy;
	rdrot.xy = m*rdrot.xy;
	hit = min(hit, roof(rorot, rdrot));
	
	// floor
	float floorHit = -(ro.y + 0.95)/rd.y;
	if (floorHit < 0)
		floorHit = INF;
	hit = min(hit, floorHit);

	return hit;
}

float particles (vec3 p)
{
	vec3 pos = p;
	pos.y -= iGlobalTime*0.02;
	float n = fbm(20.0*pos);
	n = pow(n, 5.0);
	float brightness = noise(10.3*p);
	float threshold = 0.26;
	return smoothstep(threshold, threshold + 0.15, n)*brightness*90.0;
}

float transmittance (vec3 p)
{
	return exp (0.4*p.y);
}

#define STEPS 50

vec3 inscatter (vec3 ro, vec3 rd, vec3 roLight, vec3 rdLight, vec3 lightDir, float hit, vec2 screenPos)
{
	float far;
	float near = box(roLight + vec3(0.0, 1.0, 0.0), rdLight, vec3(1.5, 3.0, 1.5), far);
	if(near == INF || hit < near)
		return vec3(0);
	
	float distAlongView = min(hit, far) - near;
	float oneOverSteps = 1.0/float(STEPS);
	vec3 step = rd*distAlongView*oneOverSteps;
	vec3 pos = ro + rd*near;
	float light = 0.0;
	
	// add noise to the start position to hide banding
	pos += rd*noise(vec3(2.0*screenPos, 0.0))*0.05;

	for(int i = 0; i < STEPS; i++)
	{
		float l = intersect(pos, lightDir) == INF ? 1.0 : 0.0;
		l *= transmittance(pos);
		light += l;
		light += particles(pos)*l;
		pos += step;
	}

	light *= oneOverSteps * distAlongView;
	return light*vec3(0.6);
}

vec3 rot (vec3 v, vec3 axis, vec2 sincosangle)
{
	return v*sincosangle.y + cross(axis, v)*sincosangle.x + axis*(dot(axis, v))*(1.0 - sincosangle.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	float fov = 100.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	vec3 ro = vec3( 2, 0.0, 0);
	vec3 rd = normalize(rotate(vec3( p.x, p.y, 1 ), vec3(0,90,0)));

	// raycast the scene
	float dist = intersect(ro,rd);
	
	// white window -> no hit
	if (dist == INF)
	{
		fragColor = vec4(1.0);
		return;
	}

	vec3 hitPos = ro + dist * rd;
	
	// direct light (screw shading!)
	vec3 lightPos = ro+ROOFPOS;
	vec3 lightDir = normalize(vec3(-0.4,1,0));
	float shadowBias = 1.0e-4;
	vec3 col = vec3(0.0);

	//the lighting of the floor
	float d = intersect(hitPos + lightDir*EPSILON, lightDir);
	vec3 hitPos2 = hitPos + d*lightDir;
	if (d == INF && hitPos2.y>boxPos.y)
		col = vec3(0.8);

	col += inscatter(ro, rd, lightPos, rd, lightDir, dist, fragCoord.xy);
	
	// color correction - Sherlock color palette ;)
	col.r = smoothstep(0.0, 1.0, col.r);
	col.g = smoothstep(0.0, 1.0, col.g - 0.1);
	col.b = smoothstep(-0.3, 1.3, col.b);
	
	fragColor = vec4(col, 0.0);
}

void main()
{
	mainImage(gl_FragColor, gl_FragCoord.xy);
}