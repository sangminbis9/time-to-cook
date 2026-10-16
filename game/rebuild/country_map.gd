extends Control
signal selected(city: String)
var owned: Array=[]
var font=preload("res://assets/fonts/Galmuri11.ttf")
var background=preload("res://rebuild/assets/jp/country_map.png")
var marker=preload("res://rebuild/assets/jp/ui_coin.png")
const POINTS={"incheon":Vector2(116,69),"seoul":Vector2(151,54),"daejeon":Vector2(149,91),"daegu":Vector2(181,110),"gwangju":Vector2(122,133),"busan":Vector2(181,143),"ulsan":Vector2(205,124),"jeju":Vector2(122,183),"fukuoka":Vector2(286,155),"kobe":Vector2(348,125),"osaka":Vector2(369,146),"kyoto":Vector2(377,109),"nagoya":Vector2(404,123),"yokohama":Vector2(435,130),"tokyo":Vector2(449,103),"sapporo":Vector2(485,43)}
var cities: Array=[]
const LABEL_OFFSETS={"kobe":Vector2(-28,18),"osaka":Vector2(-10,19),"kyoto":Vector2(-22,-12),"nagoya":Vector2(-8,-15),"yokohama":Vector2(8,16),"tokyo":Vector2(10,-2)}

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;custom_minimum_size=Vector2(550,160);mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND

func marker_position(city: String) -> Vector2:
	return Vector2(POINTS[city].x,POINTS[city].y*160.0/210.0).round()

func _draw() -> void:
	draw_texture_rect(background,Rect2(0,0,550,160),false)
	for city in cities:
		var point=marker_position(city.id)
		draw_texture_rect(marker,Rect2(point-Vector2(5,5),Vector2(10,10)),false,Color.WHITE if city.id in owned else Color(.75,.85,.9))
		var caption=point+LABEL_OFFSETS.get(city.id,Vector2(7,4))
		draw_string(font,caption+Vector2.DOWN,city.name,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("263d43"))
		draw_string(font,caption,city.name,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("fff0cc"))
	draw_string(font,Vector2(12,153),"도시 선택 · 금빛 표시는 우리 매장",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("fff0cc"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var best="";var distance=30.0
		for city in POINTS:
			var d=event.position.distance_to(marker_position(city))
			if d<distance:best=city;distance=d
		if best!="":selected.emit(best)
