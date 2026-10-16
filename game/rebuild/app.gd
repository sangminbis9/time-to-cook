extends Node
const Session = preload("res://rebuild/session.gd")
const Presentation = preload("res://rebuild/presentation.gd")
const Audio = preload("res://rebuild/audio.gd")
var session
var view
var audio
var ui: Control
var hud: Control
var panel: PanelContainer
var content: VBoxContainer
var hud_text: Label
var orders: Label
var inventory_label: Label
var inventory_slots: Array = []
var orders_paper: NinePatchRect
var toast: Label
var tutorial_label: Label
var phase_button: Button
var theme: Theme
var panel_id: String = ""
var selected_character: int = 0
var selected_slot: int = 1
var screen: String = "title"
var toast_time: float = 0
var refresh_time: float = 0
var input_time: float = 0
var last_phase: String = ""
var last_location: String = ""
var fridge_open: String = ""
var build_kind: String = ""
var move_id: String = ""
var removing: bool = false
var rebind_action: String = ""
var settings: Dictionary = {"music":.5,"effects":.7,"fullscreen":false,"colorblind":false,"font_size":12,"keys":{"up":87,"down":83,"left":65,"right":68,"interact":74,"work":75,"drop":81,"skill":76}}
var tutorial_step: int = 0
var capture_frames: int = 0
const TUTORIAL = ["① 준비 · 경영 → 발주에서 생닭·튀김옷·용기를 주문하세요.","② 준비 완료 → WASD 이동 / 재료함 앞 J로 생닭을 집으세요.","③ 도마 앞 J 배치 → K를 눌러 칼질 → J 회수", "④ 튀김옷 앞 J 배치 → K → J 회수", "⑤ 튀김기에 J → 8초 뒤 황금색일 때 J 회수", "⑥ 담기 설비에 J → K → J 회수 (용기 1개 소모)", "⑦ 식탁·계산대 J 주문 접수 / 완성 요리를 들고 J 서빙", "⑧ 식사 뒤 K로 청소 · M 경영 / L 능력 / Q 내려놓기"]

func _ready() -> void:
	var locale=Translation.new();locale.locale="ko"
	var messages=JSON.parse_string(FileAccess.get_file_as_string("res://rebuild/data/locale_ko.json"))
	if messages is Dictionary:
		for key in messages:locale.add_message(key,messages[key])
	TranslationServer.add_translation(locale);TranslationServer.set_locale("ko")
	load_settings();configure_input();build_theme()
	session=Session.new();session.name="Session";add_child(session)
	view=Presentation.new();view.session=session;view.colorblind=settings.colorblind;add_child(view)
	audio=Audio.new();add_child(audio);audio.volume("Music",settings.music);audio.volume("Effects",settings.effects);audio.set_phase("prep")
	var layer=CanvasLayer.new();add_child(layer)
	ui=Control.new();ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.theme=theme;ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(ui)
	session.message.connect(show_toast);session.effect.connect(audio.play);session.changed.connect(on_changed)
	show_title()
	var args=OS.get_cmdline_user_args()
	if "--capture-game" in args:
		session.save_root="user://capture_fixtures"
		session.start(0,3)
		for ingredient in ["chicken","flour","box"]:session.send("buy_stock",{"ingredient":ingredient,"qty":20})
		for job in ["전처리","조리","서빙","청소"]:
			session.send("hire",{"job":job})
			for employee in session.world.state.staff:employee.leave=[];employee.illness_count=1;employee.absence_count=1
		session.world.start_day()
		for i in range(900):session.world.step()
		show_game();capture_frames=30
	elif "--capture-title" in args:capture_frames=30

func build_theme() -> void:
	theme=Theme.new();theme.default_font=load("res://assets/fonts/Galmuri11.ttf");theme.default_font_size=int(settings.font_size)
	for type in ["Label","Button","CheckButton","LineEdit","OptionButton"]:theme.set_color("font_color",type,Color("453d3c"))
	for state in ["normal","hover","pressed","focus","disabled"]:
		var box=pixel_box({"normal":"ui_button","hover":"ui_hover","pressed":"ui_pressed","focus":"ui_hover","disabled":"ui_disabled"}[state],6,7,4)
		theme.set_stylebox(state,"Button",box);theme.set_stylebox(state,"OptionButton",box)
		theme.set_color("font_hover_color","Button",Color("fff0cc"));theme.set_color("font_pressed_color","Button",Color("fff0cc"))
	theme.set_stylebox("panel","PanelContainer",pixel_box("ui_panel",8,10,10))
	theme.set_stylebox("normal","LineEdit",pixel_box("ui_button",6,7,5))
	theme.set_stylebox("focus","LineEdit",pixel_box("ui_slot_selected",6,7,5))

func pixel_box(asset: String,edge: int,horizontal: int,vertical: int) -> StyleBoxTexture:
	var box=StyleBoxTexture.new();box.texture=load("res://rebuild/assets/jp/%s.png"%asset)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:box.set_texture_margin(side,edge)
	box.content_margin_left=horizontal;box.content_margin_right=horizontal;box.content_margin_top=vertical;box.content_margin_bottom=vertical
	return box

func skin(asset: String,point: Vector2,dimensions: Vector2,parent: Node,edge: int=7) -> NinePatchRect:
	var node=NinePatchRect.new();node.texture=load("res://rebuild/assets/jp/%s.png"%asset);node.position=point;node.size=dimensions;node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.patch_margin_left=edge;node.patch_margin_right=edge;node.patch_margin_top=edge;node.patch_margin_bottom=edge;parent.add_child(node);return node

