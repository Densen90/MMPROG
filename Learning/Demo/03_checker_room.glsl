uniform vec2 iResolution;
uniform float iGlobalTime;
uniform sampler2D tex0;
uniform sampler2D tex1;
in vec2 uv;

const int maxSteps = 256;
const float ambient = 0.2;
const float epsilon = 0.0001;
const float maxDepth = 100.0;
const float aoSamples = 5.0;
const vec3 diffuse = vec3(1, 1, 1);
const vec3 lightCol = vec3(1,1,1);
const vec3 lightDir = normalize(vec3(0.5, 0.5, 1.0));

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

float distBox(vec3 point, vec3 center, vec3 b )
{
  return length(max(abs(point - center) - b, vec3(0.0)));
}

vec3 pointRepetitionXZ(vec3 point, vec3 c)
{
	point.x = mod(point.x, c.x) - 0.5*c.x;
	point.z = mod(point.z, c.z) - 0.5*c.z;
	return point;
}

float distanceField(vec3 p)
{
	float bound = 1.0;
	// if(p.y<-bound || p.y>bound) return maxDepth;

	vec3 point = p;
	// point.y += sin(point.z - iGlobalTime * 6.0) * cos(point.x - iGlobalTime) * .25; //waves!
	// point.y += texture2D(tex0, vec2(mod(p.x/50.0, 1.0), mod(p.z/50.0, 1.0)))*0.125;
	float ret = distPlane(point, normalize(vec3(0, 1, 0)), -0.499);

	float expansion = 0.4;
	vec3 repet = pointRepetitionXZ(p, vec3(expansion, 0.0, expansion));
	vec3 dimen = vec3(expansion/4.0, 0.75 * (0.5*(sin(iGlobalTime+repet.x*2)+1.0)), expansion/4.0);

	ret = min(ret, distBox(repet, vec3(0, -0.5, 0), dimen));

	return ret;
}

// marching along the ray at step sizes, 
// and checking whether or not the surface is within a given threshold
vec4 raymarch(vec3 rayOrigin, vec3 rayDir, out float steps)
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
	float h = 0.0001;
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

//calculatte the color, the shadow, the lighting for a position
vec3 shading(vec3 pos, vec3 rd, vec3 n)
{
	vec3 light = max(ambient, dot(n, lightDir)) * lightCol;	//lambert light with light Color
	light *= diffuse;	//diffuse lighting, area lit lighting
	light *= shadow(pos, lightDir);	//add shadow
	light += ambientOcclusion(pos, n) * ambient;
	// light *= texture2D(tex0, pos.xz/5.0);
	return light;
}

void main()
{
	float fov = 60.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	cam.pos = vec3(0,0,iGlobalTime);
	cam.dir = normalize(vec3( p.x, p.y, 1 ));

	vec4 res;
	float steps;
	res = raymarch(cam.pos, cam.dir, steps);
	res.xyz = (res.a==1.0) ? clamp(shading(res.xyz, cam.dir, getNormal(res.xyz)), 0.0, 1.0) : vec3(1);

	//fog
	vec3 fogColor = vec3(1);
	float fogDist = 100;
	res.xyz = mix(res.xyz, fogColor, steps/fogDist);

	gl_FragColor = vec4(res.xyz, 1.0);
}