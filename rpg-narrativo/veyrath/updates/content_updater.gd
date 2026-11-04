extends RefCounted
## Signed data-only bundles. They never execute code or modify saves.
const NATIVE_VERSION := 7
const FORMAT_VERSION := 1
const MAX_ENVELOPE := 1500000
const MAX_BUNDLE := 1000000
const ROOT_URL := "https://raw.githubusercontent.com/MegaDev13/gau-rpg/refs/heads/feature/rpg-narrativo-mundo-vivo/rpg-narrativo/remote/"
var key_text := ""
var directory := "user://veyrath_content"

func _init(test_key: String = "", test_directory: String = "") -> void:
	key_text = test_key if not test_key.is_empty() else FileAccess.get_file_as_string("res://veyrath/updates/vey_public_key.pem")
	if not test_directory.is_empty():
		directory = test_directory

func path(name: String) -> String:
	return directory + "/" + name

func atomic_write(filename: String, value: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		return false
	var dst := path(filename)
	var tmp := dst + ".tmp"
	var file := FileAccess.open(tmp,FileAccess.WRITE)
	if not file:
		return false
	file.store_string(value)
	file.flush()
	var err := file.get_error()
	file.close()
	if err != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),ProjectSettings.globalize_path(dst)) == OK

func parse_json(value: String):
	var parser := JSON.new()
	if parser.parse(value) != OK:
		return null
	return parser.data

func raw_base64(value: String) -> PackedByteArray:
	var data := Marshalls.base64_to_raw(value)
	if Marshalls.raw_to_base64(data) != value:
		return PackedByteArray()
	return data