func configure_input() -> void:
	for action in settings.keys:
		if not InputMap.has_action(action):InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event=InputEventKey.new();event.physical_keycode=int(settings.keys[action]);InputMap.action_add_event(action,event)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func load_settings() -> void:
	var cfg=ConfigFile.new()
	if cfg.load("user://settings_v2.cfg")==OK:
		for key in settings:settings[key]=cfg.get_value("game",key,settings[key])

func save_settings() -> void:
	var cfg=ConfigFile.new()
	for key in settings:cfg.set_value("game",key,settings[key])
	cfg.save("user://settings_v2.cfg")

func clear_ui() -> void:
	for child in ui.get_children():ui.remove_child(child);child.queue_free()
	panel=null;hud=null;toast=null;panel_id="";hud_text=null;orders=null;inventory_label=null;tutorial_label=null;inventory_slots.clear();orders_paper=null

func label(text: String,parent: Node,size: int=0) -> Label:
	var node=Label.new();node.text=tr(text)
	if size>0:node.add_theme_font_size_override("font_size",size)
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(node);return node

func button(text: String,parent: Node,callback: Callable,width: float=0) -> Button:
	var node=Button.new();node.text=tr(text);node.custom_minimum_size=Vector2(width,25);node.pressed.connect(func():audio.play("click");callback.call());parent.add_child(node);return node

func row(parent: Node) -> HBoxContainer:
	var r=HBoxContainer.new();r.add_theme_constant_override("separation",6);parent.add_child(r);return r

func note(text: String) -> void:
	var l=label(text,content,11);l.add_theme_color_override("font_color",Color("826b53"))

func separator() -> void:content.add_child(HSeparator.new())

func show_title() -> void:
	screen="title";clear_ui()
	var art=TextureRect.new();art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.texture=load("res://rebuild/assets/jp/title.png");art.position=Vector2.ZERO;art.size=Vector2(640,360);art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;ui.add_child(art)
	var box=VBoxContainer.new();box.position=Vector2(29,26);box.size=Vector2(207,296);box.add_theme_constant_override("separation",5);ui.add_child(box)
	var logo=label("TIME TO\nCOOK",box,34);logo.add_theme_color_override("font_color",Color("fff0cc"));logo.add_theme_color_override("font_shadow_color",Color("222e42"));logo.add_theme_constant_override("shadow_offset_x",2);logo.add_theme_constant_override("shadow_offset_y",2)
	var subtitle=label("작은 주방에서, 넓은 세상으로",box,11);subtitle.add_theme_color_override("font_color",Color("fff0cc"));subtitle.add_theme_color_override("font_shadow_color",Color("222e42"));subtitle.add_theme_constant_override("shadow_offset_y",1)
	button("새로운 식탁",box,func():show_saves(true))
	button("이어하기",box,func():show_saves(false))
	button("온라인 협동 참가",box,show_join)
	button("환경 설정",box,func():open_panel("settings"))
	button("크레딧",box,func():open_panel("credits"))
	button("종료",box,func():get_tree().quit())
	var version=label("한국 · 일본  |  1–2인 식당 이야기",ui,10);version.position=Vector2(349,337);version.size=Vector2(280,18);version.add_theme_color_override("font_color",Color("fff0cc"));version.add_theme_color_override("font_shadow_color",Color("222e42"));version.add_theme_constant_override("shadow_offset_y",1)
	make_toast()

func make_toast() -> void:
	toast=Label.new();toast.position=Vector2(35,287);toast.size=Vector2(570,28);toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;toast.add_theme_color_override("font_color",Color("fff4db"));toast.add_theme_color_override("font_shadow_color",Color("5a4632"));toast.add_theme_constant_override("shadow_offset_x",1);toast.add_theme_constant_override("shadow_offset_y",1);ui.add_child(toast)

func show_toast(text: String) -> void:
	if toast==null:make_toast()
	toast.text=text;toast_time=4.0;toast.move_to_front()

func show_saves(new: bool) -> void:
	create_panel("새 게임 · 빈 슬롯 선택" if new else "저장된 식탁", "saves")
	for slot in range(1,4):
		var data=session.read_save("%s/slot_%d.json"%[session.save_root,slot])
		var r=row(content);label("슬롯 %d · %s"%[slot,"비어 있음" if data.is_empty() else "%d일 / %d원"%[data.day,data.cash]],r)
		if new:
			if data.is_empty():button("새로 시작",r,func():selected_slot=slot;show_characters())
			else:button("덮어쓰기…",r,func():confirm_overwrite(slot))
		else:
			var b=button("불러오기",r,func():if session.load_slot(slot):show_game())
			b.disabled=data.is_empty()
		if not data.is_empty():button("삭제…",r,func():confirm_delete(slot))
	note("새 세이브는 franchise_v2에 저장됩니다. 이전 게임의 저장은 변경하지 않습니다.")

func confirm_overwrite(slot: int) -> void:
	create_panel("슬롯 %d의 진행을 새 게임으로 교체할까요?"%slot,"overwrite")
	note("기존 저장의 .bak 백업은 남지만, 이 슬롯의 현재 진행은 교체됩니다.")
	button("교체 확인 · 캐릭터 선택",content,func():selected_slot=slot;show_characters())
	button("취소",content,func():show_saves(true))

