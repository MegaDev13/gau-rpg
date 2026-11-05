extends RefCounted
## Persistent civil and military records. Records reference the canonical actor registry.
const OPS := ["inventory_estate","buy_share","contest_estate","settle_estate","adopt","sell_assets",
	"institution","household_agreement","dissolve_household","succession","unilateral","law",
	"investigate","contract","rumor","employment","mandate","logistics","hazard","publication_hold",
	"custody","diplomacy","convoy","blockade","prisoner_exchange","offensive","appeal","survey_route",
	"repair","mediation","relocate","transfer_plant"]
const REGISTRIES := ["estates","properties","institutions","offices","laws","contracts","fronts","reports","cases"]
var world

func _init(catalog) -> void:
	world = catalog

func ensure(book: Dictionary) -> Dictionary:
	if not book.has("civic"):
		book.civic = {"version":1,"clock":int(book.origin_day),"ledger":[]}
		for key in REGISTRIES:
			book.civic[key] = {}
	return book.civic

func valid(record) -> bool:
	if not record is Dictionary or record.get("version") != 1 or not record.get("ledger") is Array:
		return false
	if typeof(record.get("clock")) not in [TYPE_INT,TYPE_FLOAT]:
		return false
	for key in REGISTRIES:
		if not record.get(key) is Dictionary:
			return false
		for row in record[key].values():
			if not row is Dictionary:
				return false
	for row in record.offices.values():
		if not row.has_all(["method","incumbent","claimant","status","candidates","review","opposition"]):
			return false
	for row in record.estates.values():
		if not row.has_all(["holder","heirs","asset","debts","cash","state","contest_until"]) or not record.properties.has(row.asset):
			return false
	for row in record.properties.values():
		if not row.has_all(["city","title","shares","custodians","encumbrances"]) or not row.shares is Dictionary:
			return false
	for row in record.fronts.values():
		if not row.has_all(["city","status","strength","morale","supplies","next_supply","battles"]) or not row.battles is Array:
			return false
	return true

func setup_place(book: Dictionary, city: Dictionary) -> Dictionary:
	if not book.places.has(city.id):
		book.places[city.id] = {
			"supply":int(city.supply),"origin_supply":int(city.supply),"health":50,"river":55,"habitat":55,"legitimacy":45,
			"tension":32,"route":0,"damage":0,"marks":{},"government":"inicial",
			"war":"calm","flux":4,"civil":0,"deaths":0,"duty":0,
		}
	return book.places[city.id]

func actor_id(story: Dictionary, slot: int) -> String:
	return story.cast[mini(slot,story.cast.size()-1)].id

func open_case(book: Dictionary, story: Dictionary, day: int) -> void:
	var civic := ensure(book)
	var city: String = story.city
	var id: String = story.id
	if story.source in ["S01","S02","S03","S08"] and not civic.estates.has(id):
		var decedent := id+":titular"
		book.actors[decedent] = {"id":decedent,"name":"Titular do espólio","home":city,"alive":false,"death_day":day,
			"age":63,"job":"titular","people":"Humano","pin":12,"knowledge":{}}
		var heirs := [actor_id(story,0),actor_id(story,1)]
		var asset := id+":bem"
		civic.properties[asset] = {"title":asset,"city":city,"shares":{decedent:100},"custodians":[actor_id(story,2)],
			"use_rights":[actor_id(story,2)],"encumbrances":[],"source":id}
		civic.estates[id] = {"holder":decedent,"heirs":heirs,"asset":asset,"debts":2,"cash":4,"state":"aberto",
			"contest_until":int(story.due),"adoption_recognized":false,"appeal":false,"city":city,"story":id,
			"claims":{heirs[0]:"parentesco",heirs[1]:"adoção" if story.source=="S01" else "parentesco"}}
		if story.source=="S03":
			civic.estates[id].will = {heirs[0]:60,heirs[1]:40}
	if story.source in ["S07","N01"]:
		var office := office_for(book,city)
		office.candidates = [actor_id(story,0 if story.source=="S07" else 1),actor_id(story,1 if story.source=="S07" else 2)]
		if office.incumbent.is_empty():
			office.status = "vacância"
			office.review = int(story.due)
	if story.source in ["S09","S19","S20","S21","S24","S31","S33"] and not civic.cases.has(id):
		var resolution: int = world.number(int(book.seed),id+":causa",4)
		civic.cases[id] = {"resolution":resolution,"progress":0,"status":"em instrução","deadline":int(story.due)}
		if story.source == "S21":
			civic.cases[id].responsible = actor_id(story,resolution)
		if story.source == "S19":
			civic.cases[id].missing = actor_id(story,3)

