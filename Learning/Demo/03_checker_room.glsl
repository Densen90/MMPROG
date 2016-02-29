uniform vec2 iResolution;
uniform float iGlobalTime;
uniform float uHeight;
uniform float uTwist;
uniform float uFade;
uniform float uBeatValue;
uniform float uBoxYPos;
uniform float uXRotation;
uniform float uZRotation;
uniform float uCameraXRot, uCameraZRot;
uniform sampler2D tex3;
uniform sampler2D tex4;
in vec2 uv;

const float moveSpeed = 4.5;
const int maxSteps = 256;
const float pi = 3.14159;
const float ambient = 0.1;
const float brightness = 3.0;
const float epsilon = 0.0001;
const float maxDepth = 60.0;
const float aoSamples = 5.0;
const vec3 diffuse = vec3(1, 1, 1);
const vec3 lightCol = vec3(1,1,1);
const vec3 lightDir = normalize(vec3(0.5, 0.5, -1.0));
const vec3 lightDir2 = normalize(vec3(-0.5, 0.5, -1.0));

vec3 color = vec3(1.0);

int hitRefractionBox = 0;

struct Camera
{
	vec3 pos;
	vec3 dir;
} cam;

// give the distance to a plane from a point p and normal n, shifted by y
float distPlane( vec3 p, vec3 n, float y )
{
	// n must be normalized
	return dot(p,n) - y;
}

// give the distance from point p to a sphere surface at origin
float distSphere(vec3 p, float rad)
{
	return length(p) - rad;
}

float distBox(vec3 point, vec3 center, vec3 b )
{
  return length(max(abs(point - center) - b, vec3(0.0)));
}

float distRoundBox(vec3 p, vec3 b, float r)
{
 	return length(max(abs(p)-b,0.0))-r;
}

vec3 pointRepetition(vec3 point, vec3 c)
{
	point.x = mod(point.x, c.x) - 0.5*c.x;
	point.z = mod(point.z, c.z) - 0.5*c.z;
	return point;
}