func confirm_delete(slot: int) -> void:
	create_panel("슬롯 %d 삭제 확인"%slot,"delete")
	note("이 슬롯의 현재 저장과 백업이 삭제됩니다. 삭제한 진행은 복구할 수 없습니다.")
	button("최종 확인 · 슬롯 삭제",content,func():show_toast("삭제 완료" if session.delete_slot(slot) else "삭제 실패");show_saves(false))
	button("취소",content,func():show_saves(false))

func show_characters() -> void:
	create_panel("나의 요리사 · 저장 후 변경 불가","characters")
	var names=["하나 · 전처리 15% 빠름","준 · 조리 능력","보리 · 가방 4칸 / 이동 10%","소라 · 시장 분석 능력"]
	for i in range(4):
		var r=row(content);var icon=TextureRect.new();icon.texture=AtlasTexture.new();icon.texture.atlas=load("res://rebuild/assets/jp/person_%d.png"%i);icon.texture.region=Rect2(0,0,32,40);r.add_child(icon)
		button(names[i],r,func():session.start(i,selected_slot);show_game(),330)
	note("모든 캐릭터가 모든 일을 할 수 있습니다. L: 10초 능력 / 재사용 60초.")

func show_join() -> void:
	create_panel("온라인 2인 협동 · 호스트 주소","join")
	var address=LineEdit.new();address.placeholder_text="예: 192.168.0.10";address.text="127.0.0.1";content.add_child(address)
	var choices=OptionButton.new()
	for name in ["하나","준","보리","소라"]:choices.add_item(name)
	choices.selected=1;content.add_child(choices)
	button("참가",content,func():var error=session.join(address.text.strip_edges(),choices.selected);show_toast("접속 중…" if error==OK else "연결 시작 실패: %s"%error))
	note("호스트와 다른 캐릭터를 선택하세요. UDP 7777 직접 연결을 사용합니다. 같은 LAN 또는 호스트의 포트포워딩이 필요하며 자동 중계는 제공하지 않습니다.")

func show_game() -> void:
	screen="game";clear_ui();hud=Control.new();hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(hud)
	skin("ui_hud",Vector2.ZERO,Vector2(640,45),hud)
	hud_text=label("",hud,12);hud_text.position=Vector2(12,5);hud_text.size=Vector2(444,36)
	var manage=button("경영 M",hud,func():open_panel("stock"));manage.position=Vector2(466,9)
	phase_button=button("준비 완료",hud,func():session.send("next_day" if session.world.state.phase=="settlement" else "ready"));phase_button.position=Vector2(540,9)
	skin("ui_hud",Vector2(0,306),Vector2(640,54),hud)
	for i in range(10):
		var slot=skin("ui_slot",Vector2(10+i*29,311),Vector2(27,27),hud,5)
		var icon=TextureRect.new();icon.position=Vector2(3,3);icon.size=Vector2(21,21);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;slot.add_child(icon)
		var number=label(str((i+1)%10),slot,8);number.position=Vector2(2,0);number.size=Vector2(10,10)
		inventory_slots.append({"slot":slot,"icon":icon,"number":number})
	inventory_label=label("",hud,10);inventory_label.position=Vector2(310,312);inventory_label.size=Vector2(320,28)
	tutorial_label=label("",hud,10);tutorial_label.position=Vector2(10,341);tutorial_label.size=Vector2(590,17)
	button("›",hud,func():tutorial_step=(tutorial_step+1)%TUTORIAL.size()).position=Vector2(605,335)
	orders_paper=skin("ui_ticket",Vector2(479,51),Vector2(156,92),hud,9)
	orders=label("",hud,10);orders.position=Vector2(490,61);orders.size=Vector2(132,220)
	make_toast();last_phase="";last_location="";fridge_open="";update_hud()

func create_panel(title: String,id: String) -> void:
	if panel!=null:ui.remove_child(panel);panel.queue_free()
	panel_id=id;panel=PanelContainer.new();panel.position=Vector2(24,49);panel.size=Vector2(592,258);ui.add_child(panel)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",6);panel.add_child(box)
	var header=row(box);label(title,header,16);button("닫기 Esc",header,close_panel)
	if screen=="game" and id not in ["settings","credits","fridge","settlement","help"]:
		var tabs_scroll=ScrollContainer.new();tabs_scroll.custom_minimum_size.y=31;tabs_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;box.add_child(tabs_scroll)
		var tabs=row(tabs_scroll)
		for entry in [["stock","발주"],["staff","직원"],["build","건설"],["cars","차량"],["research","연구"],["city","도시"],["finance","금융"],["menu","운영"],["skills","성장"],["log","기록"],["settings","설정"]]:
			button(entry[1],tabs,func():open_panel(entry[0]))
	var scroll=ScrollContainer.new();scroll.custom_minimum_size.y=158;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;box.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",7);scroll.add_child(content)

func close_panel() -> void:
	if panel_id=="fridge":session.send("close_fridge");fridge_open=""
	if panel!=null:ui.remove_child(panel);panel.queue_free();panel=null
	panel_id=""

func act(action: String,args: Dictionary={}) -> void:
	session.send(action,args)
	if screen=="game" and panel_id!="":call_deferred("open_panel",panel_id)

