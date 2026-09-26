shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

group_uniforms OKLCH_Values;
uniform bool use_l = true;
uniform bool use_c = true;
uniform bool use_h = true;
uniform float steps_l : hint_range(1.0, 500.0, 1.0) = 500;
uniform float level_c : hint_range(0.01, 30.0) = 30;
uniform float level_h : hint_range(0.01, 1.0) = 1;
group_uniforms;

vec3 rgb_to_oklch(vec3 rgb) {
	vec3 linear_rgb;
	linear_rgb.r = (rgb.r <= 0.04045) ? rgb.r / 12.92 : pow((rgb.r + 0.055) / 1.055, 2.4);
	linear_rgb.g = (rgb.g <= 0.04045) ? rgb.g / 12.92 : pow((rgb.g + 0.055) / 1.055, 2.4);
	linear_rgb.b = (rgb.b <= 0.04045) ? rgb.b / 12.92 : pow((rgb.b + 0.055) / 1.055, 2.4);

	float x = linear_rgb.r * 0.4124 + linear_rgb.g * 0.3576 + linear_rgb.b * 0.1805;
	float y = linear_rgb.r * 0.2126 + linear_rgb.g * 0.7152 + linear_rgb.b * 0.0722;
	float z = linear_rgb.r * 0.0193 + linear_rgb.g * 0.1192 + linear_rgb.b * 0.9505;

	float x_norm = x / 0.95047;
	float y_norm = y / 1.0;
	float z_norm = z / 1.08883;

	float fx = (x_norm > 0.008856) ? pow(x_norm, 1.0 / 3.0) : (7.787 * x_norm + 16.0 / 116.0);
	float fy = (y_norm > 0.008856) ? pow(y_norm, 1.0 / 3.0) : (7.787 * y_norm + 16.0 / 116.0);
	float fz = (z_norm > 0.008856) ? pow(z_norm, 1.0 / 3.0) : (7.787 * z_norm + 16.0 / 116.0);

	float l_lab = 116.0 * fy - 16.0;
	float a_lab = 500.0 * (fx - fy);
	float b_lab = 200.0 * (fy - fz);

	float c = sqrt(a_lab * a_lab + b_lab * b_lab);
	float h = degrees(atan(b_lab, a_lab));
	if (h < 0.0) h += 360.0;

	return vec3(l_lab / 100.0, c / 100.0, h);
}

vec3 oklch_to_rgb(vec3 lch) {
	float l = lch.x * 100.0;
	float c = lch.y * 100.0;
	float h_rad = radians(lch.z);

	float a_lab = cos(h_rad) * c;
	float b_lab = sin(h_rad) * c;

	float fy = (l + 16.0) / 116.0;
	float fx = a_lab / 500.0 + fy;
	float fz = fy - b_lab / 200.0;
	vec3 f = vec3(fx, fy, fz);
	vec3 f_cubed = pow(f, vec3(3.0));

	vec3 mask_xyz = step(vec3(0.008856), f_cubed);
	vec3 xyz = mask_xyz * f_cubed + (1.0 - mask_xyz) * ((f - vec3(16.0/116.0)) / 7.787);
	xyz *= vec3(0.95047, 1.0, 1.08883);

	float r = xyz.x *  3.2406 + xyz.y * -1.5372 + xyz.z * -0.4986;
	float g = xyz.x * -0.9689 + xyz.y *  1.8758 + xyz.z *  0.0415;
	float b = xyz.x *  0.0557 + xyz.y * -0.2040 + xyz.z *  1.0570;
	vec3 linear_rgb = vec3(r, g, b);

	vec3 linear_gamma = linear_rgb * 12.92;
	vec3 non_linear_gamma = 1.055 * pow(linear_rgb, vec3(1.0 / 2.4)) - 0.055;
	vec3 mask_rgb = step(linear_rgb, vec3(0.0031308));

	return clamp(mix(non_linear_gamma, linear_gamma, mask_rgb), 0.0, 1.0);
}

float posterize(float value, float levels) {
	return round(value * levels) / levels;
}

void fragment() {
	vec4 original_sc = texture(SCREEN_TEXTURE, SCREEN_UV);
	vec3 oklch = rgb_to_oklch(original_sc.rgb);

	if (use_l) oklch.r = posterize(oklch.r, steps_l);
	if (use_c) oklch.g = posterize(oklch.g, level_c);
	if (use_h) oklch.b = posterize(oklch.b, level_h);

	COLOR = vec4(oklch_to_rgb(oklch), 1.0);
}