func office_for(book: Dictionary, city: String) -> Dictionary:
	var civic := ensure(book)
	if not civic.offices.has(city):
		civic.offices[city] = {"method":"hereditário" if city=="valdoria-0" else "conselho",
			"incumbent":"","claimant":"","status":"vacância","candidates":[],"review":0,"opposition":0}
	return civic.offices[city]

func front_for(book: Dictionary, city: String) -> Dictionary:
	return ensure(book).fronts.get(city,{})

func advance(book: Dictionary, day: int) -> void:
	var civic := ensure(book)
	if day <= int(civic.clock):
		return
	civic.clock = day
	for city in civic.offices:
		var office: Dictionary = civic.offices[city]
		var expired: bool = office.status == "regência" and int(office.review) <= day
		var died: bool = not office.incumbent.is_empty() and not book.actors.get(office.incumbent,{}).get("alive",false)
		if expired or died:
			office.incumbent = ""
			office.status = "vacância"
			book.places[city].government = "cargo vago"
	advance_fronts(book,day)
	for person in book.actors.values():
		if person.has("move") and person.move.arrival <= day:
			var previous: Array = person.get("residences",[])
			previous.append({"city":person.home,"until":person.move.arrival})
			person.residences = previous
			person.home = person.move.to
			person.erase("move")
	for estate in civic.estates.values():
		if estate.state == "inventário" and int(estate.contest_until) <= day:
			settle(book,estate,int(estate.contest_until))
		elif estate.state == "contestado" and int(estate.get("appeal_due",day+1))<=day:
			estate.state = "inventário"
			estate.appeal_result = "A posse isolada não alterou o título. O inventário voltou a tramitar."
			settle(book,estate,int(estate.appeal_due))

func check(book: Dictionary, story: Dictionary, action: Dictionary) -> String:
	var op: String = action.special
	var domain: Dictionary = book.places[story.city]
	var front := front_for(book,story.city)
	var office: Dictionary = ensure(book).offices.get(story.city,{})
	var authority: String = domain.government if office.is_empty() else office.status
	var mandated := authority in ["regência","titular","constitucional","título reconhecido"]
	if op == "offensive" and not front.is_empty() and pact_active(book,story.city,front.enemy,int(book.civic.clock)):
		return "A rota está protegida por tratado em vigor."
	if op in ["offensive","convoy","prisoner_exchange"] and (front.is_empty() or front.get("status") not in ["mobilização","combate","ocupação"] or int(front.strength)<2 or int(front.supplies)<2):
		return "Requer força existente e abastecida nesta frente."
	if op == "offensive":
		if not mandated:
			return "A ofensiva requer mandato de um governo em exercício."
		if front.has("march"):
			return "A guarnição já está em marcha."
		var passage := march_plan(book,front,int(book.civic.clock))
		if int(front.supplies)<int(passage.cost)+2:
			return "Faltam provisões para a marcha e o combate."
	if op in ["mandate","unilateral"] and not mandated:
		return "Requer autoridade formal da jurisdição."
	if op == "unilateral" and story.source == "N01" and (front.is_empty() or int(front.strength) < 2):
		return "A operação exige tropas disponíveis."
	if op == "law" and int(domain.legitimacy) < 42:
		return "A assembleia ainda não tem apoio para deliberar."
	if op == "buy_share" and not ensure(book).estates.has(story.id):
		return "Nenhum título foi registrado para a transferência."
	if op == "transfer_plant" and int(domain.legitimacy) < 51:
		return "A jurisdição vizinha ainda não deu consentimento ambiental."
	return ""

