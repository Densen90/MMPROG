uniform vec2 iResolution;
uniform float iGlobalTime;
uniform sampler2D tex;
in vec2 uv;

const int maxSteps = 200;	// slow if the step size is small, and inaccurate if the step size is large
const float epsilon = 0.0001;
const float ambient = 0.2;
const float PI = 3.14159;
const float bigNumber = 10000.0;

const float triggerTime1 = 2.75;
const float animTime1 = 0.15;
const float triggerTime2 = 6.3;
const float animTime2 = 0.15;
const float triggerTime3 = 10.0;
const float animTime3 = 0.15;
const float triggerTime4 = 13.8;
const float animTime4 = 0.15;
const float triggerTime5 = 14.5;
const float animTime5 = 4.0;

int currentAnim = 0;

struct Cam
{
	vec3 orig;
	vec3 dir;
};

struct Light
{
	vec3 orig;
	vec3 dir;
};

struct Material
{
	vec3 col;
	float refCoef;
};

struct Intersection
{
	vec3 IP;
	vec3 normal;
	Material mat;
};

Light light;
Cam cam;
Intersection intersect;
Material matWhite;

void init();
int timeTrigger();
bool raymarch(vec3 O, vec3 D);
float ambientOcclusion(vec3 O, vec3 D);
float lighting(vec3 N, vec3 IP);
vec3 getNormal(vec3 P);
vec3 rotate( vec3 p, vec3 r );

void main()
{
	init();

	currentAnim = timeTrigger();

	bool hit = raymarch(cam.orig, cam.dir);

	vec3 col = hit ? intersect.mat.col : vec3(0.0);

	col *= lighting(intersect.normal, intersect.IP);

	//ambientOcclusion
	float ao = ambientOcclusion(intersect.IP, intersect.normal);
	// col *= ao;
	
	gl_FragColor = vec4(col, 1.0);
}

void init()
{
	//shift camera to center, origin(0,0) is now at middle of screen
	float fov = 60.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	cam.orig = vec3(0.0,0.0,-2.5 + sin(iGlobalTime*12.0)*0.2);
	cam.dir = normalize(vec3( p.x, p.y, 1 ));

	light.orig = vec3(0, 0, 0);

	matWhite.col = vec3(1.0);
	matWhite.refCoef = 0.0;
}

int timeTrigger()
{
	if(iGlobalTime>=triggerTime1 && iGlobalTime<triggerTime2) return 1;
	else if(iGlobalTime>=triggerTime2 && iGlobalTime<triggerTime3) return 2;
	else if(iGlobalTime>=triggerTime3 && iGlobalTime<triggerTime4) return 3;
	else if(iGlobalTime>=triggerTime4 && iGlobalTime<triggerTime5) return 4;
	else if(iGlobalTime>=triggerTime5) return 5;

	return 0;
}

float si(float x)
{
	return x==0.0 ? 0.0 : sin(x)/x;
}

// unions two distances / objects
float opUnion( float d1, float d2 )
{
    return min(d1,d2);
}

// substracts two distances / objects
float opSubstract( float d1, float d2 )
{
    return max(-d1,d2);
}

// intersects two distances / objects
float opIntersect( float d1, float d2 )
{
    return max(d1,d2);
}

//get rotation matrix for angle
mat3 RotationMatrix(float angleX, float angleY, float angleZ)
{
	angleX = angleX*PI/180.0;
	angleY = angleY*PI/180.0;
	angleZ = angleZ*PI/180.0;

	mat3 xRot = mat3 (	1,	0,				0,
						0,	cos(angleX),	-sin(angleX),
						0,	sin(angleX),	cos(angleX) );
	mat3 yRot = mat3 ( 	cos(angleY),		0,	sin(angleY),
						0,					1,	0,
						-sin(angleY),		0,	cos(angleY) );
	mat3 zRot = mat3 (	cos(angleZ),	-sin(angleZ),	0,
						sin(angleZ),	cos(angleZ),	0,
						0,				0,				1 );
	return xRot * yRot * zRot;
}

