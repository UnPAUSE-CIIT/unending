package main

import "core:fmt"
import "core:log"
import "core:unicode/utf8"
import "core:path/filepath"
import "core:os"
import rl "vendor:raylib"

textures: map[cstring]rl.Texture2D
fonts: map[cstring]rl.Font
sounds: map[cstring]rl.Sound

res :: proc(folder: string, file: string) -> cstring {
	return fmt.ctprintf("assets/{}/{}", folder, file)
}

trim_fname :: proc(fname: string) -> cstring {
	return to_cstr_alloc(filepath.stem(fname))
}

open_dir :: proc(path: string) -> (fh: os.Handle, fi: []os.File_Info) {
	dir_h, h_err := os.open(path)
	if h_err != nil {
		log.error("failed to open dir:", h_err)
		return os.INVALID_HANDLE, {}
	}

	entries, err := os.read_dir(dir_h, -1, allocator = context.temp_allocator)
	if err != nil {
		log.error("failed to read dir:", err)
		return os.INVALID_HANDLE, {}
	}

	return dir_h, entries
}

load_resources :: proc() -> bool {
	// load all fonts in /fonts
	{
		fonts_h, fonts := open_dir("assets/fonts")
		defer os.close(fonts_h)
		defer delete(fonts, context.temp_allocator)

		if fonts_h == os.INVALID_HANDLE {
			return false
		}

		for font in fonts {
			load_font(font.name)
		}
	}
	// load all textures in /images
	{
		textures_h, textures := open_dir("assets/images")
		defer os.close(textures_h)
		defer delete(textures, context.temp_allocator)

		if textures_h == os.INVALID_HANDLE {
			return false
		}

		for texture in textures {
			load_texture(texture.name)
		}
	}

	// load all sounds in /sounds
	{
		sounds_h, sounds := open_dir("assets/sounds")
		defer os.close(sounds_h)
		defer delete(sounds, context.temp_allocator)

		if sounds_h == os.INVALID_HANDLE {
			return false
		}

		for sound in sounds {
			load_sound(sound.name)
		}
	}

	return true
}

load_texture :: proc(image_name: string) {
	tex := rl.LoadTexture(res("images", image_name))
	textures[trim_fname(image_name)] = tex
}

load_font :: proc(font_name: string, font_size: i32 = 64) {
	f := rl.LoadFontEx(res("fonts", font_name), font_size, raw_data(runes), i32(len(runes)))
	rl.SetTextureFilter(f.texture, .TRILINEAR)

	fonts[trim_fname(font_name)] = f
}

load_sound :: proc(sound_name: string) {
	s := rl.LoadSound(res("sounds", sound_name))

	sounds[trim_fname(sound_name)] = s
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
	runes = nil
}