func settle(book: Dictionary, estate: Dictionary, day: int) -> void:
	if estate.state in ["executado","contestado"]:
		return
	var property: Dictionary = ensure(book).properties[estate.asset]
	if not property.shares.has(estate.holder):
		return
	var heirs: Array = estate.heirs.filter(func(id):
		if not book.actors.get(id,{}).get("alive",false):
			return false
		return estate.get("claims",{}).get(id) != "adoção" or estate.adoption_recognized or adoption_law(book,estate.get("city",""),day))
	if heirs.is_empty():
		estate.state = "vacância"
		return
	var initial := int(property.shares[estate.holder])
	var will: Dictionary = estate.get("will",{})
	var distributed := 0
	var weight := 0
	for id in heirs:
		weight += int(will.get(id,1))
	if weight <= 0:
		return
	property.shares.erase(estate.holder)
	for id in heirs:
		var quota := floori(float(initial)*int(will.get(id,1))/weight)
		property.shares[id] = int(property.shares.get(id,0))+quota
		distributed += quota
	property.shares[heirs[0]] += initial-distributed
	var paid := mini(int(estate.cash),int(estate.debts))
	estate.cash -= paid
	estate.debts -= paid
	estate.paid = paid
	estate.state = "executado"
	estate.executed_day = day

func adoption_law(book: Dictionary, city: String, day: int) -> bool:
	for rule in ensure(book).laws.values():
		if rule.city==city and str(rule.scope).ends_with(":S08") and rule.decision=="B" and int(rule.effective)<=day:
			return true
	return false

