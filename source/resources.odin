package main

import "core:fmt"
import "core:log"
import "core:unicode/utf8"
import rl "vendor:raylib"

textures: map[cstring]rl.Texture2D
fonts: map[cstring]rl.Font

res :: proc(path: cstring, prefix: cstring = "") -> cstring {
	return fmt.ctprintf("assets/{}{}", path, prefix)
}

load_texture :: proc(image_name: cstring) {
	tex := rl.LoadTexture(res(image_name, ".png"))
	textures[image_name] = tex
}

@(private = "file")
runes := utf8.string_to_runes(
	" !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~—–",
)
load_font :: proc(font_name: cstring, font_size: i32 = 64) {

	log.info("load font")
	f := rl.LoadFontEx(res(font_name, ".ttf"), font_size, raw_data(runes), i32(len(runes)))
	rl.SetTextureFilter(f.texture, .TRILINEAR)

	fonts[font_name] = f
}

free_resources :: proc() {
	for name, &tex in textures {
		log.info("[res] releasing texture:", name)
		rl.UnloadTexture(tex)
	}

	for name, &font in fonts {
		log.info("[res] releasing texture:", name)
		rl.UnloadFont(font)
	}
}
