package main

Rect :: struct {
	min: V2f,
	max: V2f,
}

rect_cut_left :: proc( r: ^Rect, a: f32 ) -> Rect {
	min_x := r.min.x
	r.min.x = min( r.max.x, r.min.x + a )

	return { { min_x, r.min.y }, { r.min.x, r.max.y } }
}

rect_cut_right :: proc( r: ^Rect, a: f32 ) -> Rect {
	max_x := r.max.x
	r.max.x = max( r.min.x, r.max.x - a )
	return { { r.max.x, r.min.y }, { max_x, r.max.y } }
}

rect_cut_top :: proc( r: ^Rect, a: f32 ) -> Rect {
	min_y := r.min.y
	r.min.y = min( r.max.x, r.min.x + a )

	return { { r.min.x, min_y }, { r.max.x, r.min.y } }
}

rect_cut_bottom :: proc( r: ^Rect, a: f32 ) -> Rect {
	max_y := r.max.y
	r.max.y = max( r.min.y, r.max.y - a )
	return { { r.min.x, r.max.y }, { r.max.x, max_y } }
}