func dispatch(book: Dictionary, story: Dictionary, op: String, day: int, option: String, action: Dictionary) -> String:
	var civic := ensure(book)
	var city: String = story.city
	var domain: Dictionary = book.places[city]
	var id: String = story.id
	var key := "%s:%d:%s" % [id,int(story.stage),option]
	var estate: Dictionary = civic.estates.get(id,{})
	match op:
		"inventory_estate":
			estate.state = "inventário"
		"settle_estate":
			settle(book,estate,day)
		"buy_share":
			var holder := String(estate.heirs[0])
			var buyer := String(estate.heirs[1])
			if not book.actors[holder].alive or not book.actors[buyer].alive or book.actors[holder].openness < 48 or book.actors[buyer].openness < 44:
				return "O negócio foi recusado por um dos interessados."
			settle(book,estate,day)
			var property: Dictionary = civic.properties[estate.asset]
			if not property.shares.has(holder) or not property.shares.has(buyer):
				return "A titularidade e a habilitação ainda não permitem cessão."
			var share := mini(15,int(property.shares[holder]))
			property.shares[holder] -= share
			property.shares[buyer] += share
			property.encumbrances.append(key)
			civic.contracts[key] = {"kind":"dívida de quota","parties":[holder,buyer],"amount":share,"due":day+30}
			return "Quinze pontos de participação, ou o saldo disponível, passaram ao comprador."
		"contest_estate":
			estate.state = "contestado"
			estate.appeal = true
			estate.appeal_due = maxi(day,int(estate.contest_until))+7
		"sell_assets":
			estate.cash += 3
			estate.private_sale_day = day
		"adopt":
			var child: Dictionary = book.actors[actor_id(story,0 if story.source=="S02" else 2)]
			var parent: Dictionary = book.actors[estate.holder]
			var parents: Array = child.get("parents",[])
			if not parents.has(parent.id):
				parents.append(parent.id)
				child.parents = parents
				var children: Array = parent.get("children",[])
				children.append(child.id)
				parent.children = children
			estate.adoption_recognized = true
		"institution":
			civic.institutions[key] = {"kind":id,"city":city,"leader":actor_id(story,1),"founded":day,"treasury":int(action.cost),"access":"público" if option!="D" else "provisório"}
			if story.source == "S03":
				civic.properties[estate.asset].custodians = [key]
		"custody":
			civic.properties[key] = {"title":"título em instrução","city":city,"shares":{},"custodians":[actor_id(story,3 if option=="B" else 0)],
				"use_rights":[],"encumbrances":[],"source":id,"review":day+30}
		"law":
			civic.laws[key] = {"city":city,"effective":day+7,"issued":day,"authority":actor_id(story,0),"quorum":int(domain.legitimacy),
				"scope":id,"decision":option,"retroactive":false}
		"succession","mediation","unilateral":
			var office := office_for(book,city)
			var nominee := actor_id(story,1 if story.source=="N01" else 0)
			if op == "succession":
				office.claimant = nominee
				if office.status != "regência":
					office.review = day+20
				office.procedure = {"opened":day,"source":id,"claimants":office.candidates.duplicate(),"proof_required":office.method=="hereditário"}
			elif op == "mediation":
				var rival := actor_id(story,2)
				if book.actors[nominee].openness < 45 or book.actors[rival].openness < 48:
					office.opposition += 1
					return "Uma parte rejeitou a minuta. O cargo continua em disputa."
				office.incumbent = nominee
				office.status = "regência"
				office.review = day+38
				civic.contracts[key] = {"kind":"poderes limitados","parties":[nominee,rival],"due":office.review}
			else:
				office.claimant = nominee
				office.opposition += 2
				office.status = "contestada"
				office.de_facto = nominee
				domain.government = "poder contestado"
		"employment":
			var worker: Dictionary = book.actors[actor_id(story,0)]
			var old_job: Array = worker.get("job_history",[])
			old_job.append({"job":worker.job,"until":day})
			worker.job_history = old_job
			worker.job = {"S10":"representante de turno","S13":"atendimento temporário"}.get(story.source,"responsável de contrato")
			worker.employment = {"since":day,"income":2,"shift":day%4,"employer":actor_id(story,1)}
		"relocate":
			var destination := neighbor(city,int(book.seed))
			var seats := 2 if story.source=="N02" else 1
			for i in range(seats):
				var participant: Dictionary = book.actors[actor_id(story,i)]
				if not participant.alive or participant.openness < 47:
					return "A mudança foi recusada; as residências anteriores foram mantidas."
			for i in range(seats):
				var participant: Dictionary = book.actors[actor_id(story,i)]
				participant.move = {"to":destination.id,"arrival":day+int(world.route(world.city(city,int(book.seed)),destination,false).days)}
		"household_agreement","dissolve_household":
			var first: Dictionary = book.actors[actor_id(story,0)]
			var second: Dictionary = book.actors[actor_id(story,1)]
			if not first.alive or not second.alive or first.age < 18 or second.age < 18:
				return "O contrato exige duas partes adultas e elegíveis."
			var consent: bool = first.openness >= 45 and second.openness >= 48
			if op=="household_agreement" and not consent:
				return "Um dos responsáveis não aceitou o pacto patrimonial."
			var pair: String = first.id+"|"+second.id
			civic.contracts[key] = {"kind":"pacto patrimonial" if op=="household_agreement" else "partilha doméstica",
				"parties":[first.id,second.id],"city":city,"date":day,"due":day+30,"regime":"separado",
				"contributions":{first.id:1,second.id:1},"status":"consensual" if consent else "em mediação"}
			if op=="dissolve_household" and book.relationships.has(pair) and not book.unions.has(pair):
				book.relationships[pair].state = "separação"
			return "As contribuições individuais permanecem registradas."
		"contract","diplomacy","mandate","logistics","blockade","convoy","prisoner_exchange","repair","appeal":
			civic.contracts[key] = {"kind":op,"parties":[actor_id(story,0),actor_id(story,1)],"city":city,"date":day,"due":day+14,"amount":int(action.cost),"status":"registrado"}
			if op == "blockade":
				var front := front_for(book,city)
				if not front.is_empty():
					front.supplies = maxi(0,int(front.supplies)-2)
			if op == "convoy":
				front_for(book,city).supplies += 3
			if op == "diplomacy":
				domain.marks.diplomatic_channel = true
		"rumor","publication_hold":
			civic.reports[key] = {"city":city,"source":id,"kind":"boato" if op=="rumor" else "nota editorial","day":day,"text":action.result}
		"investigate":
			if civic.cases.has(id):
				var report: Dictionary = civic.cases[id]
				report.progress += 1
				report.status = "indícios registrados" if not action.fact.is_empty() else "instrução agendada"
		"survey_route":
			var risk: int = world.number(int(book.seed),key,10)
			var verified: bool = risk < 6 and int(domain.habitat)>37
			if verified:
				domain.route = maxi(-4,int(domain.route)-1)
				domain.marks.confirmed_route = true
			return "A rota foi confirmada em campo." if verified else "A passagem não foi certificada; nenhuma rota foi aberta."
		"hazard":
			var risk: int = world.number(int(book.seed),key,10)
			if risk < 6:
				domain.damage = mini(10,int(domain.damage)+2)
				domain.health = maxi(0,int(domain.health)-5)
				return "O risco se materializou em ferimentos e avarias."
			return "A operação terminou sem ferimentos registrados."
		"transfer_plant":
			var target: Dictionary = neighbor(city,int(book.seed))
			civic.contracts[key] = {"kind":"transferência ambiental","city":city,"to":target.id,"date":day,
				"due":day+14,"amount":int(action.cost),"status":"autorizado"}
			domain.river = mini(100,int(domain.river)+8)
			domain.marks.plant_transferred = true
		"offensive":
			return begin_march(book,story,day)
	return ""