func sha256(data: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish()

func short_string(data, max_len: int) -> bool:
	return data is String and not data.strip_edges().is_empty() and data.length() <= max_len

func safe_id(id: String) -> bool:
	if id.is_empty() or id.length() > 48:
		return false
	for c in id:
		if not c in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			return false
	return true

func jpeg_dimensions(data: PackedByteArray) -> Vector2i:
	if data.size() < 4 or data[0] != 255 or data[1] != 216:
		return Vector2i.ZERO
	var i := 2
	while i + 3 < data.size():
		if data[i] != 255:
			return Vector2i.ZERO
		var marker := int(data[i+1])
		i += 2
		if marker == 216 or marker == 1:
			continue
		if marker == 217 or marker == 218 or i + 1 >= data.size():
			return Vector2i.ZERO
		var length := int(data[i])*256 + int(data[i+1])
		if length < 2 or i + length > data.size():
			return Vector2i.ZERO
		if marker in [192,193,194,195,197,198,199,201,202,203,205,206,207] and length >= 7:
			return Vector2i(int(data[i+5])*256+int(data[i+6]),int(data[i+3])*256+int(data[i+4]))
		i += length
	return Vector2i.ZERO

func validate(raw: String, channel: String = "", install_id: String = "", rollout: bool = false) -> Dictionary:
	if raw.to_utf8_buffer().size() > MAX_ENVELOPE:
		return {"ok":false,"error":"Pacote grande demais."}
	var envelope = parse_json(raw)
	if not envelope is Dictionary or not envelope.has_all(["manifest","signature","bundle"]):
		return {"ok":false,"error":"Formato de pacote inválido."}
	for k in ["manifest","signature","bundle"]:
		if not envelope[k] is String:
			return {"ok":false,"error":"Dados do pacote inválidos."}
	var manifest_bytes := raw_base64(envelope.manifest)
	var signature := raw_base64(envelope.signature)
	var bundle_bytes := raw_base64(envelope.bundle)
	if manifest_bytes.is_empty() or signature.is_empty() or bundle_bytes.is_empty() or bundle_bytes.size() > MAX_BUNDLE:
		return {"ok":false,"error":"Dados de assinatura ou pacote inválidos."}
	var key := CryptoKey.new()
	if key.load_from_string(key_text,true) != OK:
		return {"ok":false,"error":"Chave pública de atualização inválida."}
	if not Crypto.new().verify(HashingContext.HASH_SHA256,sha256(manifest_bytes),signature,key):
		return {"ok":false,"error":"Assinatura não reconhecida."}
	var manifest = parse_json(manifest_bytes.get_string_from_utf8())
	if not manifest is Dictionary or not manifest.has_all(["format","version","min_native","max_native","channel","rollout_percent","size","sha256"]):
		return {"ok":false,"error":"Manifesto incompleto."}
	for k in ["format","version","min_native","max_native","rollout_percent","size"]:
		if typeof(manifest[k]) not in [TYPE_INT,TYPE_FLOAT] or float(manifest[k]) != floorf(float(manifest[k])):
			return {"ok":false,"error":"Versão ou tamanho inválido."}
	if manifest.format != FORMAT_VERSION or manifest.version < 1 or manifest.min_native > NATIVE_VERSION or manifest.max_native < NATIVE_VERSION:
		return {"ok":false,"error":"A atualização exige outra versão do aplicativo."}
	if manifest.channel not in ["beta","stable"] or (not channel.is_empty() and manifest.channel != channel):
		return {"ok":false,"error":"Canal de atualização incorreto."}
	if manifest.rollout_percent < 0 or manifest.rollout_percent > 100 or int(manifest.size) != bundle_bytes.size() or not manifest.sha256 is String or manifest.sha256 != sha256(bundle_bytes).hex_encode():
		return {"ok":false,"error":"Integridade ou distribuição inválida."}
	if rollout:
		if install_id.is_empty():
			return {"ok":false,"error":"Identificador de instalação indisponível."}
		var cohort := int((install_id + ":" + str(manifest.version)).sha256_buffer().decode_u32(0)) % 100
		if cohort >= int(manifest.rollout_percent):
			return {"ok":false,"error":"Atualização ainda não liberada para este aparelho."}
	var pack = parse_json(bundle_bytes.get_string_from_utf8())
	if not pack is Dictionary or pack.get("schema",0) != 1 or not pack.has("stories") or not pack.stories is Array or pack.stories.size() < 1 or pack.stories.size() > 10:
		return {"ok":false,"error":"Conteúdo narrativo inválido."}
	var ids := {}
	for story in pack.stories:
		if not story is Dictionary or not story.has_all(["id","title","text","choices"]) or not story.id is String or not safe_id(story.id) or ids.has(story.id):
			return {"ok":false,"error":"História inválida."}
		ids[story.id] = true
		if not short_string(story.title,120) or not short_string(story.text,4000) or not story.choices is Array or story.choices.size() < 1 or story.choices.size() > 5:
			return {"ok":false,"error":"Conteúdo da história inválido."}
		var choice_ids := {}
		for choice in story.choices:
			if not choice is Dictionary or not choice.has_all(["id","label","result"]) or not choice.id is String or not safe_id(choice.id) or choice_ids.has(choice.id) or not short_string(choice.label,180) or not short_string(choice.result,1500):
				return {"ok":false,"error":"Escolha inválida."}
			choice_ids[choice.id] = true
	if pack.has("image_jpg"):
		if not pack.image_jpg is String or pack.image_jpg.length() > 800000:
			return {"ok":false,"error":"Imagem inválida."}
		var image_bytes := raw_base64(pack.image_jpg)
		var dimensions := jpeg_dimensions(image_bytes)
		var img := Image.new()
		if image_bytes.is_empty() or dimensions.x <= 0 or dimensions.y <= 0 or dimensions.x > 2048 or dimensions.y > 2048 or img.load_jpg_from_buffer(image_bytes) != OK:
			return {"ok":false,"error":"Imagem não reconhecida."}
	if pack.has("audio_ogg"):
		if not pack.audio_ogg is String or pack.audio_ogg.length() > 600000:
			return {"ok":false,"error":"Áudio inválido."}
		var audio_bytes := raw_base64(pack.audio_ogg)
		if audio_bytes.is_empty() or AudioStreamOggVorbis.load_from_buffer(audio_bytes) == null:
			return {"ok":false,"error":"Áudio não reconhecido."}
	return {"ok":true,"manifest":manifest,"pack":pack}

func read_checked(filename: String) -> Dictionary:
	var file := FileAccess.open(path(filename),FileAccess.READ)
	if not file or file.get_length() > MAX_ENVELOPE:
		return {}
	var raw := file.get_as_text()
	var result := validate(raw)
	if not result.get("ok",false):
		return {}
	result["raw"] = raw
	return result

func current() -> Dictionary:
	var result := read_checked("active.json")
	return read_checked("previous.json") if result.is_empty() else result

func high_watermark() -> int:
	var file := FileAccess.open(path("highest.txt"),FileAccess.READ)
	return int(file.get_as_text()) if file else 0

func install(raw: String, channel: String, install_id: String) -> Dictionary:
	var result := validate(raw,channel,install_id,true)
	if not result.get("ok",false):
		return result
	var version := int(result.manifest.version)
	if version <= high_watermark():
		return {"ok":false,"error":"Esta versão já foi instalada ou é antiga."}
	var old := current()
	if not old.is_empty() and not atomic_write("previous.json",old.raw):
		return {"ok":false,"error":"Não foi possível criar a cópia de segurança."}
	if not atomic_write("active.json",raw):
		return {"ok":false,"error":"Não foi possível instalar o pacote."}
	if not atomic_write("highest.txt",str(version)):
		# Never claim success if the downgrade guard could not be persisted.
		if not old.is_empty():
			atomic_write("active.json",old.raw)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path("active.json")))
		return {"ok":false,"error":"Não foi possível concluir a instalação."}
	return {"ok":true,"version":version}

func rollback() -> bool:
	var previous := read_checked("previous.json")
	if previous.is_empty():
		return false
	return atomic_write("active.json",previous.raw)