func open_panel(id: String) -> void:
	if id=="settings":settings_panel();return
	if id=="credits":credits_panel();return
	if session.world.state.is_empty():return
	var w=session.world;var st=w.state;var p=w.player(session.local_id())
	if p.is_empty():return
	var s=w.store_of(p)
	match id:
		"stock":
			create_panel("식재료 · 오늘의 발주","stock")
			note("준비 단계 도매 발주 · 마감 시 일반 재고는 폐기됩니다. 냉장고의 가열 전 재료만 보존됩니다.")
			for ing in w.db.all("ingredients"):
				var r=row(content);label("%s · %d개 / 개당 %s원"%[ing.name,s.stock[ing.id],str(w.unit_price(s.id,ing.id)) if session.authority() else "호스트 기준"],r)
				button("+10",r,func():act("buy_stock",{"ingredient":ing.id,"qty":10}));button("+1",r,func():act("buy_stock",{"ingredient":ing.id,"qty":1}))
			if "auto_order" in st.research:
				var r=row(content);label("자동 발주 목표: %d개"%s.auto_order,r);button("0",r,func():act("auto_order",{"qty":0}));button("20",r,func():act("auto_order",{"qty":20}));button("40",r,func():act("auto_order",{"qty":40}))
		"staff":staff_panel(w,st,s)
		"cars":
			create_panel("차고 · %d / %d 주차"%[s.vehicles.size(),s.parking],"cars")
			note("영업 중 뒷문 J → 차 앞 J → WASD 도로 주행 → 마트 J → 구매 → 귀환 J → 차 앞 J 하역")
			for car in s.vehicles:
				var r=row(content);label("보유: %s · 화물 %d/%d · 개선 %d단계"%[w.db.title("vehicles",car.kind),car.cargo.size(),w.cargo_capacity(car),car.get("upgrade",0)],r);button("판매 60%",r,func():act("vehicle_sell",{"id":car.id}))
				button("차량 개선 · 속도 +5% / 적재 +2 · %d원"%roundi(w.db.get_def("vehicles",car.kind).price*.15*(1+int(car.get("upgrade",0)))),content,func():act("vehicle_upgrade",{"id":car.id}))
			for car in w.db.all("vehicles"):
				var r=row(content);label("%s · %d원\n%.1f타일/s · %d개 · 왕복 %d원"%[car.name,car.price,car.speed,car.capacity,car.trip],r);button("구입",r,func():act("vehicle_buy",{"id":car.id}))
		"research":
			create_panel("연구소 · %d RP"%st.rp,"research")
			for def in w.db.all("research"):
				var r=row(content);label("%s · %d원 / %d RP\n선행: %s"%[def.name,def.cost,def.rp,"없음" if def.prerequisite=="" else w.db.title("research",def.prerequisite)],r)
				var b=button("완료" if def.id in st.research else "연구",r,func():act("research",{"id":def.id}));b.disabled=def.id in st.research
		"build":build_panel(w,s)
		"city":city_panel(w,st)
		"finance":
			create_panel("은행 · 신용 %d / 대출 %d건"%[st.credit,st.loans.size()],"finance")
			note("일일 이자는 원금을 줄이지 않습니다. 부분 상환 없이 전액 상환만 가능합니다.")
			for loan in st.loans:
				var r=row(content);label("%s · 만기 %d일\n전액 상환 %d원 / 연체 %d원"%[w.db.title("loans",loan.kind),loan.due,w.management.loan_balance(loan),loan.penalty],r);button("전액 상환",r,func():act("repay",{"id":loan.id}))
			for def in w.db.all("loans"):
				var r=row(content);label("%s · %d원 / %d일\n일 %.1f%% / 만기 %.1f%%"%[def.name,def.principal,def.term,def.rate*100,def.maturity*100],r);button("대출",r,func():act("loan",{"id":def.id}))
			button("오늘 영업 보험 · 1,200원 · 마감 미복구 손해 70% 보상",content,func():act("insurance"))
		"menu":
			create_panel("메뉴와 홍보 · 매장 운영","menu")
			for recipe in w.db.all("recipes"):
				if recipe.id!="fried" and recipe.id not in st.research:continue
				var r=row(content);label("%s · %d원"%[recipe.name,s.prices[recipe.id]],r)
				button("−100",r,func():act("price",{"recipe":recipe.id,"price":s.prices[recipe.id]-100}));button("+100",r,func():act("price",{"recipe":recipe.id,"price":s.prices[recipe.id]+100}));button("판매 중" if recipe.id in s.menu else "메뉴 추가",r,func():act("menu",{"recipe":recipe.id}))
			separator();note("광고는 방문 수요를 높입니다. 직원·재고·테이블 수용력을 먼저 확보하세요.")
			for i in range(4):button(["전단 · 2,000원 / 3일","SNS · 5,000원 / 5일","관광객 · 8,000원 / 5일","브랜드 · 15,000원 / 7일"][i],content,func():act("ad",{"tier":i}))
			button("매니저 우선순위: "+s.priority,content,func():act("priority"))
		"skills":
			create_panel("나의 성장 · %d RP / %d회 서빙"%[st.rp,p.xp],"skills")
			for kind in p.skills:
				var r=row(content);label("%s · Lv.%d / 5"%[{"prep":"전처리","cook":"조리","service":"서비스","move":"이동","clean":"청소","market":"시장 분석"}[kind],p.skills[kind]],r);button("연구 %d원 / %d RP"%[4000*(p.skills[kind]+1),3+p.skills[kind]*2],r,func():act("skill_upgrade",{"kind":kind}))
			button("가방 확장 · 현재 %d칸 / %d원"%[p.inventory.size(),3000*(p.inventory.size()-1)],content,func():act("inventory_upgrade"))
		"log":
			create_panel("프랜차이즈 기록","log")
			var r=row(content);button("저장",r,func():show_toast("저장 완료" if session.save(session.active_slot) else "호스트만 저장할 수 있습니다."));button("협동 호스트 열기",r,func():show_toast("호스트 시작" if session.host()==OK else "호스트 시작 실패 / 이미 실행 중"));button("도움말",r,func():open_panel("help"));button("타이틀로",r,func():session.save(session.active_slot);session.connected=false;session.stop_network();show_title())
			label("달성: "+", ".join(st.achievements),content)
			for entry in st.logs:label(entry,content,11)
		"fridge":fridge_panel(w,p,s)
		"retail":retail_panel(w,p,s)
		"settlement":
			create_panel("%d일의 식탁 · 하루 정산"%st.day,"settlement")
			var sum=st.summary
			if sum.is_empty():return
			label("매출 %d원 · 지출 %d원 · 순현금흐름 %d원"%[sum.revenue,sum.expense,sum.profit],content,16)
			label("완료 %d / 실패 %d / 폐기 %d / 연구 +%d RP"%[sum.served,sum.failed,sum.waste,2+int(sum.served/5)],content)
			for category in sum.ledger:label("%s   %d원"%[category,sum.ledger[category]],content)
			for e in st.staff:label("%s · 만족도 %.1f (%+.1f) · %s"%[e.name,e.satisfaction,e.last_delta,str(e.last_reasons)],content,11)
			button("다음 날 준비",content,func():session.send("next_day");close_panel())
		"help":
			create_panel("처음 오신 요리사에게","help")
			for instruction in TUTORIAL:label(instruction,content)
			note("숫자 1–9 / 휠: 슬롯 선택. 냉장고는 슬롯 클릭으로 교환, Shift+클릭으로 빈 가방 칸 이동. 레시피 변경은 HUD 아래 메뉴를 이용하세요. 영업과 경영 패널은 동시에 진행됩니다.")
			button("온라인 연결 안내",content,func():show_toast("UDP 7777 · IP 직접 참가 · 호스트 종료 시 세션 종료 / 기존 파트너 재접속 지원"))