func neighbor(city: String, seed: int) -> Dictionary:
	var origin: Dictionary = world.city(city,seed)
	var towns: Array = world.catalog.regions[origin.region].cities
	return world.city(city.get_slice("-",0)+"-"+str((int(city.get_slice("-",1))+1)%towns.size()),seed)

func mobilize(book: Dictionary, story: Dictionary, day: int) -> void:
	var city: String = story.city
	var foe := neighbor(city,int(book.seed))
	var previous := front_for(book,city)
	var force := {"id":city+":guarnição","city":city,"enemy":foe.id,"commander":actor_id(story,0),
		"strength":int(previous.get("strength",6)),"supplies":5,"morale":60,"status":"mobilização","day":day,"next_supply":day+7,
		"casualties":int(previous.get("casualties",0)),"civilian_losses":int(previous.get("civilian_losses",0)),
		"battles":previous.get("battles",[]),"objective":"passagem","location":city}
	ensure(book).fronts[city] = force

func pact_active(book: Dictionary, home: String, target: String, day: int) -> bool:
	var pact: Dictionary = front_for(book,home).get("treaty",{})
	if pact.is_empty() or not pact.get("ratified",false) or target not in pact.get("signatories",[]):
		return false
	return pact.scope=="peace" or day<int(pact.review)

func march_plan(book: Dictionary, front: Dictionary, day: int) -> Dictionary:
	var seed := int(book.seed)
	var origin: Dictionary = world.city(front.get("location",front.city),seed)
	var target: Dictionary = world.city(front.enemy,seed)
	var route: Dictionary = world.route(origin,target,false)
	var weather: Dictionary = world.condition(origin,seed,day,{})
	var delay := 1 if weather.weather in ["rain","storm"] else 0
	return {"arrival":day+int(route.days)+delay,"cost":maxi(1,ceili(float(route.distance)/3.0))+delay}

func begin_march(book: Dictionary, story: Dictionary, day: int) -> String:
	var front := front_for(book,story.city)
	var route := march_plan(book,front,day)
	if int(front.supplies)<int(route.cost)+2:
		return "A mudança do tempo impediu a partida com segurança."
	front.supplies -= int(route.cost)
	front.status = "marcha"
	front.march = {"id":"%s:%d" % [story.id,int(story.stage)],"from":front.get("location",story.city),
		"to":front.enemy,"departure":day,"arrival":route.arrival,"provisions":route.cost}
	return "A guarnição partiu com %d provisão(ões). Chegada prevista no dia %d." % [route.cost,route.arrival]

