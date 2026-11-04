extends RefCounted
## Version 1 derives immutable identities from a campaign seed. Only player-facing
## changes are stored; reading a district never populates the save with the catalog.
const VERSION := 1
const FOUNDING_SETTLEMENTS := 6
const GIVEN := ["Aren","Brena","Ciran","Dorin","Elva","Feren","Gara","Iria","Jorun","Kara","Luan","Mara","Neris","Oren","Pira","Ravia","Selen","Tarin","Uren","Vera","Yara","Zarel"]
const TRAITS := ["Cauteloso","Comunitário","Curioso","Idealista","Pragmático","Reservado","Ambicioso","Metódico"]
const VALUES := ["segurança do bairro","autonomia dos ofícios","memória das famílias","acesso ao conhecimento","estabilidade das rotas","saúde dos recursos locais"]
const SUFFIXES := ["do Farol","do Pátio","das Vigias","da Ponte","do Cais","da Carta","do Relógio","da Aurora","do Vale","da Travessa","do Sino","da Lume"]
var catalog: Dictionary

func _init() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://veyrath/expansion/catalog.json"))

func number(seed: int, key: String, limit: int) -> int:
	# Do not use RNG call order or the platform's object hash for persisted IDs.
	var digest := ("%s|%s|%s" % [VERSION,seed,key]).sha256_buffer()
	return int(digest.decode_u32(0)) % limit

func region_for_home(home: String) -> int:
	return 3 if home == "tharvok" else 0

func home_id(home: String) -> String:
	return "%s-0" % catalog.regions[region_for_home(home)].id

func city(id: String, seed: int) -> Dictionary:
	var pieces := id.split("-",false)
	if pieces.size() != 2 or not pieces[1].is_valid_int():
		return {}
	var slot := int(pieces[1])
	if slot < 0 or pieces[1] != str(slot):
		return {}
	for index in range(catalog.regions.size()):
		var r: Dictionary = catalog.regions[index]
		if pieces[0] == r.id and slot < r.cities.size():
			var size_class: String = ["Centro regional","Cidade","Cidade","Vila","Vila","Povoado"][mini(slot,5)]
			var size_base: int = [21000,7400,4200,1700,850,290][mini(slot,5)]
			return {"id":id,"name":r.cities[slot],"region":index,"region_name":r.name,
				"art":r.art,"size":size_class,"government":r.government,"economy":r.economy,
				"population":size_base + number(seed,id+"pop",size_base / 3),
				"supply":8+number(seed,id+"stock",17),"security":2+number(seed,id+"watch",8)}
	return {}

func places(settlement: Dictionary, seed: int) -> Array:
	var result := []
	var region: Dictionary = catalog.regions[settlement.region]
	# Each regional economy determines which institutions can appear.
	for index in range(region.places.size()):
		var kind: String = region.places[index]
		var type: Dictionary = catalog.places[kind]
		var id := "%s/%s" % [settlement.id,kind]
		var mark := number(seed,id+"sign",SUFFIXES.size())
		var district: String = type.zone if settlement.size in ["Centro regional","Cidade"] else "Núcleo local"
		result.append({"id":id,"city":settlement.id,"kind":kind,
			"name":type.name+" "+SUFFIXES[mark],"district":district,"art":type.art,
			"goods":type.goods,"trim":number(seed,id+"trim",6),"slot":index})
	return result

func place(id: String, seed: int) -> Dictionary:
	var settlement := city(id.get_slice("/",0),seed)
	if settlement.is_empty():
		return {}
	for item in places(settlement,seed):
		if item.id == id:
			return item
	return {}

