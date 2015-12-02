uniform sampler2D tex;
uniform vec2 iResolution;
in vec2 uv;

#define PI 3.14159

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

float calculateConeRad(in float h, in vec2 uv)
{
	float minAngle = PI/2.0;
	float stepSize = 1.0/iResolution;

	for(float x=0.0; x<=1.0; x+=stepSize)
	{
		for(float y=0.0; y<=1.0; y+=stepSize)
		{
			vec2 newUV = vec2(x,y);
			float newHeight = texture2D(tex, newUV);
			if(newHeight>h)
			{
				//calculate angle
				float dist = length(newUV-uv);
				float deltaHeight = newHeight - h;
				float angle = (PI/2.0) - atan(deltaHeight/dist);
				minAngle = angle<minAngle ? (angle+minAngle)/2.0 : minAngle;
			}
		}
	}

	return minAngle;
}

void main()
{
	float height = texture2D(tex, uv);
	float cone_rad = calculateConeRad(height, uv);

	gl_FragColor = vec4(cone_rad/(0.5*PI), height , 0.0, 1.0) ;
	// gl_FragColor = vec4(height);
}



// float maxSteps = 8.0;
	// float minAngle = 360.0;
	// //go 8 times around point and look on ray for several degrees if there is an intersection
	// for(float i=0.0; i<maxSteps; i++)
	// {
	// 	float rad = (i*(maxSteps/360.0))*180.0/PI;
	// 	vec2 xzDir = normalize(vec2(sin(rad), cos(rad)));

	// 	for(float j=0.0; j<1.0; j+=0.01)
	// 	{
	// 		vec2 newUV = uv + j*xzDir;
	// 		//calculate height
	// 		float newHeight = texture2D(tex, newUV);
	// 		//check if bigger
	// 		if(newHeight>h)
	// 		{
	// 			//calculate angle
	// 			vec3 v1 = vec3(uv.x, h, uv.y) - vec3(newUV.x, newHeight, newUV.y);
	// 			vec3 v2 = vec3(uv.x, h, uv.y) - vec3(newUV.x, h, newUV.y);
	// 			float angle = acos( dot(v1,v2)/(length(v1)*length(v2)) ) * 180.0/PI;
	// 			//check for smallest angle
	// 			minAngle = angle<minAngle ? angle : minAngle;
	// 		}
	// 	}
	// }