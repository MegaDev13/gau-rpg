extends SceneTree

const Game = preload("res://veyrath/engine.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var game = Game.new()
	check(game.new_game("Coroa e fronteira","scholar","valdor",361),"Nova campanha")
	estates(game)
	succession(game)
	war(game)
	print("Campanhas, espólios e tratados: %d falhas." % failures)
	quit(1 if failures else 0)

func estates(game) -> void:
	var d = game.dossier
	var c = d.civic
	var city: Dictionary = game.expedition_city()
	var book: Dictionary = d.create(361,1)
	d.open_story(book,city,"S01",1)
	var id: String = city.id+":S01"
	check(not d.perform(book,id,0,"C",city.id,2,99,99,{}).is_empty(),"Posse contestada entrou em recurso")
	var case_record: Dictionary = book.civic.estates[id]
	var property: Dictionary = book.civic.properties[case_record.asset]
	var hearing: int = case_record.appeal_due
	c.advance(book,hearing-1)
	check(property.shares.has(case_record.holder) and case_record.state=="contestado","Posse não transfere título durante recurso")
	c.advance(book,hearing)
	check(case_record.state=="executado" and not property.shares.has(case_record.heirs[1]),"Adoção sem habilitação não é tratada como propriedade adquirida")
	d.open_story(book,city,"S08",hearing+1)
	d.perform(book,city.id+":S08",0,"B",city.id,hearing+2,99,99,{})
	check(not c.adoption_law(book,city.id,hearing+8) and c.adoption_law(book,city.id,hearing+9),"Mudança legal só vale a partir da vigência")
	check(not property.shares.has(case_record.heirs[1]),"Lei nova não reabre partilha concluída")
	d.open_story(book,city,"S03",hearing+10)
	var written: Dictionary = book.civic.estates[city.id+":S03"]
	c.settle(book,written,hearing+11)
	var testament: Dictionary = book.civic.properties[written.asset]
	check(testament.shares[written.heirs[0]]==60 and testament.shares[written.heirs[1]]==40,"Testamento distribui exatamente a quota do espólio")
	check(written.paid==2 and testament.custodians.size()==1,"Dívida paga pelo espólio e custódia preservada")

func succession(game) -> void:
	var d = game.dossier
	var city: Dictionary = game.expedition_city()
	var book: Dictionary = d.create(361,1)
	d.open_story(book,city,"N01",1)
	var story: Dictionary = book.stories[city.id+":N01"]
	var domain: Dictionary = book.places[city.id]
	story.stage = 3
	story.due = 30
	domain.legitimacy = 45
	domain.tension = 66
	check(d.perform(book,story.id,3,"D",city.id,4,99,99,{}).is_empty(),"Tribunal exige prova de adoção")
	domain.marks.adoption = true
	check(not d.perform(book,story.id,3,"D",city.id,4,99,99,{}).is_empty(),"Tribunal pode reconhecer o pretendente")
	var office: Dictionary = book.civic.offices[city.id]
	check(office.de_jure==story.cast[2].id and office.de_facto==story.cast[1].id,"Prova dinástica não garante controle de fato")
	book.actors[office.incumbent].alive = false
	d.civic.advance(book,5)
	check(office.incumbent.is_empty() and office.status=="vacância","Morte do titular provoca vacância")

func war(game) -> void:
	var d = game.dossier
	var c = d.civic
	var city: Dictionary = game.expedition_city()
	var city_id: String = city.id
	var book: Dictionary = d.create(361,1)
	d.open_story(book,city,"N06",1)
	var story: Dictionary = book.stories[city_id+":N06"]
	var domain: Dictionary = book.places[city_id]
	domain.government = "regência"
	domain.tension = 67
	domain.supply = 30
	c.mobilize(book,story,2)
	domain.war = "engaged"
	var front: Dictionary = c.front_for(book,city_id)
	var target: Dictionary = game.expansion.city(front.enemy,361)
	d.open_story(book,target,"S25",2)
	var target_story: Dictionary = book.stories[target.id+":S25"]
	c.mobilize(book,target_story,2)
	var opposing: Dictionary = c.front_for(book,target.id)
	check(front.id!=opposing.id and front.location==city_id and opposing.location==target.id,"Duas guarnições possuem identidades distintas")
	story.stage = 4
	story.due = 45
	var result: Dictionary = d.perform(book,story.id,4,"D",city_id,4,99,99,{})
	check(not result.is_empty() and front.has("march") and front.supplies<5 and front.battles.is_empty(),"A opção de escalada agenda marcha, sem batalha instantânea")
	var arrival: int = front.march.arrival
	c.advance(book,arrival-1)
	check(front.battles.is_empty() and front.location==city_id,"A frente ainda não cruzou a rota")
	game.state.dossier = book
	check(game.save_game() and game.load_game(),"Save preserva ordem militar em trânsito")
	book = game.state.dossier
	front = c.front_for(book,city_id)
	c.advance(book,arrival)
	check(not front.has("march") and front.battles.size()==1 and int(front.battles[0].day)==arrival,"Chegada resolve batalha no dia correto")
	check(front.battles[0].city==target.id and int(book.places[target.id].damage)>0,"Dano foi aplicado no assentamento atingido")
	c.advance(book,arrival)
	check(front.battles.size()==1,"Repetição após reload não duplica a ordem")
	story = book.stories[story.id]
	domain = book.places[city_id]
	domain.legitimacy = 55
	domain.tension = 44
	book.places[target.id].tension = 74
	d.apply_special(book,story,domain,"ratify",arrival+1)
	check(not c.pact_active(book,city_id,target.id,arrival+2),"A jurisdição rival pode recusar a ratificação")
	book.places[target.id].tension = 40
	d.apply_special(book,story,domain,"ratify",arrival+2)
	check(c.pact_active(book,city_id,target.id,arrival+2),"Tratado vincula as duas jurisdições")
	check(not c.pact_active(book,city_id,city_id+"-outro",arrival+2),"Tratado não restringe uma parte alheia")
	check(str(c.check(book,story,{"special":"offensive"})).contains("tratado"),"Tratado impede emitir ofensiva na mesma rota")
