in vec2 translate;
in vec2 position;
in float angle;
in vec2 texture_coord;

out vec2 v_tex;

mat4 rotate2d(float angle) {
	return
	mat4( cos( angle ), -sin( angle ), 0.0, 0.0,
	      sin( angle ),  cos( angle ), 0.0, 0.0,
	      0.0,           0.0,          1.0, 0.0,
	      0.0,           0.0,          0.0, 1.0 );
}
void main() {
	vec4 pos4 = vec4(position, 0.0, 1.0)*rotate2d(angle);
	gl_Position = pos4+vec4(translate, 0.0, 0.0);
	v_tex = (texture_coord+vec2(1.0, 1.0))/2.0;
}
