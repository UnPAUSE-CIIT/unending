package main

import "core:fmt"
import "core:unicode/utf8"
import rl "vendor:raylib"

textures: map[cstring]rl.Texture2D
fonts: map[cstring]rl.Font
sounds: map[cstring]rl.Sound

res :: proc(path: cstring, prefix: cstring = "") -> cstring {
	return fmt.ctprintf("assets/{}{}", path, prefix)
}

load_texture :: proc(image_name: cstring) {
	tex := rl.LoadTexture(res(image_name, ".png"))
	textures[image_name] = tex
}

load_font :: proc(font_name: cstring, font_size: i32 = 64) {
	f := rl.LoadFontEx(res(font_name, ".ttf"), font_size, raw_data(runes), i32(len(runes)))
	rl.SetTextureFilter(f.texture, .TRILINEAR)

	fonts[font_name] = f
}

load_sound :: proc(sound_name: cstring) {
	s := rl.LoadSound(res(sound_name, ".wav"))

	sounds[sound_name] = s
}

@(private = "file")
runes: []rune 
init_resources:: proc() {
	runes = utf8.string_to_runes(
		" !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~—–",
	)
}

free_resources :: proc() {
	for _, &tex in textures {
		rl.UnloadTexture(tex)
	}

	for _, &font in fonts {
		rl.UnloadFont(font)
	}

	for _, &sound in sounds {
		rl.UnloadSound(sound)
	}
}