func staff_panel(w,st: Dictionary,s: Dictionary) -> void:
	create_panel("직원 · 채용 / 계약 / 복리후생","staff")
	note("7일마다 후보 갱신 · 특성은 채용 후 공개 · 휴가와 결근에도 일급 전액 지급")
	for job in w.JOBS:
		var r=row(content);var e=st.candidates.get(job,{})
		label("%s · %s"%[job,"모집 대기" if e.is_empty() else "%s [%s] 속도 %.2f / 일급 %d / 채용 %d"%[e.name,e.grade,e.speed,e.wage,e.fee]],r,11)
		if not e.is_empty():button("채용",r,func():act("hire",{"job":job}))
		var count=int(st.refreshes.get(job,0));button("갱신 %s"%(str(2000*(1<<count)) if count<40 else "불가"),r,func():act("refresh",{"job":job}))
	separator()
	for e in st.staff:
		label("%s [%s] %s · %s · %.1f점 / 일급 %d"%[e.name,e.grade,e.job,w.db.title("cities",e.store),e.satisfaction,e.wage],content,13)
		note("%s | %s | 휴가 %s | 병가 복귀 %d일\n요구 %s / 관계 %s / 최근 원인 %s"%[", ".join(e.traits),e.state,str(e.leave),e.sick_until,str(e.requests),str(e.relationships),str(e.last_reasons)])
		var r=row(content)
		for i in range(3):button(["소액 포상","일반 포상","특별 포상"][i],r,func():act("bonus",{"id":e.id,"tier":i}))
		var penalty=roundi(maxi(0,int(e.contract)-(int(st.day)-int(e.hired)))*e.wage*.5)
		button("해고 %d원"%penalty,r,func():act("fire",{"id":e.id}))
		var schedule=row(content);var old=OptionButton.new();var next=OptionButton.new()
		for day in e.leave:old.add_item(str(day),int(day))
		for day in range(1,31):next.add_item(str(day),day)
		schedule.add_child(old);label("→",schedule);schedule.add_child(next);button("휴가 이동 · %d원"%e.wage,schedule,func():act("vacation",{"id":e.id,"from":old.get_selected_id(),"to":next.get_selected_id()}))
		var dest=OptionButton.new()
		for city in st.stores:dest.add_item(w.db.title("cities",city));dest.set_item_metadata(dest.item_count-1,city)
		schedule.add_child(dest);button("재배치",schedule,func():act("transfer",{"id":e.id,"city":dest.get_item_metadata(dest.selected)}))
		separator()