func advance_fronts(book: Dictionary, day: int) -> void:
	var fronts: Dictionary = ensure(book).fronts
	var cities: Array = fronts.keys()
	cities.sort()
	while true:
		var selected := ""
		var next_day := day+1
		var task := ""
		for city in cities:
			var front: Dictionary = fronts[city]
			if front.status=="trégua" and int(front.treaty.review)<next_day:
				next_day = int(front.treaty.review)
				selected = city
				task = "review"
			if front.status not in ["mobilização","combate","ocupação","marcha"]:
				continue
			if int(front.next_supply)<next_day:
				next_day = int(front.next_supply)
				selected = city
				task = "supply"
			if front.has("march") and int(front.march.arrival)<next_day:
				next_day = int(front.march.arrival)
				selected = city
				task = "arrival"
		if selected.is_empty():
			return
		var front: Dictionary = fronts[selected]
		var home: Dictionary = book.places[selected]
		match task:
			"review":
				front.status = "armistício expirado"
				home.war = "calm"
				if book.places.has(front.enemy) and book.places[front.enemy].war=="truce":
					book.places[front.enemy].war = "calm"
			"supply":
				front.next_supply += 7
				front.supplies = maxi(0,int(front.supplies)-1)
				if front.supplies==0:
					front.status = "retirada"
					front.erase("march")
					home.war = "calm"
			"arrival":
				var order: Dictionary = front.march
				front.erase("march")
				if pact_active(book,selected,order.to,next_day):
					front.status = "retirada"
					home.war = "calm"
					continue
				var target := setup_place(book,world.city(order.to,int(book.seed)))
				var report := battle_order(book,front,order.id,next_day,target,order.to)
				var journal: Array = ensure(book).ledger
				journal.append({"seq":journal.size()+1,"city":order.to,"day":next_day,"type":"battle",
					"story":order.id.get_slice(":",0)+":"+order.id.get_slice(":",1),"text":report})

func battle(book: Dictionary, story: Dictionary, day: int) -> String:
	var front := front_for(book,story.city)
	if front.is_empty() or front.has("march"):
		return "A ordem não pode ser resolvida antes da chegada."
	return battle_order(book,front,"%s:%d" % [story.id,int(story.stage)],day,book.places[story.city],story.city)

func battle_order(book: Dictionary, front: Dictionary, order: String, day: int, target: Dictionary, target_city: String) -> String:
	for item in front.battles:
		if item.id == order:
			return "A ordem militar já foi processada."
	var home: Dictionary = book.places[front.city]
	if int(front.supplies)<2 or int(front.strength)<2 or int(home.supply)<2:
		front.status = "retirada"
		home.war = "calm"
		return "O comando recuou por falta de efetivo ou suprimentos."
	var terrain: int = world.number(int(book.seed),order+":terreno",20)
	var defenders := front_for(book,target_city)
	var defense := int(defenders.get("strength",0)) if target_city!=front.city else 0
	var score := int(front.strength)*5+int(front.morale)/4+terrain-int(target.tension)/3-defense
	var result := "ocupação" if score>=40 else ("recuo" if score<24 else "combate")
	var loss := mini(int(front.strength),2 if score<32 else 1)
	var civilians := 1 if score<32 and int(target.tension)>67 else 0
	front.strength -= loss
	front.supplies -= 2
	home.supply -= 2
	front.casualties += loss
	front.civilian_losses += civilians
	front.status = "retirada" if result=="recuo" else result
	front.location = front.city if result=="recuo" else target_city
	front.morale = clampi(int(front.morale)+(6 if result=="ocupação" else -8),0,100)
	front.battles.append({"id":order,"day":day,"city":target_city,"result":result,"loss":loss,"civilians":civilians,"supply":2})
	home.deaths += loss
	home.duty = int(front.strength)
	target.deaths += civilians
	target.damage = mini(10,int(target.damage)+2)
	target.war = "calm" if result=="recuo" else "engaged"
	home.war = target.war
	if result=="ocupação" and target_city!=front.city:
		target.occupation = {"authority":front.city,"commander":front.commander,"since":day}
	return "Resultado: %s. Baixas militares: %d. Civis: %d." % [result,loss,civilians]
