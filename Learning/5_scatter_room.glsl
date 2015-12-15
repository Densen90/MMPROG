uniform vec2 iResolution;
uniform float iGlobalTime;
// Robert Cupisz 2013
// Creative Commons Attribution-ShareAlike 3.0 Unported
//
// Bits of code taken from Inigo Quilez, including fbm()

#define INF 1.0e38
#define PI 3.14159
#define SCATTER_STEPS 128
#define SCATTERPOWER 0.7

const vec3 ROOFPOS = vec3(0.2,-1,0.01);
float lightStrength = 0.0;

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

//Perlin Noise Function, thanks to Robert Cupisz
float fbm (vec3 p)
{
	mat3 m = mat3( 0.00,  0.80,  0.60,
			  -0.80,  0.36, -0.48,
			  -0.60, -0.48,  0.64 );
	float f;
	f  = 0.5000*noise( p ); p = m*p*2.02;
	f += 0.2500*noise( p ); p = m*p*2.03;
	f += 0.1250*noise( p );
	// f += 0.0625*noise( p );
	return f;
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

float roof(vec3 roofPos, vec3 dir)
{
	float dist = -roofPos.y/dir.y;

	// An offset, so that shadow rays starting from the roof don't
	// think they're unoccluded
	if (dist < -0.1)
		return INF;
	
	// We've hit the plane. If we've hit the window, but
	// not the beams, return no hit.
	float spread = 0.81;
	vec2 pos = roofPos.xz + dist*dir.xz;	//go to position of the roof
	vec2 window = abs(pos) - spread;	//abs -> limit spread

	float winDist = 0.055;	//how far away the windows are from each other
	// double beams -> windows: size of window: 0.544, shifted by 0.27
	vec2 beams = winDist - abs(mod(pos, 0.41) - 0.43);
	if (max(max(window.x, window.y), max(beams.x, beams.y)) < 0.0)
		return INF;

	return dist;
}

float intersect (vec3 ro, vec3 rd)
{
	//Raycasting with two planes (Floor and roof)
	float dist = INF;

	//check if hit is at the World Position of RoofPosition
	vec3 roofPos = rotate(ro+ROOFPOS, vec3(30, 0, 0));
	vec3 rayDir = rotate(rd, vec3(30, 0, 0));
	dist = min(dist, roof(roofPos, rayDir));
	
	// floor
	float floorPos = 0.95;
	float floorHit = -(ro.y + floorPos)/rd.y;
	if (floorHit < 0.0)
	{
		floorHit = INF;
	}
	dist = min(dist, floorHit);

	return dist;
}

float particles (vec3 p)
{
	vec3 pos = p;
	pos.y -= iGlobalTime*0.2;	//particles moving up
	float n = fbm(20.0*pos);
	n = pow(n, 5.0);
	float brightness = noise(10.3*p);
	float threshold = 0.26;
	return smoothstep(threshold, threshold + 0.15, n)*brightness*90.0;
}

vec3 inscatter (vec3 ro, vec3 rd, vec3 lightDir, float hit, vec2 screenPos)
{
	float farPlane = 3.0;
	
	float distAlongView = min(hit, farPlane);	//distance not higher than farPlane
	float oneOverSteps = 1.0/float(SCATTER_STEPS);
	vec3 step = rd*distAlongView*oneOverSteps;	//how long is one step on the scatter ray
	vec3 pos = ro;
	float light = 0.0;
	
	// add noise to the start position to hide banding
	pos += rd*noise(vec3(2.0*screenPos, 0.0))*0.05;

	for(int i = 0; i < SCATTER_STEPS; i++)
	{
		//if hit, it is black, else white, later the mean is builded to have a transparent godray
		float l = intersect(pos, lightDir) == INF ? 1.0 : 0.0;
		light += l;
		//particles only if they are in the godray
		light += particles(pos)*l;
		pos += step;
	}

	light *= oneOverSteps * distAlongView;	//the mean(Durchschnitt)
	return light*SCATTERPOWER;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	float fov = 100.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	vec3 ro = vec3( 0.0, 0.0, -2.0 );
	vec3 rd = normalize(vec3( p.x, p.y, 1 ));

	// raycast the scene
	float d = intersect(ro,rd);
	
	// white window -> no hit
	if (d == INF)
	{
		fragColor = vec4(1.0);
		return;
	}

	vec3 hitPos = ro + d * rd;

	float shadowBias = 1.0e-4;
	vec3 rotation = vec3(cos(iGlobalTime)*20,0,sin(iGlobalTime)*10);
	// rotation = vec3(0);
	vec3 lightDir = rotate(normalize(vec3(0,1,0)), rotation);

	vec3 c = vec3(0.0);
	//raycast from hitPoint + lightDir, if no hit, draw white (same as roof window)
	if (intersect(hitPos + lightDir*shadowBias, lightDir) == INF)
		c = vec3(0.6);

	c += inscatter(ro, rd, lightDir, d, fragCoord.xy);
	
	// color correction - Sherlock color palette ;)
	c.r = smoothstep(0.0, 0.5, c.r);
	c.g = smoothstep(0.0, 0.5, c.g - 0.1);
	c.b = smoothstep(-0.3, 1.5, c.b);
	
	fragColor = vec4(c, 1.0);
}

void main()
{
	mainImage(gl_FragColor, gl_FragCoord);
}