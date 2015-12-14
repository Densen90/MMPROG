uniform vec2 iResolution;
uniform float iGlobalTime;
// Robert Cupisz 2013
// Creative Commons Attribution-ShareAlike 3.0 Unported
//
// Bits of code taken from Inigo Quilez, including fbm(), impulse()
// and friends, sdCone() and friends; also box() by Simon Green.

#define INF 1.0e38
#define HIT(x) hit = min(hit, x)

// Shadow rays can make things faster if there are big occluders
// but kinda ugly with no #include statement
//#define HIT(x) if (x < INF) return 0.0

mat3 m = mat3( 0.00,  0.80,  0.60,
			  -0.80,  0.36, -0.48,
			  -0.60, -0.48,  0.64 );

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
	f  = 0.5000*noise( p ); p = m*p*2.02;
	f += 0.2500*noise( p ); p = m*p*2.03;
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

float impulse (float k, float x)
{
	float h = k * x;
	return h * exp (1.0 - h);
}

float impulse2 (float k0, float k1, float x)
{
	float k = k0;
	if (x > 1.0/k0)
	{
		x += 1.0/k1 - 1.0/k0;
		k = k1;
	}
	float h = k * x;
	return h * exp (1.0 - h);
}

float cubicPulse (float w, float x)
{
	x = abs (x);
	if (x > w)
		return 0.0;
	x /= w;
	return 1.0 - x * x * (3.0 - 2.0 * x);
}

mat2 rot(float angle)
{
	float c = cos(angle);
	float s = sin(angle);
	return mat2(c,-s,s,c);
}

float sdCone( vec3 p, vec2 c )
{
	// c must be normalized
	float q = length(p.xy);
	return dot(c,vec2(q,p.z));
}

float sdPlane (vec3 p, vec4 n)
{
	// n must be normalized
	return dot(p,n.xyz) + n.w;
}

float sdSphere (vec3 p, float s)
{
	return length(p)-s;
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

#define ROOFPOS vec3(0,-1,0.01)

float intersect (vec3 ro, vec3 rd)
{
	float hit = INF;
	
	// stuff
	mat2 m = rot(3.5);
	vec3 rorot = ro + vec3(0.4,-0.6,0.3);
	vec3 rdrot = rd;
	
	// roof
	rorot = ro + ROOFPOS;
	rdrot = rd;
	// reuse the previous rotation matrix
	rorot.xy = m*rorot.xy;
	rdrot.xy = m*rdrot.xy;
	HIT(roof(rorot, rdrot));
	
	// floor
	float floorHit = -(ro.y + 0.95)/rd.y;
	if (floorHit < 0.0)
		floorHit = INF;
	HIT(floorHit);

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
	vec2 q = fragCoord.xy/iResolution.xy;
	vec2 p = -1.0 + 2.0*q;
	p.x *= iResolution.x/iResolution.y;

	// camera
	vec3 ro = normalize(vec3(1.0,-0.1,0.1));
	float cameraAngle = 0.5;
	float cca = cos(cameraAngle);
	float sca = sin(cameraAngle);
	mat2  m = mat2(cca,-sca,sca,cca);
	ro = vec3(m*ro.xz,ro.y).xzy;
	vec3 w = -ro;
	ro *= 2.5;
	vec3 u = normalize(cross( vec3(0.0,1.0,0.0), w ));
	vec3 v = normalize(cross(w,u));
	vec3 rd = normalize( p.x*u + p.y*v + 1.5*w );

	// raycast the scene
	float hit = intersect(ro,rd);
	vec3 hitPos = ro + hit * rd;
	
	// white window
	if (hit == INF)
	{
		fragColor = vec4(1.0);
		return;
	}
	
	// direct light (screw shading!)
	vec3 lightRotAxis = normalize(vec3(0.707*sin(iGlobalTime),0,0.707*cos(iGlobalTime))); //1,0,1 normalized
	vec2 lightAngleSinCos = vec2(sin(0.28), cos(0.28));
	vec3 lightDir = rot(vec3(0,1,0), lightRotAxis, lightAngleSinCos);
	float shadowBias = 1.0e-4;
	vec3 c = vec3(0.0);
	if (intersect(hitPos + lightDir*shadowBias, lightDir) == INF)
		c = vec3(0.9);
	
	// inscatter
	lightAngleSinCos.x *= -1.0; // rev angle
	vec3 roLight = rot(ro + ROOFPOS, lightRotAxis, lightAngleSinCos);
	vec3 rdLight = rot(rd, lightRotAxis, lightAngleSinCos);
	c += inscatter(ro, rd, roLight, rdLight, lightDir, hit, fragCoord.xy);
	
	// color correction - Sherlock color palette ;)
	// c.r = smoothstep(0.0, 1.0, c.r);
	// c.g = smoothstep(0.0, 1.0, c.g - 0.1);
	// c.b = smoothstep(-0.3, 1.3, c.b);
	
	fragColor = vec4(c, 0.0);
}

void main()
{
	mainImage(gl_FragColor, gl_FragCoord);
}