// Rotation / Translation of a point p with rotation r
vec3 rotate( vec3 p, vec3 r )
{
    return RotationMatrix(r.x, r.y, r.z)*p;
}

float distSphere(vec3 p, float rad)
{
	return length(p) - rad;
}

float distTriPrism( vec3 p, vec2 h )
{
    vec3 q = abs(p);
    return max(q.z-h.y,max(q.x*0.866025+p.y*0.5,-p.y)-h.x*0.5);
}

//Returns the closest distance to a surface from p in our scene, 
//we can step this far, without overshooting
float distanceField(vec3 p)
{
	float ret;
	// float rot = sin(iGlobalTime)*360.0;
	// vec3 pos = rotate(p-vec3(0, 0, 3), vec3(0,0,rot));
	// float dist1 = distTriPrism(pos, vec2(0.6));
	// float dist2 = distSphere(pos, 0.6);
	// ret = opUnion(dist1, dist2);
	// ret = clamp(mix(dist1, dist2, sin(iGlobalTime)), 0.0, 1.0);

	// pos = rotate(p-vec3(0, 0, 3.0), vec3(0,0,rot+180.0));
	// dist1 = distTriPrism(pos, vec2(0.4));
	// dist2 = distSphere(pos, 0.6);
	// float tmp = clamp(mix(dist1, dist2, sin(iGlobalTime)), 0.0, 1.0);

	// ret = opUnion(ret, tmp);

	vec3 pos = p-vec3(0, 0, 3);
	vec2 triSize = vec2(1.0,0.5);
	float tri1, tri2, tri3, tri4, sph1;
	tri1 = tri2 = tri3 = tri4 = sph1 = bigNumber;

	intersect.mat = matWhite;

	switch(currentAnim)
	{
		case 0:
			tri1 = distTriPrism(pos, triSize);
			ret = tri1;
			break;
		case 1:
			tri1 = distTriPrism(pos, triSize);
			float rot = mix(0.0, 60.0, clamp((iGlobalTime-triggerTime1)/animTime1, 0.0, 1.0));
			tri2 = distTriPrism(rotate(pos, vec3(0,0,rot)), triSize);
			ret = opUnion(tri1, tri2);
			break;
		case 2:
			tri1 = distTriPrism(pos, triSize);
			vec3 trans1 = mix(vec3(0), vec3(1.0, 0.5, 0.0), clamp((iGlobalTime-triggerTime2)/animTime2, 0.0, 1.0));
			tri2 = distTriPrism(rotate(pos-trans1, vec3(0,0,60)), triSize);
			tri3 = distTriPrism(rotate(pos, vec3(0,0,60)), triSize);
			ret = opUnion(tri1, opUnion(tri2, tri3));
			break;
		case 3:
			tri1 = distTriPrism(pos, triSize);
			vec3 trans2 = mix(vec3(0), vec3(-1.0, 0.5, 0.0), clamp((iGlobalTime-triggerTime3)/animTime3, 0.0, 1.0));
			tri2 = distTriPrism(rotate(pos-vec3(1.0, 0.5, 0.0), vec3(0,0,60)), triSize);
			tri3 = distTriPrism(rotate(pos-trans2, vec3(0,0,60)), triSize);
			tri4 = distTriPrism(rotate(pos, vec3(0,0,60)), triSize);
			ret = opUnion(tri1, opUnion(tri2, opUnion(tri3, tri4)));
			break;
		case 4:
			tri1 = distTriPrism(pos, triSize);
			vec3 trans3 = mix(vec3(0), vec3(0.0, -1.1, 0.0), clamp((iGlobalTime-triggerTime4)/animTime4, 0.0, 1.0));
			tri2 = distTriPrism(rotate(pos-vec3(1.0, 0.5, 0.0), vec3(0,0,60)), triSize);
			tri3 = distTriPrism(rotate(pos-vec3(-1.0, 0.5, 0.0), vec3(0,0,60)), triSize);
			tri4 = distTriPrism(rotate(pos-trans3, vec3(0,0,60)), triSize);
			ret = opUnion(tri1, opUnion(tri2, opUnion(tri3, tri4)));
			break;
		case 5:
			float pRot = (iGlobalTime-triggerTime5)*30;
			tri1 = distTriPrism(rotate(pos, vec3(0,0,-pRot)), triSize);
			tri2 = distTriPrism(rotate(pos-vec3(1.0, 0.5, 0.0), vec3(0,0,60+pRot)), triSize);
			tri3 = distTriPrism(rotate(pos-vec3(-1.0, 0.5, 0.0), vec3(0,0,60+pRot)), triSize);
			tri4 = distTriPrism(rotate(pos-vec3(0.0, -1.1, 0.0), vec3(0,0,60+pRot)), triSize);
			sph1 = distSphere(pos-vec3(0,0,0.9), 2.0);
			ret = opUnion(tri1, opUnion(tri2, opUnion(tri3, tri4)));
			ret = mix(ret, sph1, clamp((iGlobalTime-triggerTime5)/animTime5, 0.0, 1.0));
			break;
	}

	// tri1 = distTriPrism(pos, triSize);
	// tri2 = distTriPrism(rotate(pos-vec3(1.0, 0.5, 0.0), vec3(0,0,60)), triSize);
	// tri3 = distTriPrism(rotate(pos-vec3(-1.0, 0.5, 0.0), vec3(0,0,60)), triSize);
	// tri4 = distTriPrism(rotate(pos-vec3(0.0, -1.1, 0.0), vec3(0,0,60)), triSize);
	// sph1 = distSphere(pos-vec3(0,0,0.9), 2.0);
	// ret = opUnion(sph1, opUnion(tri1, opUnion(tri2, opUnion(tri3, tri4))));
	return ret;
}