func build_panel(w,s: Dictionary) -> void:
	create_panel("공간을 가꾸기 · 준비 중 배치","build")
	note("구입 선택 → 빈 타일 클릭. R: 회전 / Esc: 취소. 통로와 출입구를 막으면 설치되지 않습니다.")
	var r=row(content);button("이동 도구",r,func():move_id="select";close_panel();show_toast("옮길 설비를 클릭한 뒤 새 위치를 클릭하세요."));button("철거 도구 · 40% 환급",r,func():removing=true;close_panel());button("바닥 교체 2,000",r,func():act("floor_style"));button("층 확장",r,func():act("floor_add"))
	var kinds=["board","batter","fryer","plate","bench","table","chair","fridge","counter","kiosk","plant","lamp","wall_block","extinguisher","generator","vent","drain","parking","elevator"]
	for def in w.db.all("welfare"):kinds.append(def.id)
	for kind in kinds:
		var line=row(content);var welfare=w.db.get_def("welfare",kind)
		var preview=TextureRect.new();preview.texture=view.textures.get(view.regional(kind,s.id));preview.custom_minimum_size=Vector2(28,28);preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;line.add_child(preview)
		label("%s · %d원"%[w.STATION_NAMES.get(kind,w.db.title("welfare",kind)),w.management.build_cost(kind)],line)
		if not welfare.is_empty():label("효과 +%.2f / 고정 %d / 이용 %d"%[welfare.effect,welfare.fixed,welfare.usage],line,10)
		button("배치",line,func():
			if kind=="parking":act("build",{"kind":kind})
			else:
				build_kind=kind;view.build_kind=kind;close_panel())
	for obj in s.objects:
		if obj.kind=="fridge":button("냉장고 %d칸 → +3칸 / 8,000원"%obj.slots.size(),content,func():act("fridge_upgrade",{"id":obj.id}))

func city_panel(w,st: Dictionary) -> void:
	create_panel("한국과 일본 · 16개 도시","city")
	var map=preload("res://rebuild/country_map.gd").new();map.owned=st.stores.keys();map.cities=w.db.all("cities");map.selected.connect(city_detail);content.add_child(map)
	note("도시 진출은 자유 선택입니다. 일본은 해외진출 연구와 브랜드 55점 이상이 필요합니다.")
	for city in w.db.all("cities"):
		label("%s  %s · 개설 %d / 임대 %d"%["대한민국" if city.country=="kr" else "일본",city.name,city.entry,city.rent],content,13)
		note("인테리어 · "+view.art.cities[city.id].name)
		var report=st.markets.get(city.id,{})
		if report.is_empty():note("시장 정보 미확보")
		else:note("%s · %d일 경과 · 수요 %.2f / 경쟁 %.2f / 민감도 %.2f / %s"%[report.source,int(st.day)-int(report.day),report.data.demand,report.data.competition,report.data.sensitivity,report.data.event])
		var r=row(content)
		if st.stores.has(city.id):
			var s=st.stores[city.id];label("평판 %.1f · 매출 %d · 닭 %d"%[s.reputation,s.revenue,s.stock.chicken],r,10);button("방문",r,func():act("visit",{"city":city.id});close_panel());button("폐점",r,func():confirm_close(city.id))
		else:button("진출",r,func():act("expand",{"city":city.id}))
		button("정보상 3천",r,func():act("market",{"city":city.id,"grade":1,"safe":false}));button("상세 1.4만",r,func():act("market",{"city":city.id,"grade":3,"safe":false}));button("자문 2.8만",r,func():act("market",{"city":city.id,"grade":3,"safe":true}))
		separator()

func city_detail(city: String) -> void:
	var w=session.world;var def=w.db.get_def("cities",city)
	create_panel(def.name+" · 도시 정보","city_detail")
	var design=view.art.cities[city]
	var samples=row(content)
	for kind in ["table","chair","bench","counter","fridge","door","plant","lamp"]:
		var icon=TextureRect.new();icon.texture=view.textures[design.props[kind]];icon.custom_minimum_size=Vector2(32,32);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;samples.add_child(icon)
	note("지역 인테리어 · "+design.name)
	note("개설 %d원 / 일 임대료 %d원 / 최대 %d층"%[def.entry,def.rent,def.floors])
	var report=w.state.markets.get(city,{})
	if report.is_empty():note("시장 정보 미확보")
	else:note("%d일 전 조사 · 수요 %.2f / 경쟁 %.2f / %s"%[int(w.state.day)-int(report.day),report.data.demand,report.data.competition,report.data.event])
	if w.state.stores.has(city):button("이 매장 방문",content,func():session.send("visit",{"city":city});close_panel())
	else:button("매장 열기",content,func():session.send("expand",{"city":city});city_detail(city))
	button("상세 자문 · 28,000원",content,func():session.send("market",{"city":city,"grade":3,"safe":true});city_detail(city))
	button("전체 지도",content,func():open_panel("city"))

func confirm_close(city: String) -> void:
	create_panel("매장 폐점 확인","confirm_close")
	note("부지 50%, 차량 60%를 환수하고 직원은 남은 매장으로 이동합니다. 30일 동안 이 도시에 재진출할 수 없습니다. 플레이어가 있으면 폐점할 수 없습니다.")
	button("폐점 실행",content,func():act("sell_store",{"city":city});open_panel("city"))

func fridge_panel(w,p: Dictionary,s: Dictionary) -> void:
	var obj=w.object_by(s,p.fridge)
	if obj.is_empty():close_panel();return
	create_panel("냉장고 · 가열 전 재료만 보존","fridge")
	note("선택한 가방 슬롯과 교환합니다. Shift+클릭: 빈 가방 칸으로 빠르게 꺼내기. 시계는 계속 흐릅니다.")
	for i in range(obj.slots.size()):
		var food=obj.slots[i]
		button("%d · %s"%[i+1,food_name(food)],content,func():act("fridge",{"slot":i,"fast":Input.is_key_pressed(KEY_SHIFT)}))

