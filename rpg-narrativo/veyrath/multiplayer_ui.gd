extends VBoxContainer
## Credentials and session stay in memory. This UI never reads the solo campaign.
const ENDPOINT := "https://plnevlfefgfdcjqlamyh.supabase.co"
const PUBLISHABLE_KEY := "sb_publishable_d8NzCYYHMJRfB-p-94W0sg_PSZmtR4N"
const PENDING_PATH := "user://veyrath_mp_pending.json"
var back: Callable
var request: HTTPRequest
var timer: Timer
var current_action := ""
var access_token := ""
var world_id := ""
var actor_id := ""
var town_id := ""
var actor_name := ""
var pending_key := ""
var email: LineEdit
var password: LineEdit
var character_name: LineEdit
var sign_in: Button
var sign_up: Button
var enter_button: Button
var contribute_button: Button
var refresh_button: Button
var status: Label
var world_view: Label
var command_view: Label

func configure(return_callback: Callable) -> void:
	back = return_callback

func _ready() -> void:
	add_theme_constant_override("separation",14)
	text_label("MULTIPLAYER • MUNDO COMPARTILHADO",29,Color("d6b47d"))
	text_label("Um dispositivo conectado solicita a atualização; o servidor valida as decisões. O mundo é independente da campanha solo.",20,Color("d7dfeb"))
	character_name = input_field("Nome do personagem online")
	email = input_field("E-mail da conta")
	password = input_field("Senha")
	password.secret = true
	sign_in = make_button("ENTRAR",login)
	sign_up = make_button("CRIAR CONTA",signup)
	enter_button = make_button("ENTRAR NO MUNDO",enter_world)
	contribute_button = make_button("CONTRIBUIR · 2 CRÉDITOS",contribute)
	refresh_button = make_button("ATUALIZAR AGORA",poll)
	status = text_label("Entre ou crie uma conta para começar.",20,Color("d6b47d"))
	world_view = text_label("",22,Color("d7dfeb"))
	command_view = text_label("",19,Color("b7c5c6"))
	make_button("VOLTAR AO MENU",exit_screen)
	request = HTTPRequest.new()
	request.timeout = 20.0
	request.request_completed.connect(on_response)
	add_child(request)
	timer = Timer.new()
	timer.wait_time = 60.0
	timer.timeout.connect(on_timer)
	add_child(timer)
	timer.start()
	update_buttons()

func text_label(value: String, font_size: int, color: Color) -> Label:
	var item := Label.new()
	item.text = value
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",color)
	add_child(item)
	return item

func input_field(placeholder: String) -> LineEdit:
	var item := LineEdit.new()
	item.placeholder_text = placeholder
	item.custom_minimum_size.y = 66
	item.add_theme_font_size_override("font_size",22)
	add_child(item)
	return item

func make_button(value: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = value
	item.custom_minimum_size.y = 70
	item.add_theme_font_size_override("font_size",21)
	item.pressed.connect(action)
	add_child(item)
	return item

func update_buttons() -> void:
	var busy := not current_action.is_empty()
	var signed_in := not access_token.is_empty()
	var ready_world := signed_in and not actor_id.is_empty() and not town_id.is_empty()
	sign_in.visible = not signed_in
	sign_up.visible = not signed_in
	email.visible = not signed_in
	password.visible = not signed_in
	character_name.visible = not ready_world
	enter_button.visible = signed_in and not ready_world
	contribute_button.visible = ready_world
	refresh_button.visible = ready_world
	for b in [sign_in,sign_up,enter_button,contribute_button,refresh_button]:
		b.disabled = busy

func send_request(action: String, path: String, method: HTTPClient.Method, payload = null) -> void:
	if not current_action.is_empty():
		return
	var headers := PackedStringArray(["apikey: " + PUBLISHABLE_KEY,"Content-Type: application/json"])
	if not access_token.is_empty():
		headers.append("Authorization: Bearer " + access_token)
	current_action = action
	update_buttons()
	var body := "" if payload == null else JSON.stringify(payload)
	var err := request.request(ENDPOINT + path,headers,method,body)
	if err != OK:
		current_action = ""
		status.text = "Não foi possível iniciar a conexão. Confira sua internet."
		update_buttons()

func login() -> void:
	if email.text.strip_edges().is_empty() or password.text.is_empty():
		status.text = "Informe e-mail e senha."
		return
	status.text = "Entrando…"
	send_request("login","/auth/v1/token?grant_type=password",HTTPClient.METHOD_POST,{"email":email.text.strip_edges(),"password":password.text})

func signup() -> void:
	if email.text.strip_edges().is_empty() or password.text.length() < 6:
		status.text = "Informe um e-mail e uma senha com pelo menos 6 caracteres."
		return
	status.text = "Criando conta…"
	send_request("signup","/auth/v1/signup",HTTPClient.METHOD_POST,{"email":email.text.strip_edges(),"password":password.text})

func enter_world() -> void:
	actor_name = character_name.text.strip_edges()
	if actor_name.is_empty():
		status.text = "Informe o nome do personagem online."
		return
	status.text = "Localizando o mundo…"
	send_request("world","/rest/v1/veyrath_worlds?select=id,name,version&slug=eq.veyrath-primordial",HTTPClient.METHOD_GET)

func poll() -> void:
	if world_id.is_empty() or actor_id.is_empty():
		return
	status.text = "Solicitando atualização ao mundo…"
	send_request("poll","/rest/v1/rpc/veyrath_poll_world",HTTPClient.METHOD_POST,{"p_world":world_id})

func on_timer() -> void:
	if not access_token.is_empty() and not actor_id.is_empty() and current_action.is_empty():
		poll()

func uuid4() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16:
		return ""
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0,8),hex.substr(8,4),hex.substr(12,4),hex.substr(16,4),hex.substr(20,12)]