// marching along the ray at step sizes, 
// and checking whether or not the surface is within a given threshold
bool raymarch(vec3 rayOrigin, vec3 rayDir)
{
	float totalDist = 0.0;
	for(int j=0; j<maxSteps; j++)
	{
		vec3 p = rayOrigin + totalDist*rayDir;
		float dist = distanceField(p);
		if(dist<epsilon)	//if it is near the surface, return an intersection
		{
			intersect.IP = rayOrigin + totalDist*rayDir;
			intersect.normal = getNormal(rayOrigin + totalDist*rayDir);
			return true;
		}
		totalDist += dist;
	}

	return false;
}

// Approximates the (normalized) gradient of the distance function at the given point.
// If p is near a surface, the function will approximate the surface normal.
vec3 getNormal(vec3 p)
{
	float h = 0.0001;
	return normalize(vec3(
		distanceField(p + vec3(h, 0, 0)) - distanceField(p - vec3(h, 0, 0)),
		distanceField(p + vec3(0, h, 0)) - distanceField(p - vec3(0, h, 0)),
		distanceField(p + vec3(0, 0, h)) - distanceField(p - vec3(0, 0, h))));
}

//Calculates the lambert and specular light, for a given IntersectionPoint
float lighting(vec3 normal, vec3 IP)
{
	light.dir = normalize(light.orig-IP);	//for point light

	//Lambert Lighting
	float lambert = max(ambient, dot(normal, light.dir));

	//Specular Lighting
	vec3 reflection = normalize(reflect(light.dir, normal));
	vec3 viewDirection = normalize(IP);
	float spec = max(ambient, dot(reflection, viewDirection));
	spec = lambert+pow(spec, 20.0);

	return spec;
}

float ambientOcclusion(vec3 ro, vec3 rd)
{
	float step = 0.01;
	float ao = distanceField(ro + step*rd);
	float res = ao/step;	//if ao, distance to nearest object is smaller than the step
					//point is in a narrow place, if bigger, ao is bigger, o ambient ambient Occlusion
	return clamp(res, 0.8, 1.0);
}