func retail_panel(w,p: Dictionary,s: Dictionary) -> void:
	create_panel("동네 마트 · 긴급 소매 구매","retail")
	var car=w.vehicle(s,p.vehicle)
	if car.is_empty():return
	note("적재 %d / %d · 매장 귀환 후 하역해야 재고에 반영됩니다."%[car.cargo.size(),w.cargo_capacity(car)])
	for ing in w.db.all("ingredients"):
		var r=row(content)
		var price=w.unit_price(s.id,ing.id,true) if session.authority() else int(s.get("retail_prices",{}).get(ing.id,0))
		label("%s · 재고 %d · %d원 (도매 3배)"%[ing.name,s.retail[ing.id],price],r)
		button("1개",r,func():act("retail_buy",{"ingredient":ing.id,"qty":1}));button("5개",r,func():act("retail_buy",{"ingredient":ing.id,"qty":5}))

func settings_panel() -> void:
	create_panel("환경 설정","settings")
	for key in ["music","effects"]:
		var r=row(content);label("음악" if key=="music" else "효과음",r)
		var slider=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=.05;slider.value=float(settings[key]);slider.custom_minimum_size.x=280;r.add_child(slider)
		slider.value_changed.connect(func(v):settings[key]=v;audio.volume("Music" if key=="music" else "Effects",v);save_settings())
	button("전체 화면: "+("켬" if settings.fullscreen else "끔"),content,func():settings.fullscreen=not settings.fullscreen;configure_input();save_settings();settings_panel())
	button("색약 대응 파란 강조: "+("켬" if settings.colorblind else "끔"),content,func():settings.colorblind=not settings.colorblind;view.colorblind=settings.colorblind;save_settings();settings_panel())
	var r=row(content);label("글자 배율",r)
	for size in [11,12,14]:button(str(size),r,func():settings.font_size=size;build_theme();ui.theme=theme;save_settings();settings_panel())
	note("화면 흔들림은 사용하지 않습니다. 키 버튼을 누르고 원하는 키로 변경하세요.")
	for key in settings.keys:
		button("%s : %s"%[{"up":"위","down":"아래","left":"왼쪽","right":"오른쪽","interact":"상호작용","work":"작업","drop":"내려놓기","skill":"능력"}[key],OS.get_keycode_string(settings.keys[key])],content,func():rebind_action=key;show_toast("새 키를 누르세요. Esc는 취소합니다."))

func credits_panel() -> void:
	create_panel("TIME TO COOK · 크레딧","credits")
	label("기획: PLAN.md · 개발: Codex\n게임 엔진: Godot 4.7 (MIT)\n한글 폰트: Galmuri (SIL Open Font License)\n음악·효과음: 원본 절차적 합성\n타이틀·도트 원화: OpenAI 이미지 생성 도구\n스프라이트: 원화 슬라이싱·픽셀 격자 정리 / 16개 도시 가구",content)
	note("Steamworks 연동·업로드·출시 승인은 포함되지 않습니다. 라이선스 전문은 배포 폴더 LICENSES를 확인하세요.")

func on_changed() -> void:
	if session.connected and screen=="title" and session.online and not session.multiplayer.is_server():show_game()
	if screen=="game":
		update_hud()
		if not session.authority() and panel_id not in ["","settings","credits","help"]:call_deferred("open_panel",panel_id)

func food_name(food) -> String:
	if food==null:return "빈 칸"
	return {"raw":"생닭","cut":"칼질 닭","prepared":"튀김옷 닭","undercooked":"덜 익음","normal":"정상 튀김","overcooked":"과조리","burnt":"탐"}.get(food.stage,session.world.db.title("recipes",food.stage))

