extends SceneTree

const Game = preload("res://veyrath/engine.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var game = Game.new()
	check(game.new_game("Primeiro save","scholar","valdor",361),"Criar campanha")
	var transfer: String = game.export_campaign()
	check(transfer.begins_with("VEY1."),"Exportação tem formato versionado")
	check(game.new_game("Outro save","scholar","valdor",362),"Criar segundo save")
	check(not game.import_campaign(transfer.replace("VEY1.","VEY1.0")) and game.state.seed==362,"Código adulterado não substitui save")
	check(game.import_campaign(transfer) and game.load_game() and game.state.seed==361,"Importação válida sobrevive a reload")
	check(game.read_save(game.BACKUP).seed==362,"Importação preserva backup anterior")
	var d = game.dossier
	var c = d.civic
	var city: Dictionary = game.expedition_city()
	var city_id: String = city.id
	var book: Dictionary = d.create(361,1)
	d.open_story(book,city,"S02",1)
	var adoption: Dictionary = book.stories[city_id+":S02"]
	d.perform(book,adoption.id,0,"A",city_id,2,99,99,{})
	var estate: Dictionary = book.civic.estates[adoption.id]
	var adoptee: Dictionary = book.actors[adoption.cast[0].id]
	check(adoptee.parents.has(estate.holder) and not book.actors[estate.holder].alive,"Adoção e vínculo de pessoa falecida")
	c.settle(book,estate,3)
	var shares: Dictionary = book.civic.properties[estate.asset].shares
	check(shares.size()==2 and shares[estate.heirs[0]]==50 and shares[estate.heirs[1]]==50,"Partilha em duas cotas")
	check(estate.debts==0 and estate.paid==2 and estate.cash==2,"Dívida debitada do espólio")
	c.settle(book,estate,4)
	check(estate.cash==2,"Execução repetida não debita espólio")
	d.open_story(book,city,"S07",4)
	var succession: Dictionary = book.stories[city_id+":S07"]
	d.perform(book,succession.id,0,"B",city_id,5,99,99,{})
	var office: Dictionary = c.office_for(book,city_id)
	check(office.status=="regência" and office.incumbent==succession.cast[0].id,"Regência tem ocupante")
	c.advance(book,44)
	check(office.incumbent.is_empty() and office.status=="vacância","Regência expira")
	d.open_story(book,city,"S08",45)
	var reform: Dictionary = book.stories[city_id+":S08"]
	d.perform(book,reform.id,0,"B",city_id,46,99,99,{})
	var law: Dictionary = book.civic.laws.values()[0]
	check(law.effective==53 and not law.retroactive and shares.size()==2,"Vigência prospectiva e cotas preservadas")
	d.open_story(book,city,"S21",47)
	var mystery: Dictionary = book.stories[city_id+":S21"]
	var culprit: String = book.civic.cases[mystery.id].responsible
	d.perform(book,mystery.id,0,"C",city_id,48,99,99,{})
	check(book.civic.reports.values()[0].kind=="boato" and not book.known.has(city_id+":s21_clock"),"Boato não concede prova")
	check(book.civic.cases[mystery.id].responsible==culprit,"Responsável oculto fixado ao abrir")
	d.open_story(book,city,"N03",49)
	var move_story: Dictionary = book.stories[city_id+":N03"]
	var traveler: Dictionary = book.actors[move_story.cast[0].id]
	traveler.openness = 74
	d.perform(book,move_story.id,0,"D",city_id,50,99,99,{})
	check(traveler.home==city_id and traveler.has("move"),"Mudança não teletransporta")
	c.advance(book,int(traveler.move.arrival))
	check(traveler.home!=city_id and traveler.residences[0].city==city_id,"Chegada aplica o novo domicílio")
	d.open_story(book,city,"S25",55)
	var frontier: Dictionary = book.stories[city_id+":S25"]
	var domain: Dictionary = book.places[city_id]
	domain.government = "regência"
	domain.tension = 67
	domain.supply = 18
	office.status = "regência"
	office.incumbent = frontier.cast[0].id
	office.review = 110
	d.perform(book,frontier.id,0,"C",city_id,56,99,99,{})
	var army: Dictionary = c.front_for(book,city_id)
	check(not army.is_empty() and army.strength==6 and army.supplies==5,"Mandato mobiliza força abastecida")
	var result: String = c.battle(book,frontier,59)
	check(result.contains("Baixas") and army.battles.size()==1 and army.supplies==3 and domain.damage>0,"Batalha consome suprimento e registra dano")
	c.battle(book,frontier,59)
	check(army.battles.size()==1 and army.supplies==3,"Ordem militar idempotente")
	game.state.dossier = book
	check(game.save_game() and game.load_game() and game.state.dossier.civic.fronts[city_id].battles.size()==1,"Frente e batalha preservadas no save")
	print("Registros cívicos e exportação: %d falhas." % failures)
	quit(1 if failures else 0)
