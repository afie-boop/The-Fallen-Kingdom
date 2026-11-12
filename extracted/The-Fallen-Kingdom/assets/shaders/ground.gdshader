shader_type canvas_item;
// Draws the whole world in one pass: sea, beach sand, grass and bare soil, shaped by
// the island mask (scripts/island_map.gd): R = land height, G = amount of bare soil.

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D grass_tex : source_color, filter_linear, repeat_disable;   // one big unique image, never tiled
uniform sampler2D dirt_tex : source_color, filter_linear, repeat_enable;     // seamless soil
uniform sampler2D sand_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D water_tex : source_color, filter_nearest, repeat_enable;
uniform vec2 world_size = vec2(2400.0, 2400.0);
uniform vec2 dirt_px = vec2(768.0, 768.0);
uniform vec2 sand_px = vec2(240.0, 240.0);
uniform vec2 water_px = vec2(144.0, 144.0);

void fragment() {
	vec2 wp = UV * world_size;
	vec4 m = texture(mask_tex, UV);
	float v = m.r * 2.0 - 1.0;
	float dirt_amount = m.g;
	vec3 grass = texture(grass_tex, UV).rgb;
	vec3 dirt = texture(dirt_tex, wp / dirt_px).rgb;
	vec3 sand = texture(sand_tex, wp / sand_px).rgb;
	vec2 wuv = wp / water_px + vec2(TIME * 0.012, TIME * 0.006);
	vec3 water = texture(water_tex, wuv).rgb;

	// Grass brightness roughens the coastline and the edges of bare-soil patches.
	float jitter = (grass.g - 0.35) * 0.35;
	float is_soil = smoothstep(0.62, 0.66, dirt_amount + jitter * 0.25);
	vec3 ground = mix(grass, dirt, is_soil);
	ground = mix(ground, ground * 0.85, smoothstep(0.58, 0.64, dirt_amount + jitter * 0.25) * (1.0 - is_soil)); // darkened grass fringe

	float land = step(0.0, v + jitter * 0.06);
	float is_inland = step(0.1, v + jitter * 0.06);
	vec3 col = mix(sand, ground, is_inland);
	col = mix(col, col * 0.8, 1.0 - smoothstep(0.0, 0.035, v));      // wet sand at the waterline
	float foam = smoothstep(-0.07, 0.0, v) * (1.0 - land);             // light surf in the shallows
	water = mix(water, vec3(0.92, 0.98, 1.0), foam * 0.7);
	COLOR = vec4(mix(water, col, land), 1.0);
}