func update_hud() -> void:
	if hud_text==null or session.world.state.is_empty():return
	var w=session.world;var st=w.state;var p=w.player(session.local_id())
	if p.is_empty():return
	var s=w.store_of(p);var minute=540+int(float(st.tick)/20)
	phase_button.text="다음 날" if st.phase=="settlement" else ("영업 중" if st.phase in ["business","closing"] else ("준비 취소" if st.ready.get(session.local_id(),false) else "준비 완료"))
	phase_button.disabled=st.phase in ["business","closing"] or (st.phase=="settlement" and not session.authority())
	var phase={"prep":"준비","business":"영업","closing":"추가 마감","settlement":"정산"}[st.phase]
	hud_text.text="%d월 %d일  %02d:%02d  %s · %s %d층\n공용 %d원  브랜드 %.1f  매장 %.1f  RP %d"%[int((int(st.day)-1)/30)+1,(int(st.day)-1)%30+1,int(minute/60),minute%60,phase,w.db.title("cities",s.id),int(p.floor)+1,st.cash,st.brand,s.reputation,st.rp]
	for i in range(inventory_slots.size()):
		var widgets=inventory_slots[i];widgets.slot.visible=i<p.inventory.size()
		if i>=p.inventory.size():continue
		widgets.slot.texture=view.textures["ui_slot_selected" if i==int(p.slot) else "ui_slot"]
		var item=p.inventory[i]
		widgets.icon.texture=null if item==null else view.textures.get("food_"+item.stage)
	inventory_label.text="%d · %s   J 상호작용 / K 작업\nTab 메뉴: %s"%[int(p.slot)+1,food_name(p.inventory[int(p.slot)]),w.db.title("recipes",p.recipe)]
	tutorial_label.text=TUTORIAL[tutorial_step] if p.location=="store" else {"parking":"WASD 이동 · J 탑승 / 화물 하역 / 주방 출입","road":"WASD 운전 · 오른쪽 마트 90타일 / 왼쪽 식당 · 끝 주차 구역에서 J","retail":"진열대에 다가가 B 장보기 · 아래 출구에서 J 차량으로"}.get(p.location,"")
	var tickets=[]
	for c in s.customers:
		if c.state=="ordered":tickets.append("%s %s\n%d초 · %d원"%["포장" if c.type=="takeout" else "홀",w.db.title("recipes",c.recipe),int(c.timer),c.price])
	orders.text="\n".join(tickets.slice(0,6))
	if p.location=="road":
		var car=w.vehicle(s,p.vehicle)
		if not car.is_empty():orders.text="%s\n적재 %d / %d\n마트까지 %d타일"%[w.db.title("vehicles",car.kind),car.cargo.size(),w.cargo_capacity(car),maxi(0,int((2880-car.x)/32))]
	orders_paper.visible=orders.text!=""
	orders_paper.size.y=clampf(orders.get_minimum_size().y+24,60,240)
	audio.set_phase(st.phase)
	if last_phase!=st.phase:
		last_phase=st.phase
		if st.phase=="settlement":open_panel("settlement")
	if p.fridge!="" and p.fridge!=fridge_open:fridge_open=p.fridge;open_panel("fridge")
	elif p.fridge=="" and fridge_open!="":fridge_open="";close_panel()
	last_location=p.location

func _process(delta: float) -> void:
	if toast!=null:
		toast_time-=delta;toast.visible=toast_time>0
	if screen!="game":
		capture_if_requested();return
	refresh_time+=delta;input_time+=delta
	if refresh_time>=.2:refresh_time=0;update_hud()
	if input_time>=.05 and session.connected:
		input_time=0
		var blocked=panel!=null
		var direction=Vector2.ZERO if blocked else Input.get_vector("left","right","up","down")
		session.send("input",{"x":direction.x,"y":direction.y,"work":not blocked and Input.is_action_pressed("work")})
	capture_if_requested()

func capture_if_requested() -> void:
	if capture_frames>0:
		capture_frames-=1
		if capture_frames==0:
			await RenderingServer.frame_post_draw
			var capture_dir=OS.get_environment("TTC_CAPTURE_DIR")
			if capture_dir=="":capture_dir=ProjectSettings.globalize_path("res://../release")
			get_viewport().get_texture().get_image().save_png(capture_dir.path_join("%s.png"%("gameplay" if screen=="game" else "title")))
			get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if rebind_action!="" and event is InputEventKey and event.pressed:
		if event.physical_keycode!=KEY_ESCAPE:settings.keys[rebind_action]=event.physical_keycode;configure_input();save_settings()
		rebind_action="";settings_panel();return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			if build_kind!="" or move_id!="" or removing:build_kind="";view.build_kind="";move_id="";removing=false
			elif panel!=null:close_panel()
			elif screen=="game":open_panel("log")
			return
		if screen!="game":return
		if event.physical_keycode==KEY_M:open_panel("stock");return
		if event.physical_keycode==KEY_B:
			if session.world.player(session.local_id()).location=="retail":open_panel("retail")
			else:open_panel("build")
			return
		if event.physical_keycode==KEY_R and build_kind!="":view.build_rotation=(view.build_rotation+1)%4;return
		if event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_9:session.send("slot",{"slot":event.physical_keycode-KEY_1});return
		if event.physical_keycode==KEY_0:session.send("slot",{"slot":9});return
		if event.physical_keycode==KEY_TAB:
			var p=session.world.player(session.local_id());var menu=session.world.store_of(p).menu;var next=(menu.find(p.recipe)+1)%menu.size();session.send("recipe_select",{"recipe":menu[next]});show_toast("담을 메뉴: "+session.world.db.title("recipes",menu[next]));return
	if screen!="game" or panel!=null:return
	if event.is_action_pressed("interact"):session.send("interact")
	if event.is_action_pressed("drop"):session.send("drop")
	if event.is_action_pressed("skill"):session.send("skill")
	if event is InputEventMouseButton and event.pressed:
		var p=session.world.player(session.local_id())
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:session.send("slot",{"slot":posmod(int(p.slot)+(1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1),p.inventory.size())})
		if event.button_index==MOUSE_BUTTON_LEFT:
			var cell=view.screen_to_tile(event.position)
			if build_kind!="":session.send("build",{"kind":build_kind,"x":cell.x,"y":cell.y,"rotation":view.build_rotation});return
			var s=session.world.store_of(p)
			if removing or move_id=="select":
				for obj in s.objects:
					if int(obj.floor)==int(p.floor) and int(obj.x)==cell.x and int(obj.y)==cell.y:
						if removing:session.send("remove",{"id":obj.id})
						else:move_id=obj.id;show_toast("새 위치를 클릭하세요.")
						return
			elif move_id!="":session.send("move_object",{"id":move_id,"x":cell.x,"y":cell.y});move_id=""