func load_pending():
	if not FileAccess.file_exists(PENDING_PATH):
		return {}
	var file := FileAccess.open(PENDING_PATH,FileAccess.READ)
	if not file:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return null
	return parser.data

func contribute() -> void:
	if actor_id.is_empty() or town_id.is_empty():
		return
	var pending = load_pending()
	if pending == null:
		status.text = "Não foi possível ler a ação pendente; nenhuma nova ação foi enviada."
		return
	if not pending.is_empty():
		if pending.get("actor","") != actor_id or pending.get("town","") != town_id or not pending.has("key"):
			status.text = "Há uma ação online pendente de outra conta neste dispositivo. Entre na conta original para reenviá-la."
			return
		pending_key = pending.key
	else:
		pending_key = uuid4()
		if pending_key.is_empty():
			status.text = "Não foi possível preparar a ação com segurança."
			return
		var temp_path := PENDING_PATH + ".tmp"
		var file := FileAccess.open(temp_path,FileAccess.WRITE)
		if not file:
			status.text = "Não foi possível registrar a ação neste aparelho."
			return
		file.store_string(JSON.stringify({"actor":actor_id,"town":town_id,"key":pending_key}))
		file.flush()
		var err := file.get_error()
		file.close()
		if err != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path),ProjectSettings.globalize_path(PENDING_PATH)) != OK:
			status.text = "Não foi possível registrar a ação neste aparelho."
			return
	status.text = "Enviando contribuição; a aplicação será posterior."
	send_request("contribute","/rest/v1/rpc/veyrath_submit_contribution",HTTPClient.METHOD_POST,{"p_actor":actor_id,"p_settlement":town_id,"p_key":pending_key})

func on_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var action := current_action
	current_action = ""
	var parser := JSON.new()
	var data = null
	if parser.parse(body.get_string_from_utf8()) == OK:
		data = parser.data
	if result != HTTPRequest.RESULT_SUCCESS:
		status.text = "Sem resposta da rede. Se enviou uma contribuição, toque nela novamente para reenviar com segurança."
		update_buttons()
		return
	if code < 200 or code >= 300:
		if code == 401:
			access_token = ""
			world_id = ""
			actor_id = ""
			town_id = ""
			password.clear()
			status.text = "Sessão inválida ou expirada. Entre novamente."
		elif action == "contribute" and code >= 400 and code < 500:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PENDING_PATH))
			status.text = "A contribuição foi recusada. Verifique créditos e ações pendentes."
		else:
			status.text = "Não foi possível concluir a operação (código %s). Verifique os dados e tente novamente." % code
		update_buttons()
		return
	match action:
		"signup":
			password.clear()
			status.text = "Conta solicitada. Se exigido, confirme o e-mail antes de entrar."
		"login":
			password.clear()
			if not data is Dictionary or not data.has("access_token"):
				status.text = "Não foi possível iniciar a sessão."
			else:
				access_token = data.access_token
				status.text = "Conectado. Informe o nome e entre no mundo."
		"world":
			if data is Array and not data.is_empty():
				world_id = data[0].id
				send_request("character","/rest/v1/rpc/veyrath_register_character",HTTPClient.METHOD_POST,{"p_world":world_id,"p_name":actor_name})
			else:
				status.text = "Mundo não encontrado."
		"character":
			if data is Dictionary and data.has("id"):
				actor_id = data.id
				actor_name = data.name
				send_request("town","/rest/v1/veyrath_settlements?select=id,name,public_supplies,version&world_id=eq." + world_id,HTTPClient.METHOD_GET)
			else:
				status.text = "Personagem online indisponível."
		"town":
			if data is Array and not data.is_empty():
				town_id = data[0].id
				poll()
			else:
				status.text = "Cidade compartilhada indisponível."
		"poll":
			status.text = "Mundo consultado. Ações aguardam seu prazo no servidor."
			send_request("refresh_town","/rest/v1/veyrath_settlements?select=name,public_supplies,version&id=eq." + town_id,HTTPClient.METHOD_GET)
		"refresh_town":
			if data is Array and not data.is_empty():
				world_view.text = "%s · %s\nSuprimentos da cidade: %s" % [actor_name,data[0].name,data[0].public_supplies]
			send_request("commands","/rest/v1/veyrath_commands?select=status,available_at,rejection_reason&order=created_at.desc&limit=5",HTTPClient.METHOD_GET)
		"commands":
			command_view.text = "ÚLTIMAS AÇÕES\n"
			if data is Array:
				for cmd in data:
					var stage: String = {"pending":"Pendente","applied":"Aplicada","rejected":"Recusada"}.get(cmd.status,cmd.status)
					command_view.text += "%s · previsão: %s\n" % [stage,cmd.available_at]
				if data.is_empty():
					command_view.text += "Nenhuma ação enviada."
		"contribute":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PENDING_PATH))
			pending_key = ""
			status.text = "Contribuição recebida. Ela aguarda o prazo de aplicação."
			poll()
	update_buttons()

func exit_screen() -> void:
	access_token = ""
	password.clear()
	back.call()