func person(site: Dictionary, staff: int, seed: int) -> Dictionary:
	var settlement := city(site.city,seed)
	var region: Dictionary = catalog.regions[settlement.region]
	var type: Dictionary = catalog.places[site.kind]
	var id := "%s/%d" % [site.id,staff]
	var lineage := number(seed,site.id+"family",region.suffix.size())
	var origin := "%s-%d" % [region.id,number(seed,id+"birth",FOUNDING_SETTLEMENTS)]
	var name := "%s %s" % [GIVEN[(number(seed,site.id+"given",GIVEN.size())+staff*5)%GIVEN.size()],region.suffix[lineage if staff < 2 else number(seed,id+"surname",region.suffix.size())]]
	var peer := "%s/%d" % [site.id,(staff+1)%4]
	var household := "%s/%d" % [site.id,1-staff] if staff < 2 else ""
	return {"id":id,"name":name,"people":region.peoples[number(seed,id+"people",region.peoples.size())],
		"job":type.jobs[staff],"age":22+number(seed,id+"age",53),"birthplace":origin,"home":site.city,
		"site":site.id,"personality":TRAITS[number(seed,id+"trait",TRAITS.size())],
		"value":VALUES[number(seed,id+"value",VALUES.size())],"goal":type.goals[staff],
		"reserve":2+number(seed,id+"reserve",21),"coworker":peer,"household":household,
		"important":staff == 0 and int(site.slot) < 3,"off_shift":number(seed,id+"shift",4),
		"pin":number(seed,id+"pin",48)}

func present(actor: Dictionary, day: int) -> bool:
	return day % 4 != int(actor.off_shift)

func route(origin: Dictionary, destination: Dictionary, fast: bool) -> Dictionary:
	var same_region: bool = origin.region == destination.region
	var distance := 1 + absi(int(origin.id.get_slice("-",1)) - int(destination.id.get_slice("-",1)))
	if not same_region:
		distance += 4 + absi(int(origin.region)-int(destination.region))*2
	return {"distance":distance,"days":maxi(1,ceili(distance / 3.0)) if fast else distance,
		"credits":ceili(distance/2.0) if fast else 0,"method":"Transporte contratado" if fast else "Em caravana a pé"}

func project(settlement: Dictionary, seed: int, day: int, backing: Dictionary) -> Dictionary:
	var cycle := floori(float(day-1)/14.0)
	var date := cycle*14+1
	var id := "%s:%d" % [settlement.id,cycle]
	var sites := places(settlement,seed)
	var site: Dictionary = sites[number(seed,id+"initiative",sites.size())]
	var owner := person(site,0,seed)
	var partner := person(site,1,seed)
	var self_funded := int(owner.reserve) + int(partner.reserve) >= 25
	var backed := backing.has(id)
	var phase := "pedido" if day < date+9 else ("realizado" if backed or self_funded else "adiado")
	var cost := maxi(0,25-int(owner.reserve)-int(partner.reserve))
	return {"id":id,"date":date,"deadline":date+9,"site":site.id,"site_name":site.name,
		"lead":owner,"partner":partner,"cost":cost,"backed":backed,"phase":phase,"self_funded":self_funded}

func condition(settlement: Dictionary, seed: int, day: int, backing: Dictionary) -> Dictionary:
	var season := floori(float(day-1)/90.0)
	var season_balance := number(seed,settlement.id+str(season)+"supply",11)-5
	var initiative := project(settlement,seed,day,backing)
	var delta := 3 if initiative.phase == "realizado" else (-2 if initiative.phase == "adiado" else 0)
	var previous: Dictionary = {}
	var previous_cycle_end := floori(float(day-1)/14.0)*14
	if previous_cycle_end > 0:
		previous = project(settlement,seed,previous_cycle_end,backing)
		delta += 1 if previous.phase == "realizado" else -1
	var reserves := maxi(0,int(settlement.supply)+season_balance+delta)
	var change := (number(seed,settlement.id+str(season)+"population",9)-4)*0.004
	return {"supply":reserves,"population":roundi(float(settlement.population)*(1.0+change)),
		"security":clampi(int(settlement.security)+signi(reserves-10),0,10),
		"weather":["mist","rain","embers"][number(seed,settlement.id+str(floori(day/3.0))+"weather",3)],
		"daylight":day%4,"project":initiative,"previous_project":previous}