// Rotation / Translation of a point p with rotation r
vec3 rotate( vec3 p, vec3 r )
{
	r.x *= pi/180.0;
	r.y *= pi/180.0;
	r.z *= pi/180.0;

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

// twist the object
vec3 opTwist( vec3 p, float amount )
{
    float c = cos(amount*p.y);
    float s = sin(amount*p.y);
    mat2  m = mat2(c,-s,s,c);
    return vec3(m*p.xz,p.y);
}

float opUnionRound(float a, float b, float r) {
	vec2 u = max(vec2(r - a,r - b), vec2(0));
	return max(r, min (a, b)) - length(u);
}

float distanceField(vec3 p)
{
	hitRefractionBox = 0;
	float beatValue1 = uBeatValue;
	float beatValue2 = abs(1.7-uBeatValue);

	vec3 point = p;
	float expansion = 4.5;
	vec3 repPoint = pointRepetition(p, vec3(expansion, 0.0, expansion));
	vec3 repPoint2 = pointRepetition(p-vec3(0,0,expansion/2.0), vec3(expansion, 0.0, expansion));
	vec3 repPointSphere = pointRepetition(p-vec3(cos(iGlobalTime*moveSpeed*0.5)*expansion/4.0 * beatValue1,0,0), vec3(expansion, 0, expansion));
	vec3 repPointSphere2 = pointRepetition(p-vec3(sin(iGlobalTime*moveSpeed*0.5)*expansion/4.0 * beatValue1,0,expansion/2.0), vec3(expansion, 0, expansion));

	vec3 boxDimension1 = vec3(expansion/4.0 * beatValue1, beatValue1, (0.5*(cos(iGlobalTime*moveSpeed+repPoint.y)+1.0+0.1)));
	vec3 boxDimension2 = vec3(expansion/4.0 * beatValue1, beatValue2, (0.5*(sin(iGlobalTime*moveSpeed+repPoint.y)+1.0+0.1)));
	
	vec3 spherePos = vec3(repPointSphere.x-(1.6-beatValue1)*0.25, repPoint.y-beatValue1+0.3, repPointSphere.z);
	vec3 spherePos2 = vec3(repPointSphere2.x, repPoint2.y-beatValue2+0.3, repPointSphere2.z);

	float plane = distPlane(point, normalize(vec3(0, 1, 0)), -0.5);
	float boxes = distBox(repPoint, vec3((1.6-beatValue1)*0.25, -0.5, 0), boxDimension1);
	float boxes2 = distBox(repPoint2, vec3(0, -0.5, 0), boxDimension2);

	boxes = distRoundBox(repPoint-vec3((1.6-beatValue1)*0.25, -0.5, 0), boxDimension1, 0.01);
	boxes2 = distRoundBox(repPoint2-vec3(0, -0.5, 0), boxDimension2, 0.01);

	float spheres = distSphere(spherePos, 0.2);
	float spheres2 = distSphere(spherePos2, 0.2);

	vec3 refboxpos = rotate(p-cam.pos-vec3(0,uBoxYPos-(0.15-uHeight)-0.3,2.7), vec3(uXRotation,0,uZRotation));
	// refboxpos = opTwist(r efboxpos.xzy , uTwist);
	float refBox = distRoundBox(refboxpos, vec3(0.15*(0.15/uHeight), uHeight, 0.15), 0.15);

	plane = opUnionRound(plane, boxes, 0.3);
	plane = opUnionRound(plane, boxes2, 0.3);
	float ret = min(refBox, min(plane, min(spheres, spheres2)));

	if(ret==plane) color = vec3(1.0);
	else if(ret==boxes) color = vec3(0.5*(sin(beatValue1)+1.0), 0.6, 0.5*(cos(beatValue1)+1.0));
	else if(ret==boxes2) color = vec3(0.5*(sin(beatValue1)+1.0), 0.72, 0.5*(cos(beatValue1)+1.0));
	else if(ret==spheres) color = vec3(0.5*(sin(beatValue1*2.0)+1.0), 0.6, 0.5*(cos(beatValue1*2.0)+1.0));
	else if(ret==spheres2) color = vec3(0.5*(sin(beatValue1*2.0)+1.0), 0.72, 0.5*(cos(beatValue1*2.0)+1.0));
	else if(ret==refBox)
	{
		hitRefractionBox = 1;
		color = vec3(0);
	}

	return ret;
}

// marching along the ray at step sizes, 
// and checking whether or not the surface is within a given threshold
vec4 raymarch(vec3 rayOrigin, vec3 rayDir, out int steps)
{
	float totalDist = 0.0;
	for(int j=0; j<maxSteps; j++)
	{
		steps = j;
		vec3 p = rayOrigin + totalDist*rayDir;
		float dist = distanceField(p);
		if(abs(dist)<epsilon)	//if it is near the surface, return an intersection
		{
			return vec4(p, 1.0);
		}
		totalDist += dist;
		if(totalDist>=maxDepth) break;
	}
	return vec4(0);
}

// Approximates the (normalized) gradient of the distance function at the given point.
// If p is near a surface, the function will approximate the surface normal.
vec3 getNormal(vec3 p)
{
	float h = epsilon;
	return normalize(vec3(
		distanceField(p + vec3(h, 0, 0)) - distanceField(p - vec3(h, 0, 0)),
		distanceField(p + vec3(0, h, 0)) - distanceField(p - vec3(0, h, 0)),
		distanceField(p + vec3(0, 0, h)) - distanceField(p - vec3(0, 0, h))));
}

float shadow(vec3 ro, vec3 rd)
{
	float softshadowFac = 32.0;
	float res = 1.0;
    for( float t=0.01; t<32.0; )
    {
        float h = distanceField(ro + rd*t);
        if( h<epsilon )
            return ambient;
        res = min( res, softshadowFac*h/t );
        t += h;
    }
    return res;
}

//calculate ambient occlusion
float ambientOcclusion(vec3 p, vec3 n)
{
	float res = 0.0;
	float fac = 1.0;
	for(float i=0.0; i<aoSamples; i++)
	{
		float distOut = i*0.3;	//go on normal ray AOSAMPLES times with factor 0.3
		res += fac * (distOut - distanceField(p + n*distOut));	//look for every step, how far the nearest object is
		fac *= 0.5;	//for every step taken on the normal ray, the fac decreases, so the shadow gets brighter
	}
	return 1.0 - clamp(res, 0.0, 1.0);
}

//calculate the color, the shadow, the lighting for a position
vec3 shading(vec3 pos, vec3 rd, vec3 n)
{
	vec3 light = max(ambient*brightness, dot(n, lightDir)) * lightCol;	//lambert light with light Color
	
	light.r = smoothstep(0.0, 0.5, light.r);
	light.g = smoothstep(0.0, 0.5, light.g - 0.1);
	light.b = smoothstep(-0.3, 1.5, light.b);


	if(pos.x < 1.7) light *= shadow(pos, lightDir2);	//little trick to simulate two lights -> choose which light source depending on position
	if(pos.x > -1.7 ) light *= shadow(pos, lightDir);
	light += ambientOcclusion(pos, n) * ambient*brightness;
	// light *= texture2D(tex0, pos.xz/5.0);
	// float surf = texture2D(tex4, pos.xz*0.5+0.5);
	// light *= surf;
	return light;
}

vec3 bg(float aspect, vec2 uv, float size, float angle) {
    float powF = -10.0;
    vec2 xy;
    xy[0] = uv[0] - 0.5;
    xy[1] = uv[1] - 0.5;
    xy[1] /= aspect;
    xy[0] -= 0.5*sin(angle);
    xy[1] += 0.5*cos(angle);
    xy *= 20.0 * size;
    
    
    float pow1 = pow(abs(xy[0] * sin(angle) + xy[1] * cos(angle)),powF);
    float pow2 = pow(abs(xy[1] * sin(angle) - xy[0] * cos(angle)),powF);

    float outColor = clamp(
        pow1+pow2
        , 0.0, 1.0);

    return vec3(outColor);
}

//thanks to "0x17de" Shader "ColorfulCubes" from ShaderToy
vec3 background(vec3 bgColor)
{
	vec3 outColor = bgColor * sin(uv.x) * cos(uv.y);
	float speed = iGlobalTime / 4.0;
	float aspect = iResolution.x / iResolution.y;

	outColor /= 1.0-bg(aspect, uv, 8.0,  speed + pi);
	outColor /= 1.0-bg(aspect, uv, 4.0,  speed - pi/2.0);
	outColor /= 1.0-bg(aspect, uv, 2.0,  speed);
	outColor /= 1.0-bg(aspect, uv, 1.3,  speed + pi/2.0);

	outColor = clamp(outColor, vec3(0), vec3(0.9,0.8,0.8));

	return outColor;
}

void main()
{
	float fov = 60.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	cam.pos = vec3(0,0.3,iGlobalTime*4.0);
	cam.dir = rotate(normalize(vec3( p.x, p.y, 1 )), vec3(uCameraXRot-10, 0, uCameraZRot));

	vec4 res;
	int steps;
	res = raymarch(cam.pos, cam.dir, steps);
	vec3 currentCol = color; //save the color, the global color changes in shading (shadow & AO)

	if(res.a==1.0 || uFade>0.9)
	{
		//standard shading if not hit the refraction box
		if(hitRefractionBox==0)
		{		
			currentCol *= clamp(shading(res.xyz, cam.dir, getNormal(res.xyz)), 0.0, 1.0);
		}//refraction shading otherwise
		else
		{

			float st;
			
			vec3 n = getNormal(res.xyz);

			//Specular Lighting
			vec3 reflection = normalize(reflect(lightDir, n));
			vec3 viewDirection = normalize(res.xyz);
			float spec = max(ambient, dot(reflection, viewDirection));
			currentCol += pow(spec, 30);

			reflection = normalize(reflect(lightDir2, n));
			spec = max(ambient, dot(reflection, viewDirection));
			currentCol += pow(spec, 30);

			//first intersection --> inside the cube, air to water
			vec3 refractDir = normalize(refract(cam.dir, n, 1.0/1.3));
			res = raymarch(res.xyz - 0.01*n, refractDir, st);
			//second intersection --> outside of cube, water to air
			n = -getNormal(res.xyz);
			refractDir = normalize(refract(refractDir, n, 1.3/1.0));
			res = raymarch(res.xyz - 0.01*n, refractDir, st);
			currentCol += res.a==1.0 ? shading(res.xyz, refractDir, n) : background(vec3(0.7, 0.7, 0.6));
		}
	}
	else	//background
	{
		currentCol = background(vec3(0.8, 0.7, 0.5));
		// currentCol = texture2D(tex4, uv);
	}

	//fog
	vec3 fogColor = vec3(1.0);
	float fogDist = 200.0;
	currentCol *= pow(texture2D(tex3, uv).r, 2);	//vignette
	currentCol = mix(currentCol, fogColor, clamp((steps/fogDist)+uFade, 0, 1));

	

	gl_FragColor = vec4(currentCol, 1.0);
}