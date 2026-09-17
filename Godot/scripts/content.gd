extends RefCounted
class_name SpiritContent

var raw: Dictionary
var cards: Array
var encounters: Array[Dictionary] = []

const CHAPTER_NAMES_ZH = [
	"雾林", "烬河三角洲", "雷鸣群峰", "岩甲城塞", "荆棘荒野", "万灵潮汐", "翠玉圣域", "幻雾长原", "怒焰火山", "万象熔炉",
	"沉沦废墟", "暗涌深渊", "亡灵回廊", "血月峡谷", "蚀骨沼泽", "寂静墓园", "裂魂断崖", "幽冥深渊", "噬影荒原", "深渊之王座",
	"云海孤峰", "雷霆天堑", "风蚀断岭", "星陨荒漠", "极光冰原", "苍穹回廊", "天穹裂隙", "流星圣域", "天狱回音", "苍穹主宰",
	"虚无之境", "归墟暗流", "湮灭回廊", "无光深渊", "亡界孤岛", "虚空裂痕", "归墟秘境", "万魂窟", "湮灭回音", "归墟主宰",
	"创世裂隙", "混沌回廊", "星辰熔炉", "永恒回音", "万象之眼", "创世深渊", "时空裂境", "万灵归一", "创世回音", "万象终焉",
]
const CHAPTER_NAMES_EN = [
	"Mistwood", "Ember Delta", "Thunder Peaks", "Stone Citadel", "Thorn Wilds", "Spirit Tide", "Jade Sanctuary", "Mirage Expanse", "Fury Caldera", "Worldforge",
	"Sunken Ruins", "Abyssal Current", "Wraith Corridor", "Bloodmoon Canyon", "Bonerot Marsh", "Silent Necropolis", "Soulrend Cliffs", "Netherdeep Abyss", "Shadowmaw Wastes", "Abyssal Throne",
	"Cloudsea Pinnacle", "Thunder Rift", "Windworn Ridge", "Starfall Desert", "Aurora Icefield", "Skybound Corridor", "Heaven's Fissure", "Meteor Sanctum", "Skyprison Echo", "Sovereign of the Sky",
	"Void Reaches", "Netherfall Current", "Oblivion Corridor", "Lightless Abyss", "Deadworld Isle", "Voidrift", "Netherfall Sanctum", "Chamber of Ten Thousand Souls", "Oblivion Echo", "Sovereign of the Void",
	"Genesis Rift", "Chaos Corridor", "Stellar Forge", "Eternal Echo", "Eye of Worlds", "Genesis Abyss", "Rift of Time", "Convergence of Spirits", "Genesis Echo", "The End of All",
]
const WAYPOINT_ZH = ["入口", "集市", "险峰", "营火", "深处"]
const WAYPOINT_EN = ["Trailhead", "Market", "Ridge", "Campfire", "Heart"]

# One chronicle entry per chapter, unlocked in step with the map's own chapter-lock rule
# (chapter * 5 <= profile.unlocked) rather than any separate flag — reads as a travelogue the
# player fills in just by playing, with no extra bookkeeping of its own. The 50 chapters read
# as five 10-chapter realms tracing one arc: wake in the mortal Mistwood, descend into the
# sunken/undead depths, climb into a storm-wracked sky realm, pass beyond it into lightless
# void, and finally reach the primordial realm where the world was both forged and will end.
const CHAPTER_LORE_ZH = [
	"灵狐初醒之地，终年不散的浓雾中藏着最早的低阶亡魂。",
	"河水早已被战火染成灰烬色，三角洲上仍能听见旧日战鼓的余音。",
	"山峰终年悬着雷云，传说峰顶封印着一头未曾苏醒的雷兽。",
	"废弃的边境要塞，如今只有披着岩甲的哨兵仍在履行早已无人下达的命令。",
	"荆棘吞没了所有旧日道路，唯有循着灵光才能找到穿行的缝隙。",
	"退潮时露出的滩涂上，散落着无数微弱灵魂随波而来又随波而去。",
	"供奉着古老灵狐一族的圣域，翠玉神像的裂缝里渗出微弱却持续的灵气。",
	"长原上的幻雾能重现旅人最深的记忆，也最擅长把它们变成陷阱。",
	"活火山的怒焰从未真正熄灭，山腹中沉睡着一头以怒火为食的古兽。",
	"传说中万物最初被锻造成形之地，如今熔炉仍在运转，锻造着不该存在的东西。",
	"一座曾经辉煌的城市沉入地底，如今只剩残垣间游荡的旧日居民。",
	"看似平静的深渊水面下，暗涌裹挟着无数不愿沉睡的怨灵。",
	"回廊无始无终，亡灵们仍在其中重复着死前最后一刻的动作。",
	"每当血月升起，峡谷的岩壁便会渗出暗红色的、拒绝干涸的液体。",
	"沼泽的酸雾能在几日内蚀穿骨骼，也正因此格外偏爱瘴气生物栖居。",
	"一座葬着整座古国的墓园，安静得连脚步声都显得多余。",
	"断崖间的风声撕扯着经过的每一缕灵魂，据说崖底堆满了被撕碎的记忆。",
	"深渊底部彻底断绝了阳光，连灵狐一族的灵火也只能勉强照亮脚下。",
	"荒原上的影子会独立于主人行动，且格外贪婪地吞噬其他灵魂的影子。",
	"深渊尽头的王座早已空置千年，但王座本身仍在散发着统御一切亡灵的意志。",
	"孤峰刺穿云海，站在峰顶能望见脚下整片大陆，也能望见头顶更高的风暴。",
	"天堑中终年游走着实体化的雷电，劈开的不只是岩石，还有闯入者的运气。",
	"断岭被烈风打磨了千万年，风声中仍能辨出远古灵兽振翅的回音。",
	"荒漠中散落着坠落星辰的碎片，每一块都还带着来自天外的余温。",
	"冰原上空的极光并非天象，而是无数被冻结的灵魂仍在无声呐喊的光。",
	"回廊悬浮于云层之上，据说是古代天工匠人为守护苍穹而建的最后防线。",
	"天穹上的裂隙从未愈合，透过裂隙能瞥见另一重天空，以及不属于此界的目光。",
	"圣域由陨石建成，古代祭司在此观测星轨，直到星轨本身开始观测他们。",
	"一座悬浮的天牢，囚禁的对象早已逃脱，只剩回音仍在履行看守的职责。",
	"自封为苍穹主宰者的宝座悬于风暴眼中央，风暴本身就是它的意志延伸。",
	"越过苍穹尽头便是彻底的虚无，连灵火在此也只能勉强维持一豆微光。",
	"传说万物终将坠入的归墟就藏在这片虚空深处，暗流正缓缓将一切拖向那里。",
	"回廊中的一切声音、色彩与记忆都在缓慢湮灭，唯有意志足够坚定者才能留下痕迹。",
	"深渊彻底吞噬光线，包括从外界带入的灵火——你只能凭感觉战斗。",
	"一整座曾经存在过的世界，如今只剩孤岛大小的残片漂浮在虚空中。",
	"裂痕深处传出的低语声，据说是无数破碎世界临死前最后的记录。",
	"秘境守护着归墟的入口，历代守护者最终都选择了坠入，而非继续守护。",
	"窟中封存着万千灵魂的残响，据说数量恰好等于这个世界曾经失去的一切。",
	"此地连湮灭本身都开始产生回音，仿佛虚无也在害怕被彻底遗忘。",
	"归墟主宰从不言语，因为在它统治的领域里，语言本身早已失去意义。",
	"裂隙深处仍残留着世界诞生瞬间的余温，触碰它的手会短暂忘记时间的存在。",
	"回廊尚未被秩序整理过，脚下的路会随着走过它的意志而改变形状。",
	"每一颗星辰最初都在此炉中锻造，如今炉火仍未熄灭，只是不再锻造星辰。",
	"此地时间不再流动，所有曾经发生过的战斗都在永恒回音中反复上演。",
	"巨眼俯瞰着所有平行存在的世界，据说它眨眼的间隙，便是一整个世界的终结。",
	"深渊既是世界诞生之处，也是世界最终归于虚无之处——起点与终点在此重叠。",
	"裂境中过去、现在与未来同时存在，稍有不慎便会与另一个时间线的自己交手。",
	"所有曾经存在过的灵魂最终都会汇聚于此，包括那些尚未死去、却注定要来的。",
	"世界诞生时发出的第一声回响仍未消散，越靠近尽头，回响就越清晰。",
	"万象的终焉，也是万象的起点——传说灵狐一族最初的记忆，就诞生于此地即将崩塌的瞬间。",
]
const CHAPTER_LORE_EN = [
	"Where the fox spirit first wakes — a fog that never lifts, and the first restless dead hiding in it.",
	"The river ran to ash generations ago; the delta still echoes with the drums of a war no one remembers starting.",
	"Thunderheads never leave these peaks — legend says something enormous sleeps beneath the highest one.",
	"An abandoned border fortress where stone-clad sentries still stand a post no one has ordered them to hold in centuries.",
	"Thorns have swallowed every old road — only a trace of spirit-light still finds a way through.",
	"At low tide the flats fill with countless faint spirits, washed in and out like driftwood.",
	"A sanctuary built for the ancient fox-spirit line — faint power still seeps from the cracks in its jade idols.",
	"The mirage-fog here conjures a traveler's deepest memories — and is just as good at turning them into traps.",
	"The caldera's fury never truly cools — something ancient sleeps in its belly, feeding on the rage itself.",
	"Where the world itself was said to be first forged — the furnace still burns, shaping things that were never meant to exist.",
	"A once-glorious city sank into the earth; only its former residents still wander the ruins.",
	"Beneath a deceptively calm surface, hidden currents drag countless restless spirits who refuse to sleep.",
	"A corridor with no beginning and no end, where the dead endlessly relive the instant before they died.",
	"Whenever the bloodmoon rises, the canyon walls weep a dark red fluid that never dries.",
	"Its acid mist can eat through bone in days — which is exactly why miasma-born things call it home.",
	"A necropolis holding an entire fallen kingdom, so silent that even footsteps feel like an intrusion.",
	"The wind between these cliffs tears at every passing soul — the base is said to be piled with shredded memories.",
	"No light has ever reached the bottom of this abyss — even foxfire can barely hold back the dark underfoot.",
	"Shadows here move on their own, and hunger — quite literally — for other souls' shadows.",
	"The throne at the abyss's end has sat empty for a thousand years — yet it still radiates the will to command every restless dead.",
	"A lone peak piercing the cloud-sea — from its summit you can see the whole continent below, and a bigger storm above.",
	"Solid lightning roams this rift year-round, splitting stone — and the luck of anyone foolish enough to enter.",
	"Ground down by gales for ten thousand years, the ridge's wind still carries the echo of an ancient spirit-beast's wingbeats.",
	"Fallen star-fragments litter this desert, each one still faintly warm with heat from somewhere beyond the sky.",
	"The aurora here isn't weather — it's the silent, frozen scream of countless trapped spirits, still glowing.",
	"A corridor suspended above the clouds, said to be the last line the old sky-artificers built to guard the heavens.",
	"A fissure in the sky itself that never healed — through it, glimpses of another heaven, and eyes that don't belong to this one.",
	"Built from meteoric stone — ancient priests once charted the stars here, until the stars began charting them back.",
	"A floating prison whose prisoner escaped long ago — only the echo of its wardens still keeps watch.",
	"The self-proclaimed sovereign's throne hangs at the eye of the storm — the storm itself is just an extension of its will.",
	"Past the edge of the sky lies pure nothing — even foxfire barely holds on to a single flickering point of light.",
	"The mythic Netherfall — where all things are said to finally fall — hides in this void, and its current is slowly dragging everything toward it.",
	"Every sound, color, and memory here slowly erodes into nothing — only the strongest will leaves any trace at all.",
	"This abyss devours all light, including foxfire carried in from outside — you fight here by feel alone.",
	"An entire world that once existed, now shrunk to a single drifting island-sized fragment in the void.",
	"A low whisper drifts from deep in the rift — said to be the last recorded words of countless shattered worlds.",
	"A sanctum guarding the Netherfall's entrance — every guardian before this one eventually chose to fall in rather than keep watching.",
	"A chamber holding the residual echoes of ten thousand souls — said to number exactly everything this world has ever lost.",
	"Even oblivion itself echoes here, as if the void were afraid of being forgotten completely.",
	"The Sovereign of the Void never speaks — in the realm it rules, language lost its meaning long ago.",
	"The rift still holds the warmth of the world's first instant — touch it, and your hand briefly forgets time exists.",
	"This corridor has never been touched by order — the path underfoot reshapes itself to match whoever's will is strongest.",
	"Every star was once forged in this furnace — the fire never went out, it simply stopped making stars.",
	"Time doesn't pass here — every battle that ever happened just keeps replaying, forever.",
	"A vast eye watching over every parallel world at once — a single blink, they say, is long enough to end one.",
	"The abyss where the world was born is the same abyss it will return to — beginning and end, folded into one place.",
	"Past, present, and future all coexist in this rift — one wrong step, and you're fighting a version of yourself from another timeline.",
	"Every spirit that has ever existed eventually converges here — including those not yet dead, but already destined to arrive.",
	"The very first sound the world ever made still hasn't faded — the closer you get to the end, the clearer it rings.",
	"The end of all things is also their beginning — legend holds that the fox spirits' very first memory was born in this place's final, collapsing instant.",
]
const ENEMIES = [
	{"name":"雾林守卫", "name_en":"Mistwood Sentinel", "art":"sentinel-v1.jpg", "tint":"83e4c1", "lore":"游荡于雾林间的古老哨兵，行动迟缓但极难被击溃。", "lore_en":"An ancient sentinel wandering the misty woods — slow, but brutally hard to bring down."},
	{"name":"提灯石卫", "name_en":"Lanternstone Keeper", "art":"lanternstone-keeper-v1.jpg", "tint":"75d7d2", "lore":"以石灯照亮回廊的守望者，偏好稳固防御与反复布阵。", "lore_en":"A watcher lighting the corridors with stone lanterns, favoring steady defense over aggression."},
	{"name":"缚文巨像", "name_en":"Runebound Colossus", "art":"runebound-colossus-v1.jpg", "tint":"a3c8ff", "lore":"由古老符文束缚而成的巨像，力大无穷，招式沉重。", "lore_en":"A colossus bound by ancient runes, immense in strength and weighty in every strike."},
	{"name":"烬崖守护者", "name_en":"Embercliff Guardian", "art":"embercliff-guardian-v1.jpg", "tint":"f0b16d", "lore":"栖息于烬崖的守护者，愤怒时攻击力会持续攀升。", "lore_en":"A guardian dwelling on the ember cliffs, growing more dangerous the longer a fight drags on."},
	{"name":"山岳之心", "name_en":"Heart of the Mountain", "art":"heart-of-mountain-v1.jpg", "tint":"e67c65", "lore":"整座山脉的意志凝聚而成，是每十章尽头等待着的终极考验。", "lore_en":"The will of an entire mountain given form — the ultimate trial waiting at the end of every tenth chapter."},
]

func enemy_lore(enemy: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return str(enemy.get("lore_en", ""))
	return str(enemy.get("lore", ""))

const EQUIPMENT = [
	{"id":"emberBlade","slot":"weapon","icon":"⚔","icon_kind":"sword","icon_flourish":"flame","zh":"烬火长刀","en":"Ember Blade","detail":"每回合第一张攻击牌伤害 +3。","detail_en":"First attack each turn deals +3 damage."},
	{"id":"jadePlate","slot":"armor","icon":"⬢","icon_kind":"shield","icon_flourish":"","zh":"翠玉战甲","en":"Jade Plate","detail":"战斗开始时获得 8 点护盾。","detail_en":"Start battle with 8 Shield."},
	{"id":"soulPendant","slot":"charm","icon":"◇","icon_kind":"pendant","icon_flourish":"eye","zh":"猎魂坠饰","en":"Soul Pendant","detail":"击败敌人回复 2 点生命，每场最多 3 次。","detail_en":"Heal 2 HP on kill, up to 3 times per battle."},
	{"id":"moonStaff","slot":"weapon","icon":"☾","icon_kind":"staff","icon_flourish":"crescent","zh":"月纹法杖","en":"Moon Staff","detail":"每回合第一张策略牌返还 1 点能量。","detail_en":"First Tactic each turn refunds 1 Energy."},
	{"id":"thornArmor","slot":"armor","icon":"✣","icon_kind":"shield","icon_flourish":"spike","zh":"荆棘铠甲","en":"Thorn Armor","detail":"受到敌方伤害后反击 2 点。","detail_en":"Retaliate 2 damage when hit by enemies."},
	{"id":"tideCharm","slot":"charm","icon":"≋","icon_kind":"pendant","icon_flourish":"wave","zh":"灵潮玉佩","en":"Tide Charm","detail":"每回合首次获得护盾时抽 1 张牌。","detail_en":"First Shield gained each turn draws 1 card."},
	{"id":"stoneSpear","slot":"weapon","icon":"➹","icon_kind":"spear","icon_flourish":"","zh":"破岩灵枪","en":"Stone Spear","detail":"攻击牌无视敌方护盾。","detail_en":"Attacks pierce enemy Shield."},
	{"id":"mistCloak","slot":"armor","icon":"≈","icon_kind":"shield","icon_flourish":"wave","zh":"流雾披风","en":"Mist Cloak","detail":"每第三次敌方攻击伤害归零。","detail_en":"Every 3rd enemy attack deals 0 damage."},
	{"id":"fortuneSeal","slot":"charm","icon":"◆","icon_kind":"pendant","icon_flourish":"coin","zh":"旅运金印","en":"Fortune Seal","detail":"胜利金币增加 15%。","detail_en":"Gold rewards increased by 15%."},
	{"id":"stormBow","slot":"weapon","icon":"ϟ","icon_kind":"bow","icon_flourish":"","zh":"逐电长弓","en":"Storm Bow","detail":"击败敌人时抽 1 张牌。","detail_en":"Draw 1 card on kill."},
	{"id":"phoenixMail","slot":"armor","icon":"♨","icon_kind":"shield","icon_flourish":"wing","zh":"涅槃羽衣","en":"Phoenix Mail","detail":"每场一次，以 15 点生命抵挡致命伤害。","detail_en":"Survive lethal damage once with 15 HP."},
	{"id":"focusCharm","slot":"charm","icon":"◉","icon_kind":"pendant","icon_flourish":"spiral","zh":"凝神灵镜","en":"Focus Charm","detail":"战斗开始时获得 1 层凝神。","detail_en":"Start battle with 1 Focus."},
]

# Quest "type" values are the vocabulary game.gd's _advance_quest() understands. Each is
# tied to a signal that already exists in the game (a card played, a chest opened, a
# purchase made) rather than anything new the engine has to emit.
const DAILY_QUESTS = [
	{"id":"d_win3","type":"win_battles","target":3,"reward":40,"zh":"打赢 3 场战斗","en":"Win 3 battles"},
	{"id":"d_damage200","type":"deal_damage","target":200,"reward":35,"zh":"造成 200 点总伤害","en":"Deal 200 total damage"},
	{"id":"d_rune3","type":"play_runed_cards","target":3,"reward":30,"zh":"使用 3 次镶嵌符文的卡牌","en":"Play 3 rune-socketed cards"},
	{"id":"d_chest1","type":"open_chest","target":1,"reward":25,"zh":"开启 1 个胜利宝箱","en":"Open 1 victory chest"},
	{"id":"d_shop1","type":"shop_purchase","target":1,"reward":25,"zh":"在商店购买 1 次","en":"Make 1 purchase in the shop"},
	{"id":"d_gold100","type":"earn_gold","target":100,"reward":30,"zh":"累计获得 100 金币","en":"Earn 100 gold"},
]
const WEEKLY_QUESTS = [
	{"id":"w_eliteboss5","type":"clear_elite_or_boss","target":5,"reward":150,"zh":"击败 5 场精英或首领战斗","en":"Clear 5 elite or boss battles"},
	{"id":"w_damage2000","type":"deal_damage","target":2000,"reward":140,"zh":"累计造成 2000 点伤害","en":"Deal 2000 total damage"},
	{"id":"w_greatboss1","type":"defeat_great_boss","target":1,"reward":200,"zh":"击败 1 位大首领","en":"Defeat 1 great boss"},
	{"id":"w_collect5","type":"collect_cards","target":5,"reward":130,"zh":"收集 5 张新卡牌","en":"Collect 5 new cards"},
	{"id":"w_win15","type":"win_battles","target":15,"reward":160,"zh":"打赢 15 场战斗","en":"Win 15 battles"},
	{"id":"w_gold500","type":"earn_gold","target":500,"reward":120,"zh":"累计获得 500 金币","en":"Earn 500 gold"},
]

# Rolling weekly login reward: "log in on any N of the 7 days this week" rather than a
# hard-reset daily streak — 2026 mobile-retention research is explicit that the reset variant
# makes a player give up on the whole system after one missed day, while a forgiving weekly
# tally keeps paying off even after a gap. See game.gd's _ensure_login_reward_current().
const LOGIN_REWARD_TIERS = [
	{"days":3,"reward":30},
	{"days":5,"reward":60},
	{"days":7,"reward":100},
]

const RELICS = [
	{"id":"foxCharm","icon":"✦","icon_mark":"flame","color":"ffb765","zh":"绯狐护符","en":"Fox Charm","detail":"第 2 回合额外获得 1 点能量。","detail_en":"Gain 1 extra Energy on Turn 2."},
	{"id":"starShard","icon":"✧","icon_mark":"sparkle","color":"a2d9ff","zh":"碎星石","en":"Star Shard","detail":"每回合第一张攻击牌额外造成 2 点伤害。","detail_en":"First attack each turn deals +2 damage."},
	{"id":"ancientSeed","icon":"❦","icon_mark":"leaf","color":"8ff5cf","zh":"古树之种","en":"Ancient Seed","detail":"每回合开始回复 2 点生命。","detail_en":"Restore 2 HP at the start of each turn."},
	{"id":"windChime","icon":"≋","icon_mark":"wave","color":"78e9ff","zh":"引灵风铃","en":"Spirit Chime","detail":"抽牌堆洗牌时额外抽 1 张牌。","detail_en":"Draw 1 card when the draw pile is reshuffled."},
	{"id":"bloodJade","icon":"❥","icon_mark":"drop","color":"ff7373","zh":"饮血玉","en":"Blood Jade","detail":"击败敌人回复 3 点生命。","detail_en":"Restore 3 HP when an enemy dies."},
	{"id":"thunderSeal","icon":"ϟ","icon_mark":"bolt","color":"ffe08a","zh":"雷纹印","en":"Thunder Seal","detail":"每 3 回合开始时获得 2 点能量。","detail_en":"Gain 2 Energy every third turn."},
	{"id":"mirrorScale","icon":"◈","icon_mark":"rings","color":"b9a2ff","zh":"镜鳞甲","en":"Mirror Scale","detail":"回合结束时保留一半护盾。","detail_en":"Keep half of your Shield at end of turn."},
	{"id":"emberCore","icon":"♨","icon_mark":"cross_blade","color":"ff9868","zh":"烬心","en":"Ember Core","detail":"燃烧每层额外造成 1 点伤害。","detail_en":"Burn deals 1 extra damage per stack."},
	{"id":"cursedTome","icon":"🕮","icon_mark":"leaf","color":"b359ff","zh":"死灵禁典","en":"Cursed Tome","detail":"每回合多抽 1 张牌，但每回合受到 2 点伤害。","detail_en":"Draw 1 additional card each turn, but take 2 damage each turn."},
	{"id":"titanBell","icon":"🔔","icon_mark":"shield_mark","color":"ffd700","zh":"泰坦古钟","en":"Titan Bell","detail":"最大生命 +20，战斗开始获 15 护盾。每两回合能量上限 -1。","detail_en":"+20 Max HP, start battle with 15 Shield. -1 Energy every 2 turns."},
	{"id":"chaosPrism","icon":"💎","icon_mark":"sparkle","color":"ff4081","zh":"混沌棱镜","en":"Chaos Prism","detail":"每次攻击造成伤害时施加 1 层易伤，但敌人初始护盾 +6。","detail_en":"Attacks apply 1 Vulnerable, but enemies start with +6 Shield."},
]

# High-stakes, high-impact relics reserved for Great Boss kills specifically — a regular
# boss draws from RELICS minus this list, so these three stay rare and always feel like the
# reward for the hardest fight in a chapter, not something that can also drop from a
# mid-chapter boss.
const BOSS_RELIC_IDS = ["cursedTome", "titanBell", "chaosPrism"]

# combat.gd's upgrade bonus is already a raw int add with no cap of its own (see
# state.upgrades.get(card.id, 0) in _play_card/_resolve_effects/_preview_damage) — the cap
# lives here, purely as a UI/economy rule, so a card can be Spirit-Smithed to +1 once and,
# on a later rest-site visit, Awakened to +2, then no further.
const MAX_CARD_UPGRADE := 2

const RUNES = [
	{"id":"swift","icon":"»","icon_mark":"chevrons","zh":"迅捷","en":"Swift","detail":"每回合第一次使用免费（返还其能量费用）。","detail_en":"First play each turn is free (refunds its Energy cost).","color":"78e9ff"},
	{"id":"chain","icon":"⌁","icon_mark":"bolt","zh":"连锁","en":"Chain","detail":"40% 单体伤害传递给另一名敌人。","detail_en":"40% single-target damage splashes to another enemy.","color":"a2d9ff"},
	{"id":"echo","icon":"◎","icon_mark":"rings","zh":"回响","en":"Echo","detail":"以 50% 数值重复卡牌效果。","detail_en":"Repeat card effect at 50% value.","color":"d1a8ff"},
	{"id":"siphon","icon":"◒","icon_mark":"drop","zh":"吸魂","en":"Siphon","detail":"获得伤害 25% 的护盾。","detail_en":"Gain Shield equal to 25% of damage dealt.","color":"80e4c0"},
	{"id":"burning","icon":"♨","icon_mark":"flame","zh":"灼烧","en":"Burning","detail":"伤害牌额外施加 2 层燃烧。","detail_en":"Attacks apply 2 additional Burn.","color":"ff9868"},
	{"id":"guardian","icon":"⬡","icon_mark":"shield_mark","zh":"守御","en":"Guardian","detail":"使用时额外获得 4 点护盾。","detail_en":"Gain 4 Shield on play.","color":"8ff5cf"},
	{"id":"cycle","icon":"↻","icon_mark":"cycle_arrows","zh":"循环","en":"Cycle","detail":"使用后放到抽牌堆底部。","detail_en":"Place at bottom of draw pile on play.","color":"ffd47c"},
	{"id":"cleanse","icon":"✦","icon_mark":"sparkle","zh":"净化","en":"Cleanse","detail":"使用时移除自身燃烧。","detail_en":"Remove Burn from self on play.","color":"f7f0bd"},
	{"id":"execute","icon":"✕","icon_mark":"cross_blade","zh":"处决","en":"Execute","detail":"目标低于 25% 生命时伤害 +50%。","detail_en":"Deal +50% damage if target is below 25% HP.","color":"ff7373"},
	{"id":"resonance","icon":"◈","icon_mark":"wave","zh":"共鸣","en":"Resonance","detail":"本回合每张同属性牌使数值 +1。","detail_en":"+1 value per same-element card played this turn.","color":"b9a2ff"},
]

const STORE_CONSUMABLES = [
	{
		"id": "elixir_vitality",
		"icon": "🧪",
		"color": "ff7373",
		"zh": "回春灵液", "en": "Elixir of Vitality",
		"detail_zh": "立刻为英雄回复 25 点生命值。", "detail_en": "Immediately restores 25 HP to the hero.",
		"price_gold": 45, "price_jade": 0,
	},
	{
		"id": "elixir_might",
		"icon": "⚔️",
		"color": "ffb359",
		"zh": "狂澜神油", "en": "Draught of Might",
		"detail_zh": "下一场战斗获得 +2 初始力量加成。", "detail_en": "+2 Strength bonus in the next battle.",
		"price_gold": 60, "price_jade": 5,
	},
	{
		"id": "elixir_focus",
		"icon": "💧",
		"color": "78e9ff",
		"zh": "宁神清气露", "en": "Philter of Focus",
		"detail_zh": "下一场战斗首回合抽牌 +2 且能量 +1。", "detail_en": "+2 Draw and +1 Energy on Turn 1 of next battle.",
		"price_gold": 50, "price_jade": 0,
	},
	{
		"id": "upgrade_stone",
		"icon": "💠",
		"color": "ffd700",
		"zh": "炼虚灵石", "en": "Spirit Upgrade Stone",
		"detail_zh": "在商店当场任选牌库中一张卡牌强化 (+1)。", "detail_en": "Immediately upgrade any card in your deck (+1).",
		"price_gold": 140, "price_jade": 15,
	},
	{
		"id": "dust_ore",
		"icon": "❖",
		"color": "c79bff",
		"zh": "灵尘精矿", "en": "Alchemical Dust Ore",
		"detail_zh": "炼金提纯，立即获得 35 灵尘用于卡牌置换。", "detail_en": "Refine into 35 Spirit Dust for Card Exchange.",
		"price_gold": 80, "price_jade": 0,
	}
]

const NOVICE_JOURNEY_TASKS = [
	{
		"day": 1,
		"title_zh": "初入灵界", "title_en": "First Steps",
		"desc_zh": "通关第 1 关（探索前哨）", "desc_en": "Clear Stage 1 (Trailhead Outpost)",
		"gold": 60, "jade": 10, "dust": 15,
		"target_stage": 1,
	},
	{
		"day": 2,
		"title_zh": "灵市见闻", "title_en": "Bazaar Visit",
		"desc_zh": "通关第 2 关（秘境集市）", "desc_en": "Clear Stage 2 (Spirit Bazaar)",
		"gold": 50, "jade": 10, "dust": 25,
		"target_stage": 2,
	},
	{
		"day": 3,
		"title_zh": "诛灭强敌", "title_en": "Elite Triumph",
		"desc_zh": "击败第 3 关强敌险峰", "desc_en": "Defeat the Stage 3 Elite Foe",
		"gold": 80, "jade": 15, "dust": 30,
		"target_stage": 3,
	},
	{
		"day": 4,
		"title_zh": "静修明心", "title_en": "Sacred Campfire",
		"desc_zh": "抵达第 4 关营火静修处", "desc_en": "Reach Stage 4 Sacred Campfire",
		"gold": 70, "jade": 15, "dust": 40,
		"target_stage": 4,
	},
	{
		"day": 5,
		"title_zh": "破晓首胜", "title_en": "Dawn Sovereign",
		"desc_zh": "击败第一章终焉首领（第 5 关）", "desc_en": "Defeat Chapter 1 Boss (Stage 5)",
		"gold": 120, "jade": 30, "dust": 50,
		"target_stage": 5,
	},
	{
		"day": 6,
		"title_zh": "试炼之道", "title_en": "Trial of Valor",
		"desc_zh": "通关第 6 关或参与每日试炼", "desc_en": "Clear Stage 6 or Daily Trial",
		"gold": 100, "jade": 25, "dust": 40,
		"target_stage": 6,
	},
	{
		"day": 7,
		"title_zh": "灵尊大成", "title_en": "Ascendant Grandmaster",
		"desc_zh": "通关第 10 关或击破大首领", "desc_en": "Clear Stage 10 or Great Boss",
		"gold": 200, "jade": 50, "dust": 100,
		"target_stage": 10,
	},
]

const RUNE_SETS = [
	{
		"id": "set_flame",
		"name": "烈焰共鸣",
		"name_en": "Flame Resonance",
		"desc": "命中灼烧目标时造成额外 +3 点伤害。",
		"desc_en": "Attacks against Burning targets deal +3 bonus damage.",
		"runes": ["burning", "execute"],
		"color": "ff784d"
	},
	{
		"id": "set_gale",
		"name": "疾风共鸣",
		"name_en": "Gale Resonance",
		"desc": "每回合首次过牌或循环时回复 1 点能量。",
		"desc_en": "Gain 1 Energy on your first cycle/card-draw each turn.",
		"runes": ["swift", "cycle"],
		"color": "6ee3ff"
	},
	{
		"id": "set_stone",
		"name": "磐石共鸣",
		"name_en": "Stone Resonance",
		"desc": "获得护盾时有 25% 几率使护盾值提升 50%。",
		"desc_en": "25% chance to gain +50% extra Shield on shield actions.",
		"runes": ["guardian", "siphon"],
		"color": "8affc2"
	}
]

func active_rune_sets(card_runes: Dictionary) -> Array:
	var socketed_runes: Array = card_runes.values()
	var active := []
	for s in RUNE_SETS:
		var has_all := true
		for r in s.runes:
			if not socketed_runes.has(r):
				has_all = false
				break
		if has_all:
			active.append(s.id)
	return active

func _init() -> void:
	var file := FileAccess.open("res://data/core.json", FileAccess.READ)
	raw = JSON.parse_string(file.get_as_text())
	cards = raw.cards
	_build_encounters()

func card(id: String) -> Dictionary:
	for value in cards:
		if value.id == id: return value
	return {}

func text(key: String, language := "zh-Hans") -> String:
	return str(raw.translations.get(language, raw.translations.en).get(key, key))

func stage_name(index: int, language := "zh-Hans") -> String:
	var chapter := index / 5
	var level := index % 5
	if language == "zh-Hans": return "%s·%s" % [CHAPTER_NAMES_ZH[chapter], WAYPOINT_ZH[level]]
	return "%s · %s" % [CHAPTER_NAMES_EN[chapter], WAYPOINT_EN[level]]

func chapter_name(chapter: int, language := "zh-Hans") -> String:
	var index: int = clampi(chapter, 0, CHAPTER_NAMES_ZH.size() - 1)
	if language == "zh-Hans": return CHAPTER_NAMES_ZH[index]
	return CHAPTER_NAMES_EN[index]

func chapter_lore(chapter: int, language := "zh-Hans") -> String:
	var index: int = clampi(chapter, 0, CHAPTER_LORE_ZH.size() - 1)
	if language == "zh-Hans": return CHAPTER_LORE_ZH[index]
	return CHAPTER_LORE_EN[index]

func waypoint_name(level: int, language := "zh-Hans") -> String:
	var index: int = clampi(level, 0, WAYPOINT_ZH.size() - 1)
	if language == "zh-Hans": return WAYPOINT_ZH[index]
	return WAYPOINT_EN[index]

func node_kind(index: int) -> String:
	var chapter := index / 5 + 1
	var level := index % 5 + 1
	# Every chapter ends on a boss; every tenth chapter ends on a great boss instead.
	if level == 5: return "greatboss" if chapter % 10 == 0 else "boss"
	if level == 3: return "elite"
	if level == 2: return "event" if (index / 5) % 2 == 0 else "merchant"
	if level == 4: return "rest"
	return "battle"

func is_boss_kind(kind: String) -> bool:
	return kind == "boss" or kind == "greatboss"

# Boss Rush reuses the real campaign encounter for each boss stage the player has already
# reached, rather than a synthetic stat block, so it's a genuine "refight the bosses you've
# already beaten" mode — gated to `unlocked` so it never spoils or trivializes bosses ahead of
# where the player actually is.
func boss_rush_boss_indices(unlocked: int) -> Array:
	var out: Array = []
	for i in mini(unlocked + 1, encounters.size()):
		if is_boss_kind(node_kind(i)): out.append(i)
	return out

const HERO_CLASSES = [
	{
		"id": "fox_spirit",
		"name": "灵狐行者",
		"name_en": "Fox Spirit",
		"desc": "掌控灵火与疾风的敏捷行者。擅长灵火连击与爆发回响。",
		"desc_en": "Agile master of foxfire and gale. Excels at flame combos and echo bursts.",
		"sprite": "hero_fox_spirit",
		"relic": "foxCharm",
		"deck": [
			"strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike",
			"ward", "ward", "ward", "ward", "ward", "ward", "ward", "ward",
			"foxfire", "foxfire", "foxfire",
			"wildSpark", "wildSpark"
		]
	},
	{
		"id": "stone_sentinel",
		"name": "岩铠卫士",
		"name_en": "Stone Sentinel",
		"desc": "坚若磐石的古代护卫。擅长重甲防御、护盾转化与反击。",
		"desc_en": "Immovable ancient guardian. Specializes in heavy armor, shield conversion and counter-strike.",
		"sprite": "hero_stone_sentinel",
		"relic": "ancientSeed",
		"deck": [
			"strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike",
			"ward", "ward", "ward", "ward", "ward", "ward", "ward", "ward", "ward", "ward", "ward", "ward",
			"stoneBreaker", "stoneBreaker",
			"ironHide"
		]
	},
	{
		"id": "shadow_stalker",
		"name": "夜影刺客",
		"name_en": "Shadow Stalker",
		"desc": "潜行于暗影中的致命杀手。擅长易伤诅咒、暴击斩杀与毒火流血。",
		"desc_en": "Lethal stalker of shadows. Specializes in vulnerability curses, critical executions, and bleed.",
		"sprite": "hero_shadow_stalker",
		"relic": "starShard",
		"deck": [
			"strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike",
			"ward", "ward", "ward", "ward", "ward", "ward", "ward", "ward",
			"moonfang", "moonfang",
			"cinderHex"
		]
	},
	{
		"id": "miasma_witch",
		"name": "瘴气巫女",
		"name_en": "Miasma Witch",
		"desc": "操控剧毒瘴气的诡异法师，让敌人在持续侵蚀中衰竭。擅长毒素叠加与资源回收。",
		"desc_en": "An eerie mage who commands toxic miasma, wearing enemies down through relentless decay. Specializes in stacking Poison and recycling resources.",
		"sprite": "hero_miasma_witch",
		"relic": "bloodJade",
		"deck": [
			"strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike",
			"ward", "ward", "ward", "ward", "ward", "ward", "ward", "ward",
			"toxinDart", "toxinDart", "toxinDart",
			"witherTouch", "witherTouch",
			"miasmaBrew"
		]
	}
]

const ABYSS_BOONS = [
	{
		"id": "boon_blood_lust",
		"nameKey": "boon.blood_lust.name",
		"descKey": "boon.blood_lust.desc",
		"icon": "♥",
		"color": "ff5c5c",
		"type": "heal_on_kill",
		"value": 8
	},
	{
		"id": "boon_iron_core",
		"nameKey": "boon.iron_core.name",
		"descKey": "boon.iron_core.desc",
		"icon": "⬢",
		"color": "7ec9ff",
		"type": "shield_turn_start",
		"value": 5
	},
	{
		"id": "boon_spirit_surge",
		"nameKey": "boon.spirit_surge.name",
		"descKey": "boon.spirit_surge.desc",
		"icon": "⚡",
		"color": "ffe175",
		"type": "first_attack_bonus",
		"value": 4
	},
	{
		"id": "boon_flame_affinity",
		"nameKey": "boon.flame_affinity.name",
		"descKey": "boon.flame_affinity.desc",
		"icon": "♨",
		"color": "ff944d",
		"type": "burn_boost",
		"value": 2
	},
	{
		"id": "boon_wind_stride",
		"nameKey": "boon.wind_stride.name",
		"descKey": "boon.wind_stride.desc",
		"icon": "༄",
		"color": "82f7c0",
		"type": "draw_turn_start",
		"value": 1
	},
	{
		"id": "boon_golden_fortune",
		"nameKey": "boon.golden_fortune.name",
		"descKey": "boon.golden_fortune.desc",
		"icon": "◆",
		"color": "ffd859",
		"type": "gold_boost",
		"value": 50
	}
]

func abyss_boon(id: String) -> Dictionary:
	for b in ABYSS_BOONS:
		if b.id == id: return b
	return {}

# Hero Mastery: every battle won with a hero equipped earns that hero XP (see
# game.gd's _grant_mastery_xp), climbing a permanent Lv1-5 track. Each level adds one
# always-on perk to a small, reusable vocabulary of battle-start/first-attack/per-turn hooks
# combat.gd already has hooks for (max_hp mirrors titanBell, shield_start mirrors jadePlate,
# first_attack_bonus mirrors emberBlade/starShard, heal_per_turn mirrors ancientSeed,
# burn_start/vulnerable_start are the one new pair, applied once at battle start) — so a new
# hero never needs new engine code, only a new row in HERO_MASTERY_PERKS. Levels are
# cumulative: mastery_bonuses() sums every perk at or below the reached level, so Lv5 carries
# everything Lv1-4 already granted plus its own.
# Achievements: a permanent, never-reset counterpart to the daily/weekly quest system.
# "stat" achievements read profile.lifetime_stats[stat] — a running total game.gd bumps
# alongside the existing period-scoped quest progress every time _advance_quest() fires, so
# no new event-hook call sites were needed anywhere in combat/reward code. The other "kind"
# values read an existing profile field directly (mastery level, abyss record, daily trial
# badges, compendium %, relic count, distinct cards owned) since those are already permanent
# running totals with nothing to duplicate.
const ACHIEVEMENT_TIERS = ["bronze", "silver", "gold", "platinum"]

const ACHIEVEMENTS = [
	{"id":"win10","kind":"stat","stat":"win_battles","target":10,"tier":"bronze","nameKey":"ach.win10.name","descKey":"ach.win10.desc"},
	{"id":"win50","kind":"stat","stat":"win_battles","target":50,"tier":"silver","nameKey":"ach.win50.name","descKey":"ach.win50.desc"},
	{"id":"win200","kind":"stat","stat":"win_battles","target":200,"tier":"gold","nameKey":"ach.win200.name","descKey":"ach.win200.desc"},
	{"id":"damage10k","kind":"stat","stat":"deal_damage","target":10000,"tier":"bronze","nameKey":"ach.damage10k.name","descKey":"ach.damage10k.desc"},
	{"id":"damage100k","kind":"stat","stat":"deal_damage","target":100000,"tier":"gold","nameKey":"ach.damage100k.name","descKey":"ach.damage100k.desc"},
	{"id":"chest10","kind":"stat","stat":"open_chest","target":10,"tier":"bronze","nameKey":"ach.chest10.name","descKey":"ach.chest10.desc"},
	{"id":"shop20","kind":"stat","stat":"shop_purchase","target":20,"tier":"bronze","nameKey":"ach.shop20.name","descKey":"ach.shop20.desc"},
	{"id":"gold1000","kind":"stat","stat":"earn_gold","target":1000,"tier":"bronze","nameKey":"ach.gold1000.name","descKey":"ach.gold1000.desc"},
	{"id":"gold10000","kind":"stat","stat":"earn_gold","target":10000,"tier":"silver","nameKey":"ach.gold10000.name","descKey":"ach.gold10000.desc"},
	{"id":"elite_boss20","kind":"stat","stat":"clear_elite_or_boss","target":20,"tier":"silver","nameKey":"ach.elite_boss20.name","descKey":"ach.elite_boss20.desc"},
	{"id":"greatboss5","kind":"stat","stat":"defeat_great_boss","target":5,"tier":"gold","nameKey":"ach.greatboss5.name","descKey":"ach.greatboss5.desc"},
	{"id":"rune_play50","kind":"stat","stat":"play_runed_cards","target":50,"tier":"silver","nameKey":"ach.rune_play50.name","descKey":"ach.rune_play50.desc"},
	{"id":"collect20","kind":"card_collection","target":20,"tier":"bronze","nameKey":"ach.collect20.name","descKey":"ach.collect20.desc"},
	# target must equal the number of non-Curse cards (profile.collection can never hold a
	# Curse id — see AGENTS.md's Curse cards note — so that's the true max achievable value).
	# This has drifted silently before as cards were added; test_runner.gd now asserts this
	# target against the live count so a future addition fails loudly instead of quietly
	# making "collect all" completable early.
	{"id":"collect_all","kind":"card_collection","target":45,"tier":"platinum","nameKey":"ach.collect_all.name","descKey":"ach.collect_all.desc"},
	{"id":"relics_all","kind":"relic_count","target":11,"tier":"platinum","nameKey":"ach.relics_all.name","descKey":"ach.relics_all.desc"},
	{"id":"mastery5","kind":"mastery_level","target":5,"tier":"gold","nameKey":"ach.mastery5.name","descKey":"ach.mastery5.desc"},
	{"id":"abyss10","kind":"abyss_floor","target":10,"tier":"silver","nameKey":"ach.abyss10.name","descKey":"ach.abyss10.desc"},
	{"id":"abyss30","kind":"abyss_floor","target":30,"tier":"platinum","nameKey":"ach.abyss30.name","descKey":"ach.abyss30.desc"},
	{"id":"trial_badges5","kind":"daily_trial_badges","target":5,"tier":"bronze","nameKey":"ach.trial_badges5.name","descKey":"ach.trial_badges5.desc"},
	{"id":"trial_badges20","kind":"daily_trial_badges","target":20,"tier":"gold","nameKey":"ach.trial_badges20.name","descKey":"ach.trial_badges20.desc"},
	{"id":"compendium50","kind":"compendium_percent","target":50,"tier":"silver","nameKey":"ach.compendium50.name","descKey":"ach.compendium50.desc"},
	{"id":"compendium100","kind":"compendium_percent","target":100,"tier":"platinum","nameKey":"ach.compendium100.name","descKey":"ach.compendium100.desc"},
]

const HERO_MASTERY_XP_FOR_LEVEL = [60, 150, 300, 500, 800]

const HERO_MASTERY_PERKS = {
	"fox_spirit": [
		{"level":1,"kind":"energy_turn1","value":1,"nameKey":"mastery.fox.1.name","descKey":"mastery.fox.1.desc"},
		{"level":2,"kind":"max_hp","value":4,"nameKey":"mastery.fox.2.name","descKey":"mastery.fox.2.desc"},
		{"level":3,"kind":"first_attack_bonus","value":2,"nameKey":"mastery.fox.3.name","descKey":"mastery.fox.3.desc"},
		{"level":4,"kind":"burn_start","value":1,"nameKey":"mastery.fox.4.name","descKey":"mastery.fox.4.desc"},
		{"level":5,"kind":"first_attack_bonus","value":3,"nameKey":"mastery.fox.5.name","descKey":"mastery.fox.5.desc"},
	],
	"stone_sentinel": [
		{"level":1,"kind":"max_hp","value":6,"nameKey":"mastery.stone.1.name","descKey":"mastery.stone.1.desc"},
		{"level":2,"kind":"shield_start","value":5,"nameKey":"mastery.stone.2.name","descKey":"mastery.stone.2.desc"},
		{"level":3,"kind":"heal_per_turn","value":1,"nameKey":"mastery.stone.3.name","descKey":"mastery.stone.3.desc"},
		{"level":4,"kind":"shield_start","value":7,"nameKey":"mastery.stone.4.name","descKey":"mastery.stone.4.desc"},
		{"level":5,"kind":"max_hp","value":10,"nameKey":"mastery.stone.5.name","descKey":"mastery.stone.5.desc"},
	],
	"shadow_stalker": [
		{"level":1,"kind":"max_hp","value":4,"nameKey":"mastery.shadow.1.name","descKey":"mastery.shadow.1.desc"},
		{"level":2,"kind":"vulnerable_start","value":1,"nameKey":"mastery.shadow.2.name","descKey":"mastery.shadow.2.desc"},
		{"level":3,"kind":"first_attack_bonus","value":3,"nameKey":"mastery.shadow.3.name","descKey":"mastery.shadow.3.desc"},
		{"level":4,"kind":"vulnerable_start","value":1,"nameKey":"mastery.shadow.4.name","descKey":"mastery.shadow.4.desc"},
		{"level":5,"kind":"first_attack_bonus","value":4,"nameKey":"mastery.shadow.5.name","descKey":"mastery.shadow.5.desc"},
	],
	"miasma_witch": [
		{"level":1,"kind":"max_hp","value":4,"nameKey":"mastery.miasma.1.name","descKey":"mastery.miasma.1.desc"},
		{"level":2,"kind":"poison_start","value":1,"nameKey":"mastery.miasma.2.name","descKey":"mastery.miasma.2.desc"},
		{"level":3,"kind":"first_attack_bonus","value":2,"nameKey":"mastery.miasma.3.name","descKey":"mastery.miasma.3.desc"},
		{"level":4,"kind":"poison_start","value":1,"nameKey":"mastery.miasma.4.name","descKey":"mastery.miasma.4.desc"},
		{"level":5,"kind":"first_attack_bonus","value":3,"nameKey":"mastery.miasma.5.name","descKey":"mastery.miasma.5.desc"},
	],
}

# Level 0 (no perks at all) is the real starting point for a brand-new hero — combat.gd's
# "turn 1 is strictly 2 energy" and similar invariants (see AGENTS.md) must hold with zero
# mastery investment, so every threshold below is a positive xp cost, never free at 0 xp.
func mastery_level_for_xp(xp: int) -> int:
	var level := 0
	for l in range(1, 6):
		if xp >= HERO_MASTERY_XP_FOR_LEVEL[l - 1]: level = l
	return level

# xp required to REACH a level (level 1 is free, at 0 xp); -1 outside 1..5.
func mastery_xp_for_level(level: int) -> int:
	if level < 1 or level > 5: return -1
	return HERO_MASTERY_XP_FOR_LEVEL[level - 1]

func mastery_perk(hero_id: String, level: int) -> Dictionary:
	for p in HERO_MASTERY_PERKS.get(hero_id, []):
		if int(p.level) == level: return p
	return {}

func mastery_bonuses(hero_id: String, level: int) -> Dictionary:
	var result := {}
	for p in HERO_MASTERY_PERKS.get(hero_id, []):
		if int(p.level) > level: continue
		var kind: String = str(p.kind)
		result[kind] = int(result.get(kind, 0)) + int(p.value)
	return result

# C2: 轮回 (Rebirth) — a prestige loop for players who've cleared the full 250-stage campaign
# at the hardest tier (see game_camp_screen.gd's _rebirth_section() for the exact eligibility
# check). Each cycle grants a small permanent combat bonus through the same hero_bonuses hook
# hero mastery perks already use (combat.gd's max_hp/shield_start handling), so no new engine
# surface was needed for the reward itself — only the reset flow is new.
const REBIRTH_MAX_HP_PER_CYCLE = 3
const REBIRTH_SHIELD_PER_CYCLE = 1

func rebirth_bonuses(count: int) -> Dictionary:
	if count <= 0: return {}
	return {"max_hp": count * REBIRTH_MAX_HP_PER_CYCLE, "shield_start": count * REBIRTH_SHIELD_PER_CYCLE}

# Daily Seeded Trial: a 15-stage gauntlet, independent of campaign progress, that resets at
# the same day boundary as the daily quests (game.gd's DAY_SECONDS). Every device rolling
# over on the same day picks the same 3-tag trio and fights the same seeded battles, same
# deterministic-per-period approach as roll_quests()/roll_shop_stock() above. Each tag maps
# to exactly one combat.gd modifier key, so combining up to 3 of these 5 is always a plain
# dictionary union — never two tags fighting over the same key.
const DAILY_TRIAL_STAGES = 15
# E1: bounds daily_trial_record.history so the trend chart's local-only data can't grow
# without limit over months of play — a month's worth is plenty for a "recent trend" read.
const DAILY_TRIAL_HISTORY_LIMIT = 30

const DAILY_TRIAL_TAGS = [
	{"id":"double_damage","nameKey":"trial.tag.double_damage.name","descKey":"trial.tag.double_damage.desc","damage_mult":2.0},
	{"id":"juggernaut","nameKey":"trial.tag.juggernaut.name","descKey":"trial.tag.juggernaut.desc","health_scale":1.75},
	{"id":"swarm","nameKey":"trial.tag.swarm.name","descKey":"trial.tag.swarm.desc","extra_enemy":1},
	{"id":"undying","nameKey":"trial.tag.undying.name","descKey":"trial.tag.undying.desc","revive":0.5},
	{"id":"frenzy","nameKey":"trial.tag.frenzy.name","descKey":"trial.tag.frenzy.desc","damage_bonus":5},
]

func daily_trial_tags(day_seed: int) -> Array:
	var indices := _shuffled_indices(DAILY_TRIAL_TAGS.size(), day_seed + 555)
	var picked: Array = []
	for i in mini(3, indices.size()): picked.append(DAILY_TRIAL_TAGS[indices[i]])
	return picked

# Same shape as the campaign's _modifier() options in game.gd (name/name_en/detail/detail_en
# alongside the actual combat.gd keys) — show_battle()'s modifier badge reads those four
# fields unconditionally, so a trio with no display text would read a null property off this
# dictionary and crash the battle screen the moment a Daily Trial run started.
func daily_trial_modifier(day_seed: int) -> Dictionary:
	var tags: Array = daily_trial_tags(day_seed)
	var mod := {}
	for tag in tags:
		for key in tag:
			if key in ["id", "nameKey", "descKey"]: continue
			mod[key] = tag[key]
	var names_zh: Array = []
	var names_en: Array = []
	var descs_zh: Array = []
	var descs_en: Array = []
	for tag in tags:
		names_zh.append(ui(tag.nameKey, "zh-Hans"))
		names_en.append(ui(tag.nameKey, "en"))
		descs_zh.append(ui(tag.descKey, "zh-Hans"))
		descs_en.append(ui(tag.descKey, "en"))
	mod["name"] = "、".join(names_zh)
	mod["name_en"] = ", ".join(names_en)
	mod["detail"] = "；".join(descs_zh)
	mod["detail_en"] = "; ".join(descs_en)
	return mod

# Purely a function of the stage index (1-based), not the day seed — the trio of tags above
# is what makes a given day distinct, while the base gauntlet itself stays a fair, predictable
# 15-stage curve every player climbs the same way.
func daily_trial_encounter(stage: int) -> Dictionary:
	var enemy: Dictionary = ENEMIES[(stage - 1) % ENEMIES.size()]
	return {
		"chapter": 100, "level": stage,
		"health": 30 + stage * 14,
		"damage": 6 + int(stage * 1.8),
		"reward": 20 + stage * 6,
		"name": enemy.name, "name_en": enemy.get("name_en", enemy.name), "art": enemy.art,
		"mechanics": {"shield_per_turn": 4, "critical_every": 3, "enrage": 1} if stage >= DAILY_TRIAL_STAGES else ({"shield_per_turn": 3} if stage >= 8 else {}),
		"adds": 1 if stage % 4 == 0 else 0,
		"background": (stage - 1) % 5
	}

# Weekly Theme Challenge (B3): reuses the Daily Trial's deterministic-per-period tag engine
# above, but at a weekly cadence and with exactly one themed modifier instead of a combined
# trio — "本周主题" reads as one clear theme, not a grab-bag. A shorter 8-stage gauntlet (vs
# the daily trial's 15) keeps it a single-sitting weekly event rather than a second daily grind.
const WEEKLY_CHALLENGE_STAGES = 8

const WEEKLY_CHALLENGE_TAGS = [
	{"id":"iron_horde","nameKey":"weekly.tag.iron_horde.name","descKey":"weekly.tag.iron_horde.desc","health_scale":1.6},
	{"id":"savage_tide","nameKey":"weekly.tag.savage_tide.name","descKey":"weekly.tag.savage_tide.desc","damage_mult":1.6},
	{"id":"twin_pack","nameKey":"weekly.tag.twin_pack.name","descKey":"weekly.tag.twin_pack.desc","extra_enemy":1},
	{"id":"bounty_week","nameKey":"weekly.tag.bounty_week.name","descKey":"weekly.tag.bounty_week.desc","reward_mult":2.0},
]

func weekly_challenge_tag(week_seed: int) -> Dictionary:
	var indices := _shuffled_indices(WEEKLY_CHALLENGE_TAGS.size(), week_seed + 9001)
	return WEEKLY_CHALLENGE_TAGS[indices[0]]

# Same shape rule as daily_trial_modifier: show_battle()'s modifier badge reads name/name_en/
# detail/detail_en unconditionally, so this always carries all four even for a single tag.
# reward_mult is not a combat.gd key (nothing there reads gold) — game.gd's weekly-challenge
# reward code reads it directly off active_modifier instead, same as reward_scale already
# works for the campaign's own random encounter modifiers.
func weekly_challenge_modifier(week_seed: int) -> Dictionary:
	var tag: Dictionary = weekly_challenge_tag(week_seed)
	var mod := {}
	for key in tag:
		if key in ["id", "nameKey", "descKey"]: continue
		mod[key] = tag[key]
	mod["name"] = ui(tag.nameKey, "zh-Hans")
	mod["name_en"] = ui(tag.nameKey, "en")
	mod["detail"] = ui(tag.descKey, "zh-Hans")
	mod["detail_en"] = ui(tag.descKey, "en")
	return mod

# Purely a function of stage index, like daily_trial_encounter — steeper curve than the daily
# trial's since there are only 8 stages to build tension across instead of 15.
func weekly_challenge_encounter(stage: int) -> Dictionary:
	var enemy: Dictionary = ENEMIES[(stage - 1) % ENEMIES.size()]
	return {
		"chapter": 101, "level": stage,
		"health": 40 + stage * 20,
		"damage": 8 + int(stage * 2.4),
		"reward": 30 + stage * 10,
		"name": enemy.name, "name_en": enemy.get("name_en", enemy.name), "art": enemy.art,
		"mechanics": {"shield_per_turn": 4, "critical_every": 3, "enrage": 1} if stage >= WEEKLY_CHALLENGE_STAGES else ({"shield_per_turn": 3} if stage >= 5 else {}),
		"adds": 1 if stage % 3 == 0 else 0,
		"background": (stage - 1) % 5
	}

const PHANTOM_CULTIVATORS = [
	{"name": "青云剑修 · 虚影", "name_en": "Qingyun Swordsman · Phantom", "art": "sentinel", "mechanics": {"critical_every": 3}},
	{"name": "拜月圣女 · 虚影", "name_en": "Moon Maiden · Phantom", "art": "runebound", "mechanics": {"shield_per_turn": 5}},
	{"name": "狂刀行者 · 虚影", "name_en": "Blade Walker · Phantom", "art": "embercliff", "mechanics": {"enrage": 2}},
	{"name": "百草灵修 · 虚影", "name_en": "Herbal Cultivator · Phantom", "art": "fox", "mechanics": {"regeneration": 4}},
]

func phantom_arena_encounter(unlocked: int, seed_idx: int = 0) -> Dictionary:
	var phantom: Dictionary = PHANTOM_CULTIVATORS[abs(seed_idx) % PHANTOM_CULTIVATORS.size()]
	var effective_stage := clampi(unlocked, 1, 250)
	return {
		"chapter": 102, "level": effective_stage,
		"health": 35 + effective_stage * 12,
		"damage": 6 + int(effective_stage * 1.5),
		"reward": 40 + effective_stage * 5,
		"name": phantom.name, "name_en": phantom.name_en, "art": phantom.art,
		"mechanics": phantom.mechanics,
		"adds": 0,
		"background": 2
	}

func hero_class(id: String) -> Dictionary:
	for h in HERO_CLASSES:
		if h.id == id: return h
	return HERO_CLASSES[0]

func hero_name(h: Dictionary, language := "zh-Hans") -> String:
	return str(h.get("name_en" if language == "en" else "name", h.get("id", "")))

func hero_desc(h: Dictionary, language := "zh-Hans") -> String:
	return str(h.get("desc_en" if language == "en" else "desc", ""))

func abyss_encounter(floor: int) -> Dictionary:
	var hp: int = 45 + floor * 12
	var dmg: int = 7 + int(floor * 1.5)
	var adds: int = 1 if floor % 3 == 0 else (2 if floor % 7 == 0 else 0)
	var bgs: int = floor % 5
	return {
		"chapter": 99,
		"level": floor,
		"health": hp,
		"damage": dmg,
		"reward": 25 + floor * 5,
		"name": "深渊守卫 · 层%d" % floor,
		"art": "sentinel-v1.jpg",
		"mechanics": {"shield_per_turn": 3} if floor > 5 else {},
		"adds": adds,
		"background": bgs
	}

func equipment(id: String) -> Dictionary:
	for item in EQUIPMENT:
		if item.id == id: return item
	return {}

func rune(id: String) -> Dictionary:
	for item in RUNES:
		if item.id == id: return item
	return {}

func relic(id: String) -> Dictionary:
	for item in RELICS:
		if item.id == id: return item
	return {}

func relic_name(item: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return item.get("en", item.get("zh", ""))
	return item.get("zh", "")

func relic_detail(item: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return item.get("detail_en", item.get("detail", ""))
	return item.get("detail", "")

func store_consumable(id: String) -> Dictionary:
	for item in STORE_CONSUMABLES:
		if item.id == id: return item
	return {}

func quest_by_id(id: String) -> Dictionary:
	for q in DAILY_QUESTS:
		if q.id == id: return q
	for q in WEEKLY_QUESTS:
		if q.id == id: return q
	return {}

func quest_name(quest: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return quest.get("en", quest.get("zh", ""))
	return quest.get("zh", "")

# Deterministic per period so every device rolling over at the same reset time gets the
# same three quests that day/week, rather than fresh randomness on every reroll call.
func _shuffled_indices(size: int, seed_value: int) -> Array:
	var indices: Array = range(size)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(indices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = indices[i]; indices[i] = indices[j]; indices[j] = tmp
	return indices

func roll_quests(catalog: Array, count: int, period_seed: int) -> Array:
	var indices := _shuffled_indices(catalog.size(), period_seed)
	var picked: Array = []
	for i in mini(count, indices.size()):
		var q: Dictionary = catalog[indices[i]].duplicate()
		q["progress"] = 0
		q["claimed"] = false
		picked.append(q)
	return picked

func is_card_soulbound(card_id: String) -> bool:
	return card_id == "strike" or card_id == "ward"

func card_recycle_dust_value(card: Dictionary) -> int:
	if is_card_soulbound(str(card.get("id", ""))): return 0
	var rarity: String = str(card.get("rarity", "Common"))
	match rarity:
		"Rare": return 120
		"Uncommon": return 40
		_: return 15

func card_craft_dust_cost(card: Dictionary) -> int:
	var rarity: String = str(card.get("rarity", "Common"))
	match rarity:
		"Rare": return 300
		"Uncommon": return 100
		_: return 40

# Same deterministic-per-day approach as quests: every device sees the same stock and the
# same discounted slot until the next reset, rather than a fresh random shuffle on every
# visit to the shop.
func roll_shop_stock(day_seed: int, count: int) -> Dictionary:
	var pool: Array = cards.filter(func(c): return c.rarity != "Starter" and c.get("rarity", "") != "Curse")
	var indices := _shuffled_indices(pool.size(), day_seed)
	var picked: Array = []
	for i in mini(count, indices.size()): picked.append(pool[indices[i]])
	var rng := RandomNumberGenerator.new()
	rng.seed = day_seed + 777
	var sale_index: int = rng.randi_range(0, maxi(0, picked.size() - 1))
	
	# Rotating shop rune (picks from non-empty RUNES)
	var rune_indices := _shuffled_indices(RUNES.size(), day_seed + 101)
	var shop_rune: Dictionary = RUNES[rune_indices[0]] if not RUNES.is_empty() else {}
	
	# Rotating non-boss relic
	var regular_relics: Array = RELICS.filter(func(r): return not BOSS_RELIC_IDS.has(r.id))
	var relic_indices := _shuffled_indices(regular_relics.size(), day_seed + 202)
	var shop_relic: Dictionary = regular_relics[relic_indices[0]] if not regular_relics.is_empty() else {}
	
	# Mystery Spirit Pack
	var booster_pack := {
		"id": "spirit_pack",
		"price_gold": 120,
		"price_jade": 12,
	}
	
	return {
		"cards": picked,
		"sale_index": sale_index,
		"rune": shop_rune,
		"relic": shop_relic,
		"booster_pack": booster_pack
	}

# Four difficulty bands across 50 chapters (250 stages), each ending at a chapter boundary
# so the numbers line up with what a player actually experiences one chapter at a time:
#   1-4   (stages   1- 20): trivial, clearable on autopilot.
#   5-10  (stages  21- 50): card sequencing starts to matter.
#   11-20 (stages  51-100): needs a deliberately built deck.
#   21-50 (stages 101-250): needs runes/equipment/relics from earlier farming, not skill alone.
# Tuned against tests/balance_probe.gd — see Docs/ARCHITECTURE.md for the win-rate curve
# that came out of it and why these constants ended up where they did. Band 3's 0.16 (was
# 0.22 until the 2026-09-17 revalidation) is the fixed value — see that section and
# test_runner.gd's own pinning assertion for what the old value broke.
const BAND_1_END = 4
const BAND_2_END = 10
const BAND_3_END = 20

func _chapter_factor(chapter: int) -> float:
	if chapter <= BAND_1_END:
		return 1.0 + float(chapter - 1) * 0.08
	if chapter <= BAND_2_END:
		var base_a: float = 1.0 + float(BAND_1_END - 1) * 0.08
		return base_a + float(chapter - BAND_1_END) * 0.12
	if chapter <= BAND_3_END:
		var base_b: float = _chapter_factor(BAND_2_END)
		return base_b + float(chapter - BAND_2_END) * 0.16
	var base_c: float = _chapter_factor(BAND_3_END)
	return base_c * pow(1.062, float(chapter - BAND_3_END))

# C2 follow-up (2026-09-17): profile.difficulty (the A0-A5+ ladder in Camp) previously had
# zero effect on actual combat, despite ui.camp_desc's own "更高挑战提高敌人生命与伤害"
# ("higher tiers increase enemy HP & damage") claiming otherwise — it only ever shifted which
# boss-equipment/elite-rune drops rotate to (_grant_stage_rewards()), a reward-variety knob,
# not a difficulty one. Wired here for real. Extended past the old A5 ceiling to support C2's
# Rebirth (轮回): each rebirth cycle raises the max selectable tier by one (see
# _rebirth_section()'s "5 + rebirth_count" eligibility, game_camp_screen.gd), so the escalating
# tier ladder is now an actual escalating challenge ladder, not a cosmetic one, and Rebirth has
# somewhere real to send a player who has run out of harder content otherwise.
# Tier 0 (A0) is deliberately a no-op: tests/balance_probe.gd's revalidation (see
# Docs/ARCHITECTURE.md) validated the base curve at zero extra scaling, and every existing
# save already defaults to difficulty 0 — this must never retroactively make the validated
# baseline harder.
func difficulty_modifier(tier: int) -> Dictionary:
	if tier <= 0: return {}
	var hp_pct: int = int(round(float(tier) * 12.0))
	var gold_pct: int = int(round(float(tier) * 10.0))
	# Bilingual name/detail built directly into the dict rather than routed through UI_TEXT,
	# matching game_battle_screen.gd's own _modifier() flavor-modifier pool and
	# daily_trial_modifier()'s tag-synthesized text — both are procedurally generated content,
	# not fixed static labels, so they carry both languages inline for the caller to pick from.
	return {
		"health_scale": 1.0 + float(tier) * 0.12, "damage_bonus": tier, "reward_scale": 1.0 + float(tier) * 0.1,
		"name": "挑战等级 A%d" % tier, "name_en": "Challenge Tier A%d" % tier,
		"detail": "敌人生命 +%d%%，伤害 +%d，金币 +%d%%" % [hp_pct, tier, gold_pct],
		"detail_en": "Enemy HP +%d%%, damage +%d, gold +%d%%" % [hp_pct, tier, gold_pct],
	}

func _chapter_mechanics(chapter: int, is_great_boss: bool) -> Dictionary:
	if chapter <= 2: return {}
	if is_great_boss:
		# Every 10th chapter combines three mechanics at once, scaling with the arc — the
		# five great bosses are meant to be the hardest single fight in their neighborhood.
		var tier: int = chapter / 10
		return {"shield_per_turn": 2 + tier, "critical_every": maxi(2, 4 - tier), "below_half": 2 + tier, "enrage": tier}
	var band: int = 0
	if chapter <= BAND_2_END: band = 1
	elif chapter <= BAND_3_END: band = 2
	else: band = 3
	var archetypes := ["critical", "shield", "thorns", "regen", "dodge", "enrage"]
	match archetypes[(chapter - 1) % archetypes.size()]:
		"critical": return {"critical_every": maxi(2, 4 - band)}
		"shield": return {"shield_per_turn": 3 + band * 2}
		"thorns": return {"thorns": 1 + band}
		"regen": return {"regeneration": 2 + band * 2}
		"dodge": return {"dodge_every": maxi(2, 4 - band)}
		"enrage": return {"enrage": 1 + band}
	return {}

func _chapter_adds(chapter: int, level: int, is_great_boss: bool) -> int:
	var adds := 0
	if level == 3:
		# Elites: a real group fight from the deckbuilding band onward, which is exactly
		# why the cleave finishers (stormArc/worldFlame/spiritNova) exist. The second add used
		# to start at chapter 15 — square in the middle of Band 3, where it stacked with that
		# band's own steep per-chapter growth into an unwinnable wall (see the 2026-09-17
		# revalidation note above _chapter_factor). Moved to chapter 21, Band 4's own start,
		# where a second add is already part of what "needs farmed gear" means.
		if chapter >= 3: adds += 1
		if chapter >= 21: adds += 1
		if chapter >= 35: adds += 1
	elif level in [1, 2]:
		if chapter >= 6: adds += 1
		if chapter >= 25: adds += 1
	elif level == 5:
		if chapter >= 5: adds += 1
		if is_great_boss: adds += 1
		if chapter >= 40: adds += 1
	return adds

func _build_encounters() -> void:
	var chapter_count: int = CHAPTER_NAMES_ZH.size()
	for index in chapter_count * 5:
		var chapter: int = index / 5 + 1
		var level := index % 5 + 1
		var enemy: Dictionary = ENEMIES[(chapter + level - 2) % ENEMIES.size()]
		var is_great_boss: bool = level == 5 and chapter % 10 == 0
		var mechanics := _chapter_mechanics(chapter, is_great_boss)
		var adds := _chapter_adds(chapter, level, is_great_boss)
		var factor: float = _chapter_factor(chapter)
		var level_health: float = 1.0 + float(level - 1) * 0.12
		var level_damage: float = 1.0 + float(level - 1) * 0.10
		encounters.append({
			"chapter":chapter,"level":level,
			"health":maxi(6, int(round(28.0 * factor * level_health))),
			"damage":maxi(2, int(round(4.0 * factor * level_damage))),
			"reward":int(round(16.0 + float(chapter) * 5.0 + float(level) * 2.0 + factor * 4.0)),
			"name":enemy.name,"name_en":enemy.get("name_en", enemy.name),"art":enemy.art,
			"mechanics":mechanics,"adds":adds,"background":(chapter - 1) % 5
		})

const UI_TEXT = {
	"ui.choose_dest": {"zh-Hans":"沿灵迹选择目的地", "en":"Follow the spirit trail"},
	"ui.lang_toggle": {"zh-Hans":"中/EN", "en":"EN/中"},
	"ui.deck_btn": {"zh-Hans":"牌组", "en":"Deck"},
	"ui.equip_btn": {"zh-Hans":"装备", "en":"Gear"},
	"ui.trial_btn": {"zh-Hans":"试炼", "en":"Trials"},
	"ui.shop_btn": {"zh-Hans":"商店", "en":"Shop"},
	"ui.next_btn": {"zh-Hans":"下一关", "en":"Next"},
	"ui.chapter_n": {"zh-Hans":"第%d大关 · %s", "en":"Chapter %d · %s"},
	"ui.turn_n": {"zh-Hans":"回合 %d", "en":"Turn %d"},
	"ui.draw_pile": {"zh-Hans":"抽牌", "en":"Draw"},
	"ui.discard_pile": {"zh-Hans":"弃牌", "en":"Discard"},
	"ui.exhaust_pile": {"zh-Hans":"消耗", "en":"Exhaust"},
	"ui.spirit_name": {"zh-Hans":"绯狐", "en":"Crimson Fox"},
	"ui.player_status": {"zh-Hans":"%s   ♥ %d/60   ◆ 护盾 %d", "en":"%s   ♥ %d/60   ◆ Shield %d"},
	"ui.energy_actions": {"zh-Hans":"能量 %d    本回合还可出牌 %d", "en":"Energy %d    %d plays remaining"},
	"ui.end_turn": {"zh-Hans":"结束回合", "en":"End Turn"},
	"ui.battle_won": {"zh-Hans":"战斗胜利", "en":"Victory"},
	"ui.battle_lost": {"zh-Hans":"远征失败", "en":"Expedition Failed"},
	"ui.open_chest": {"zh-Hans":"打开胜利宝箱", "en":"Open Victory Chest"},
	"ui.return_map": {"zh-Hans":"返回地图", "en":"Return to Map"},
	"ui.drag_hint": {"zh-Hans":"拖出卡牌使用 · 伤害牌拖到敌人，增益牌可拖到空白处", "en":"Drag cards to play · Drag attacks onto enemies, buffs anywhere"},
	"ui.target_invalid": {"zh-Hans":"目标无效或资源不足", "en":"Invalid target or insufficient resources"},
	"ui.hp_lost": {"zh-Hans":"−%d 生命", "en":"−%d HP"},
	"ui.revive_toast": {"zh-Hans":"✥ 敌人复活 +%d", "en":"✥ Enemy revived +%d"},
	"ui.crit_intent": {"zh-Hans":"✹ 暴击 %d", "en":"✹ CRIT %d"},
	"ui.attack_intent": {"zh-Hans":"⚔ 攻击 %d", "en":"⚔ ATK %d"},
	"ui.add_name": {"zh-Hans":"灵迹随从", "en":"Spirit Minion"},
	"ui.gold_reward": {"zh-Hans":"◆ +%d 金币    ♥ 战后恢复 10", "en":"◆ +%d Gold    ♥ Post-battle heal 10"},
	"ui.boss_equip_title": {"zh-Hans":"%s 首领装备 · %s", "en":"%s Boss Equipment · %s"},
	"ui.elite_rune_title": {"zh-Hans":"%s 精英符文 · %s", "en":"%s Elite Rune · %s"},
	"ui.choose_card": {"zh-Hans":"选择一张新卡", "en":"Choose a new card"},
	"ui.skip_card": {"zh-Hans":"跳过卡牌并返回地图", "en":"Skip card & return to map"},
	"ui.event_traveler": {"zh-Hans":"迷雾中的旅者", "en":"Traveler in the Mist"},
	"ui.chapter_title": {"zh-Hans":"第 %d 章", "en":"Chapter %d"},
	"ui.chapter_cleared_title": {"zh-Hans":"第 %d 章 · 妖煞荡尽", "en":"Chapter %d Cleared"},
	"ui.entering_new_realm": {"zh-Hans":"✦ 踏入全新疆域 ✦", "en":"✦ Entering New Realm ✦"},
	"ui.chapter_enter_toast": {"zh-Hans":"抵达第 %d 章 · %s", "en":"Arrived at Chapter %d · %s"},
	"ui.transition_skip": {"zh-Hans":"点击跳过", "en":"Tap to Skip"},
	"ui.map_back_to_current": {"zh-Hans":"当前进度", "en":"Current Stage"},
	"ui.event_merchant": {"zh-Hans":"路边行商", "en":"Roadside Merchant"},
	"ui.event_rest": {"zh-Hans":"灵火营地", "en":"Spirit Campfire"},
	"ui.event_default": {"zh-Hans":"旅途事件", "en":"Journey Event"},
	"ui.event_prompt": {"zh-Hans":"选择一项准备，然后进入本关战斗。", "en":"Choose a preparation, then enter battle."},
	"ui.event_opt_potion": {"zh-Hans":"商贩赠礼 · 获得 ◆25 灵石", "en":"Merchant Gift · Gain ◆25 Gold"},
	"ui.event_opt_direct": {"zh-Hans":"直接进入战斗", "en":"Enter battle directly"},
	"ui.shop_title": {"zh-Hans":"灵契商店", "en":"Spirit Shop"},
	"ui.shop_sub": {"zh-Hans":"购买卡牌与仪式净化", "en":"Buy cards & oblivion rituals"},
	"ui.shop_potion": {"zh-Hans":"商贩补给 · 获得灵石", "en":"Merchant Supply · Gain Gold"},
	"ui.shop_no_gold": {"zh-Hans":"金币不足", "en":"Not enough gold"},
	"ui.shop_card_fmt": {"zh-Hans":"%s   ◆%d   拥有%d", "en":"%s   ◆%d   Owned %d"},
	"rarity.Starter": {"zh-Hans":"初始", "en":"Starter"},
	"rarity.Common": {"zh-Hans":"普通", "en":"Common"},
	"rarity.Uncommon": {"zh-Hans":"罕见", "en":"Uncommon"},
	"rarity.Rare": {"zh-Hans":"稀有", "en":"Rare"},
	"ui.deck_title": {"zh-Hans":"牌组构筑", "en":"Deck Builder"},
	"ui.deck_sub": {"zh-Hans":"固定 25 张 · 当前 %d/25", "en":"Fixed 25 cards · Current %d/25"},
	"ui.deck_owned_fmt": {"zh-Hans":"%s  拥有%d", "en":"%s  Owned %d"},
	"ui.deck_confirm_fmt": {"zh-Hans":"确认牌组 %d/25", "en":"Confirm deck %d/25"},
	"ui.loadout_title": {"zh-Hans":"装备与符文", "en":"Equipment & Runes"},
	"ui.loadout_sub": {"zh-Hans":"三个装备槽位 · 每种卡牌一个符文", "en":"Three equipment slots · One rune per card"},
	"ui.loadout_cur_equip": {"zh-Hans":"当前装备", "en":"Current Equipment"},
	"ui.loadout_empty": {"zh-Hans":"空", "en":"Empty"},
	"ui.loadout_collection": {"zh-Hans":"装备收藏", "en":"Equipment Collection"},
	"ui.loadout_unequip": {"zh-Hans":"卸下", "en":"Unequip"},
	"ui.loadout_equip": {"zh-Hans":"装备", "en":"Equip"},
	"ui.loadout_unobtained": {"zh-Hans":"未获得", "en":"Locked"},
	"ui.loadout_runes_bag": {"zh-Hans":"符文行囊 · 选择后镶嵌到卡牌", "en":"Rune Bag · Select then socket to card"},
	"ui.loadout_deck_runes": {"zh-Hans":"牌组符文", "en":"Deck Runes"},
	"ui.loadout_unsocketed": {"zh-Hans":"未镶嵌", "en":"None"},
	"ui.loadout_remove": {"zh-Hans":"取下", "en":"Remove"},
	"ui.loadout_socket": {"zh-Hans":"镶嵌", "en":"Socket"},
	"ui.loadout_select_first": {"zh-Hans":"请先选择符文", "en":"Please select a rune first"},
	"ui.camp_title": {"zh-Hans":"探险营地", "en":"Expedition Camp"},
	"ui.camp_sub": {"zh-Hans":"档案、遗物与挑战阶梯", "en":"Dossier, relics, and challenge tiers"},
	"ui.camp_tier": {"zh-Hans":"挑战等级 A%d", "en":"Challenge Tier A%d"},
	"ui.camp_relics": {"zh-Hans":"已获得遗物 %d/5", "en":"Relics collected %d/5"},
	"ui.camp_desc": {"zh-Hans":"更高挑战提高敌人生命与伤害；Boss装备奖励会轮换。", "en":"Higher tiers boost enemy HP & ATK; Boss equipment rotates."},
	"ui.camp_tier_rebirth_unlocked": {"zh-Hans":"轮回已解锁至 A%d", "en":"Rebirth has unlocked up to A%d"},
	"ui.rebirth_title": {"zh-Hans":"轮回", "en":"Rebirth"},
	"ui.rebirth_locked_desc": {"zh-Hans":"通关全部250关，并将挑战等级设为A%d后解锁", "en":"Clear all 250 stages with Challenge Tier set to A%d to unlock"},
	"ui.rebirth_count_fmt": {"zh-Hans":"已轮回 %d 次", "en":"Rebirths: %d"},
	"ui.rebirth_bonus_fmt": {"zh-Hans":"当前永久加成：+%d 最大生命，+%d 初始护盾", "en":"Current permanent bonus: +%d Max HP, +%d Starting Shield"},
	"ui.rebirth_next_bonus_fmt": {"zh-Hans":"下次轮回后：+%d 最大生命，+%d 初始护盾", "en":"After next rebirth: +%d Max HP, +%d Starting Shield"},
	"ui.rebirth_button": {"zh-Hans":"轮回转生", "en":"Undergo Rebirth"},
	"ui.rebirth_confirm_title": {"zh-Hans":"确认轮回？", "en":"Confirm Rebirth?"},
	"ui.rebirth_confirm_resets": {"zh-Hans":"⚠ 将重置：关卡进度、牌组与卡牌收藏、卡牌强化、装备、符文、遗物", "en":"⚠ Will reset: stage progress, deck & card collection, card upgrades, equipment, runes, relics"},
	"ui.rebirth_confirm_keeps": {"zh-Hans":"✓ 将保留：金币与灵玉、英雄专精、成就、图鉴、日常/周常/深渊等其他进度", "en":"✓ Will keep: gold & jade, hero mastery, achievements, compendium, and all other modes' progress"},
	"ui.rebirth_confirm_btn": {"zh-Hans":"确认轮回", "en":"Confirm Rebirth"},
	"ui.rebirth_cancel_btn": {"zh-Hans":"取消", "en":"Cancel"},
	"ui.rebirth_toast": {"zh-Hans":"轮回完成！第 %d 次轮回的力量已融入你的血脉。", "en":"Rebirth complete! The power of cycle %d flows through you."},
	"ui.thorns_toast": {"zh-Hans":"荆棘反伤 −%d", "en":"Thorns reflect −%d"},
	"ui.quests_title": {"zh-Hans":"探险委托", "en":"Quest Commissions"},
	"ui.quests_sub": {"zh-Hans":"每日与每周探险委派", "en":"Daily & weekly commissions"},
	"ui.quests_hint": {"zh-Hans":"完成每日与每周委派任务，获取金币奖励与探险声望。", "en":"Complete daily and weekly commission tasks to earn gold and renown."},
	"ui.quests_daily": {"zh-Hans":"每日任务", "en":"Daily Quests"},
	"ui.quests_weekly": {"zh-Hans":"每周任务", "en":"Weekly Quests"},
	"ui.quests_daily_reset": {"zh-Hans":"%s后重置", "en":"Resets in %s"},
	"ui.quest_claim": {"zh-Hans":"领取", "en":"Claim"},
	"ui.quest_claimed": {"zh-Hans":"已领取", "en":"Claimed"},
	"ui.quest_reward_fmt": {"zh-Hans":"◆ %d", "en":"◆ %d"},
	"ui.quest_claimed_toast": {"zh-Hans":"任务完成 +%d 金币", "en":"Quest complete +%d gold"},
	"ui.quest_ready_toast": {"zh-Hans":"✦ 有任务可以领取了", "en":"✦ A quest is ready to claim"},
	"ui.reward_choose": {"zh-Hans":"选择一张卡牌带走", "en":"Choose a card to take"},
	"ui.reward_collect": {"zh-Hans":"只收入收藏", "en":"Collect only"},
	"ui.reward_smart_add": {"zh-Hans":"✦ 智能入组", "en":"✦ Add to deck"},
	"ui.reward_owned": {"zh-Hans":"已有 %d 张", "en":"Owned %d"},
	"ui.reward_in_deck": {"zh-Hans":"牌组中 %d 张", "en":"%d in deck"},
	"ui.reward_collected": {"zh-Hans":"%s 已收入收藏", "en":"%s added to your collection"},
	"ui.reward_added": {"zh-Hans":"%s 已加入牌组", "en":"%s added to your deck"},
	"ui.reward_replaced": {"zh-Hans":"%s 入组，替换掉 %s", "en":"%s added, replacing %s"},
	"ui.reward_gold_line": {"zh-Hans":"◆ +%d 金币", "en":"◆ +%d gold"},
	"ui.target_pick": {"zh-Hans":"选择目标", "en":"Pick a target"},
	"ui.target_cancel": {"zh-Hans":"再次点击卡牌取消", "en":"Tap the card again to cancel"},
	"ui.tap_to_dismiss": {"zh-Hans":"点击空白处关闭", "en":"Tap outside to close"},
	"ui.account_welcome": {"zh-Hans":"踏入灵界", "en":"Enter the Spirit Realm"},
	"ui.account_prompt": {"zh-Hans":"为你的驭灵者取个名字", "en":"Name your spirit tamer"},
	"ui.account_placeholder": {"zh-Hans":"输入名字", "en":"Enter a name"},
	"ui.account_start": {"zh-Hans":"开始远征", "en":"Begin Expedition"},
	"ui.account_need_name": {"zh-Hans":"请先输入名字", "en":"Please enter a name first"},
	"ui.account_title": {"zh-Hans":"账号", "en":"Account"},
	"ui.account_local": {"zh-Hans":"本地账号", "en":"Local account"},
	"ui.account_id": {"zh-Hans":"存档 ID", "en":"Save ID"},
	"ui.account_created": {"zh-Hans":"创建于 %s", "en":"Created %s"},
	"ui.account_rename": {"zh-Hans":"改名", "en":"Rename"},
	"ui.account_cloud": {"zh-Hans":"云端同步（即将支持）", "en":"Cloud sync (coming soon)"},
	"ui.account_cloud_hint": {"zh-Hans":"存档已按云同步格式保存，接入 Apple / Google 登录后可直接上传。", "en":"Saves already use the cloud-sync format; Apple / Google sign-in can upload them as-is."},
	"ui.intent_attack": {"zh-Hans":"⚔ %d", "en":"⚔ %d"},
	"ui.intent_critical": {"zh-Hans":"✹ %d", "en":"✹ %d"},
	"ui.intent_defend": {"zh-Hans":"⬢ %d", "en":"⬢ %d"},
	"ui.intent_empower": {"zh-Hans":"▲ +%d", "en":"▲ +%d"},
	"ui.intent_curse": {"zh-Hans":"☣ %d", "en":"☣ %d"},
	"ui.intent_attack_defend": {"zh-Hans":"⚔%d ⬢%d", "en":"⚔%d ⬢%d"},
	"ui.intent_tip_attack": {"zh-Hans":"准备攻击", "en":"Preparing to attack"},
	"ui.intent_tip_defend": {"zh-Hans":"准备防御", "en":"Preparing to defend"},
	"ui.intent_tip_empower": {"zh-Hans":"准备强化", "en":"Preparing to empower"},
	"ui.intent_tip_curse": {"zh-Hans":"准备施加燃烧", "en":"Preparing to inflict Burn"},
	"ui.preview_lethal": {"zh-Hans":"致命", "en":"LETHAL"},
	"ui.preview_blocked": {"zh-Hans":"盾挡%d", "en":"%d blocked"},
	"ui.relic_title": {"zh-Hans":"遗物", "en":"Relics"},
	"ui.relic_reward_title": {"zh-Hans":"%s 遗物 · %s", "en":"%s Relic · %s"},
	"ui.relic_none": {"zh-Hans":"尚未获得遗物", "en":"No relics yet"},
	"ui.node_boss": {"zh-Hans":"首领", "en":"Boss"},
	"ui.node_greatboss": {"zh-Hans":"大首领", "en":"Great Boss"},
	"ui.node_elite": {"zh-Hans":"精英", "en":"Elite"},
	"ui.node_event": {"zh-Hans":"事件", "en":"Event"},
	"ui.node_merchant": {"zh-Hans":"行商", "en":"Merchant"},
	"ui.node_rest": {"zh-Hans":"营地", "en":"Camp"},
	"ui.node_battle": {"zh-Hans":"战斗", "en":"Battle"},
	"ui.locked": {"zh-Hans":"未解锁", "en":"Locked"},
	"ui.energy_label": {"zh-Hans":"能量", "en":"Energy"},
	"ui.auto_end_turn": {"zh-Hans":"回合结束", "en":"Turn over"},
	"ui.no_playable": {"zh-Hans":"无可出之牌 · 回合结束", "en":"No playable cards · turn ends"},
	"ui.deck_auto_build": {"zh-Hans":"✦ 智能构筑", "en":"✦ Auto-Build"},
	"ui.deck_confirm": {"zh-Hans":"确认牌组", "en":"Confirm Deck"},
	"ui.deck_in_deck": {"zh-Hans":"入组", "en":"In deck"},
	"ui.deck_owned_short": {"zh-Hans":"拥有", "en":"Owned"},
	"ui.deck_auto_done": {"zh-Hans":"已按属性均衡自动构筑", "en":"Auto-built a balanced deck"},
	"ui.deck_need_cards": {"zh-Hans":"卡牌收藏不足 25 张", "en":"Fewer than 25 cards owned"},
	"ui.deck_full": {"zh-Hans":"牌组已满 25 张", "en":"Deck is full at 25"},
	"ui.tab_equipment": {"zh-Hans":"装备", "en":"Equipment"},
	"ui.tab_runes": {"zh-Hans":"符文", "en":"Runes"},
	"ui.slot_weapon": {"zh-Hans":"武器", "en":"Weapon"},
	"ui.slot_armor": {"zh-Hans":"护甲", "en":"Armor"},
	"ui.slot_charm": {"zh-Hans":"灵佩", "en":"Charm"},
	"ui.shop_buy": {"zh-Hans":"购买", "en":"Buy"},
	"ui.shop_refresh": {"zh-Hans":"%s后上新", "en":"New stock in %s"},
	"ui.shop_sale": {"zh-Hans":"今日特惠", "en":"Today's Deal"},
	"ui.shop_next_price": {"zh-Hans":"下一张 ◆%d", "en":"Next copy ◆%d"},
	"ui.shop_gold": {"zh-Hans":"◆ %d", "en":"◆ %d"},
	"ui.shop_bought": {"zh-Hans":"已购入 %s", "en":"Bought %s"},
	"ui.rune_none_selected": {"zh-Hans":"点击符文选中，再点卡牌镶嵌", "en":"Tap a rune, then tap a card to socket"},
	"desc.damage": {"zh-Hans":"造成%d点伤害", "en":"Deal %d damage"},
	"desc.shield": {"zh-Hans":"获得%d点护盾", "en":"Gain %d Shield"},
	"desc.heal": {"zh-Hans":"回复%d点生命", "en":"Restore %d HP"},
	"desc.draw": {"zh-Hans":"抽%d张牌", "en":"Draw %d cards"},
	"desc.burn": {"zh-Hans":"施加%d层燃烧", "en":"Apply %d Burn"},
	"desc.focus": {"zh-Hans":"施加%d层凝神", "en":"Apply %d Focus"},
	"desc.vulnerable": {"zh-Hans":"施加%d回合易伤（受到伤害+50%%）", "en":"Apply %d Vulnerable (+50%% damage taken)"},
	"desc.weak": {"zh-Hans":"施加%d回合虚弱（造成伤害-25%%）", "en":"Apply %d Weak (-25%% damage dealt)"},
	"desc.strength": {"zh-Hans":"获得%d点本场力量（攻击牌永久+伤害）", "en":"Gain %d Strength this battle (permanent attack bonus)"},
	"desc.poison": {"zh-Hans":"施加%d层毒素（每回合造成等量伤害，不会自然衰减）", "en":"Apply %d Poison (deals damage equal to stacks each turn, does not decay on its own)"},
	"desc.energy": {"zh-Hans":"获得%d点能量", "en":"Gain %d Energy"},
	"desc.special.pierce": {"zh-Hans":"无视护盾", "en":"Pierces Shield"},
	"desc.special.cleave": {"zh-Hans":"命中所有敌人", "en":"Hits all enemies"},
	"desc.special.critical": {"zh-Hans":"伤害翻倍", "en":"Double damage"},
	"desc.special.stun": {"zh-Hans":"眩晕目标一回合", "en":"Stuns target for a turn"},
	"desc.special.recoverExhaust": {"zh-Hans":"取回一张消耗牌", "en":"Return an exhausted card"},
	"desc.special.recycleDiscard": {"zh-Hans":"回收弃牌堆至多2张", "en":"Recycle up to 2 discards"},
	"ui.speed_toggle": {"zh-Hans":"%sx", "en":"%sx"},
	"ui.pass_turn": {"zh-Hans":"空过", "en":"Pass"},
	"kw.damage": {"zh-Hans":"伤害：对目标造成指定数值的生命值损失。受凝神(Focus)加成。", "en":"Damage: Deal the specified amount of HP loss to the target. Boosted by Focus."},
	"kw.shield": {"zh-Hans":"护盾：在本回合内吸收等量伤害，回合结束时清零。", "en":"Shield: Absorbs damage this turn, removed at end of turn."},
	"kw.heal": {"zh-Hans":"回复：恢复指定数值的生命值，不超过上限。", "en":"Heal: Restore the specified HP, up to max."},
	"kw.draw": {"zh-Hans":"抽牌：从抽牌堆抽取指定数量的卡牌到手牌。", "en":"Draw: Draw the specified number of cards from your draw pile."},
	"kw.burn": {"zh-Hans":"燃烧：每回合开始时对目标造成等量伤害，每回合递减1层。", "en":"Burn: Deals damage equal to stacks at turn start, decays by 1 each turn."},
	"kw.focus": {"zh-Hans":"凝神：本次攻击额外增加等量伤害，使用后清零。", "en":"Focus: Adds to your next attack's damage, then resets to 0."},
	"kw.vulnerable": {"zh-Hans":"易伤：受到的伤害增加50%，每敌方回合递减1层。", "en":"Vulnerable: Take 50% more damage. Decays by 1 each enemy turn."},
	"kw.weak": {"zh-Hans":"虚弱：造成的伤害减少25%，每敌方回合递减1层。", "en":"Weak: Deal 25% less damage. Decays by 1 each enemy turn."},
	"kw.strength": {"zh-Hans":"力量：永久增加攻击牌的伤害，持续整场战斗。", "en":"Strength: Permanently increases attack card damage for this battle."},
	"kw.poison": {"zh-Hans":"毒素：每回合开始对目标造成等同层数的伤害，且不会像灼烧一样自然衰减，只能被治疗或击杀清除。", "en":"Poison: Deals damage equal to its stacks at the start of each turn. Unlike Burn, it never decays on its own — only healing or a kill clears it."},
	"kw.pierce": {"zh-Hans":"贯穿：无视目标护盾，直接造成伤害。", "en":"Pierce: Ignores target's Shield, dealing damage directly to HP."},
	"kw.cleave": {"zh-Hans":"横扫：同时命中所有存活的敌人。", "en":"Cleave: Hits all living enemies simultaneously."},
	"kw.critical": {"zh-Hans":"暴击：造成双倍伤害。", "en":"Critical: Deals double damage."},
	"kw.stun": {"zh-Hans":"眩晕：目标跳过下一回合的行动。", "en":"Stun: Target skips their next action."},
	"kw.energy": {"zh-Hans":"能量：出牌所需的资源。每回合回复，随回合数递增。", "en":"Energy: Resource spent to play cards. Replenishes each turn, increasing over time."},
	"kw.echo": {"zh-Hans":"回响：卡牌效果有50%概率触发第二次。", "en":"Echo: 50% chance to trigger the card's effect a second time."},
	"kw.siphon": {"zh-Hans":"虹吸：将造成伤害的25%转化为护盾。", "en":"Siphon: Converts 25% of damage dealt into Shield."},
	"kw.resonance": {"zh-Hans":"共鸣：根据之前打出的同元素卡牌数量增加伤害。", "en":"Resonance: Increases damage based on previously played same-element cards."},
	"ui.rest_title": {"zh-Hans":"灵火营地", "en":"Spirit Campfire"},
	"ui.rest_prompt": {"zh-Hans":"温暖的灵火在荒野中升腾。选择一项仪式以助前路：", "en":"Warm spirit embers burn in the wild. Choose a ritual to aid your path:"},
	"ui.rest_heal_choice": {"zh-Hans":"灵火调息 · 获得 ◆35 灵石", "en":"Spirit Rest · Gain ◆35 Gold"},
	"ui.rest_purify_choice": {"zh-Hans":"遗忘祭坛 · 净化并替换一张卡牌", "en":"Purify Altar · Banish & replace a card"},
	"ui.rest_smith_choice": {"zh-Hans":"灵火淬炼 · 强化一张卡牌 (+1)", "en":"Spirit Smith · Upgrade a card (+1)"},
	"ui.shop_purge_service": {"zh-Hans":"遗忘仪式 · 移除一张卡牌", "en":"Oblivion Ritual · Purge a card"},
	"ui.purge_title": {"zh-Hans":"遗忘祭坛", "en":"Altar of Oblivion"},
	"ui.purge_sub": {"zh-Hans":"选择一张卡牌永久从牌组中放逐，获得灵火祝福", "en":"Select a card to banish from deck & gain a spirit blessing"},
	"ui.purge_confirm": {"zh-Hans":"放逐", "en":"Banish"},
	"ui.purge_card_fmt": {"zh-Hans":"放逐 %s", "en":"Banish %s"},
	"ui.purged_toast": {"zh-Hans":"已放逐 %s，转化获得 %s", "en":"Banished %s, transformed into %s"},
	"ui.upgrade_title": {"zh-Hans":"灵火淬炼", "en":"Spirit Smith"},
	"ui.upgrade_sub": {"zh-Hans":"选择一张卡牌进行永久强化 (+1)", "en":"Select a card to permanently upgrade (+1)"},
	"ui.upgraded_toast": {"zh-Hans":"%s 已强化为 %s +1", "en":"%s upgraded to %s +1"},
	"ui.event_blood_pact": {"zh-Hans":"暗影交易 · 获得 ◆50 灵石", "en":"Shadow Pact · Gain ◆50 Gold"},
	"ui.event_spirit_blessing": {"zh-Hans":"灵脉洗礼 · 净化一张卡牌", "en":"Spirit Blessing · Purge a card"},
	"ui.hero_classes_title": {"zh-Hans":"英雄流派", "en":"Hero Archetypes"},
	"ui.hero_class_select": {"zh-Hans":"选择职业", "en":"Select Class"},
	"ui.hero_selected_toast": {"zh-Hans":"已切换为 %s", "en":"Switched to %s"},
	"ui.abyss_title": {"zh-Hans":"无尽深渊", "en":"Endless Abyss"},
	"ui.abyss_sub": {"zh-Hans":"挑战无休止的极度试炼 · 击破深渊守卫", "en":"Challenge endless trials · Vanquish abyss sentinels"},
	"ui.abyss_floor_fmt": {"zh-Hans":"当前深渊：第 %d 层", "en":"Current: Floor %d"},
	"ui.abyss_record_fmt": {"zh-Hans":"历史最佳：第 %d 层", "en":"Personal Best: Floor %d"},
	"ui.abyss_enter": {"zh-Hans":"踏入深渊试炼", "en":"Enter Abyss Trial"},
	"ui.abyss_btn": {"zh-Hans":"深渊", "en":"Abyss"},
	"ui.abyss_reward_toast": {"zh-Hans":"深渊第 %d 层通关！获得 ◆%d 金币", "en":"Abyss Floor %d Cleared! +◆%d Gold"},
	"ui.lethal": {"zh-Hans":"斩杀", "en":"LETHAL"},
	"ui.danger": {"zh-Hans":"危险", "en":"DANGER"},
	"ui.pile_draw_title": {"zh-Hans":"抽牌堆", "en":"Draw Pile"},
	"ui.pile_discard_title": {"zh-Hans":"弃牌堆", "en":"Discard Pile"},
	"ui.pile_exhaust_title": {"zh-Hans":"消耗堆", "en":"Exhaust Pile"},
	"ui.cancel_drop": {"zh-Hans":"拖至此处取消释放", "en":"Drop here to cancel"},
	"ui.pile_count_desc": {"zh-Hans":"共 %d 张卡牌（无序）", "en":"%d cards remaining (shuffled)"},
	"ui.finishing_blow": {"zh-Hans":"终结", "en":"FINISHING BLOW"},
	"ui.finishing_sub": {"zh-Hans":"致命一击", "en":"LETHAL STRIKE"},
	"ui.boon_draft_title": {"zh-Hans":"深渊恩赐", "en":"Abyss Boon"},
	"ui.boon_draft_sub": {"zh-Hans":"深渊裂隙给予你的古老祝福（选择一项）：", "en":"Choose an ancient blessing granted by the abyss:"},
	"ui.boon_acquired_toast": {"zh-Hans":"已获得深渊恩赐：%s！", "en":"Acquired Abyss Boon: %s!"},
	"ui.claim": {"zh-Hans":"选择", "en":"Choose"},
	"boon.blood_lust.name": {"zh-Hans":"嗜血渴望", "en":"Blood Lust"},
	"boon.blood_lust.desc": {"zh-Hans":"击败敌人时恢复 8 点生命值", "en":"Heal 8 HP when an enemy is defeated."},
	"boon.iron_core.name": {"zh-Hans":"玄铁核心", "en":"Iron Core"},
	"boon.iron_core.desc": {"zh-Hans":"每回合开始时获得 5 点护盾", "en":"Gain 5 shield at the start of each turn."},
	"boon.spirit_surge.name": {"zh-Hans":"灵力涌动", "en":"Spirit Surge"},
	"boon.spirit_surge.desc": {"zh-Hans":"每回合第一张攻击牌伤害 +4", "en":"First attack card each turn deals +4 damage."},
	"boon.flame_affinity.name": {"zh-Hans":"炎火亲和", "en":"Flame Affinity"},
	"boon.flame_affinity.desc": {"zh-Hans":"施加的灼烧层数额外 +2", "en":"All burn effects apply +2 additional stacks."},
	"boon.wind_stride.name": {"zh-Hans":"风行之步", "en":"Wind Stride"},
	"boon.wind_stride.desc": {"zh-Hans":"每回合开始时额外抽取 1 张卡牌", "en":"Draw 1 additional card at the start of each turn."},
	"boon.golden_fortune.name": {"zh-Hans":"深渊淘金", "en":"Abyssal Greed"},
	"boon.golden_fortune.desc": {"zh-Hans":"深渊金币奖励提升 50%", "en":"Increase Abyss gold rewards by 50%."},
	"desc.decay_blight": {"zh-Hans":"消耗此牌。回合结束若在手牌中，受到 3 点伤害。", "en":"Exhausts on play. If in hand at turn end, take 3 damage."},
	"desc.void_curse": {"zh-Hans":"无法打出。抽到时受到 2 点伤害。回合结束时自动消耗。", "en":"Unplayable. When drawn, take 2 damage. Exhausts at turn end."},
	"ui.rune_resonance_title": {"zh-Hans":"符文共鸣套装", "en":"Rune Resonance Sets"},
	"ui.rune_resonance_active": {"zh-Hans":"✦ 已激活共鸣", "en":"✦ Resonance Active"},
	"ui.rune_resonance_inactive": {"zh-Hans":"未激活（需镶嵌对应符文）", "en":"Inactive (Socket required runes)"},
	"set.flame.name": {"zh-Hans":"烈焰共鸣", "en":"Flame Resonance"},
	"set.flame.desc": {"zh-Hans":"攻击命中灼烧目标时造成额外 +3 点伤害", "en":"Attacks against Burning targets deal +3 bonus damage"},
	"set.gale.name": {"zh-Hans":"疾风共鸣", "en":"Gale Resonance"},
	"set.gale.desc": {"zh-Hans":"每回合首次过牌或循环时回复 1 点能量", "en":"Gain 1 Energy on your first cycle/card-draw each turn"},
	"set.stone.name": {"zh-Hans":"磐石共鸣", "en":"Stone Resonance"},
	"set.stone.desc": {"zh-Hans":"获得护盾时有 25% 几率使护盾值提升 50%", "en":"25% chance to gain +50% extra Shield on shield actions"},
	"ui.compendium_title": {"zh-Hans":"驭灵秘典", "en":"Spirit Compendium"},
	"ui.compendium_sub": {"zh-Hans":"卡牌、装备、符文、遗物与图鉴全收录", "en":"Every card, relic, rune and beast you've discovered"},
	"ui.compendium_tab_cards": {"zh-Hans":"卡牌", "en":"Cards"},
	"ui.compendium_tab_gear": {"zh-Hans":"装备", "en":"Gear"},
	"ui.compendium_tab_bestiary": {"zh-Hans":"图鉴", "en":"Bestiary"},
	"ui.compendium_progress": {"zh-Hans":"已发现 %d/%d", "en":"Discovered %d/%d"},
	"ui.compendium_locked": {"zh-Hans":"尚未发现", "en":"Undiscovered"},
	"ui.compendium_open_btn": {"zh-Hans":"打开驭灵秘典", "en":"Open Compendium"},
	"ui.mastery_level_fmt": {"zh-Hans":"专精 Lv.%d", "en":"Mastery Lv.%d"},
	"ui.mastery_progress_fmt": {"zh-Hans":"%d/%d 经验", "en":"%d/%d XP"},
	"ui.mastery_maxed": {"zh-Hans":"已满级", "en":"Maxed"},
	"ui.mastery_levelup_toast": {"zh-Hans":"%s 专精提升至 Lv.%d！", "en":"%s Mastery reached Lv.%d!"},
	"mastery.fox.1.name": {"zh-Hans":"灵狐初醒", "en":"Fox Awakening"},
	"mastery.fox.1.desc": {"zh-Hans":"战斗第 1 回合起始能量 +1", "en":"+1 starting Energy on Turn 1"},
	"mastery.fox.2.name": {"zh-Hans":"灵体强化", "en":"Vital Attunement"},
	"mastery.fox.2.desc": {"zh-Hans":"最大生命 +4", "en":"+4 Max HP"},
	"mastery.fox.3.name": {"zh-Hans":"灵火连击", "en":"Foxfire Combo"},
	"mastery.fox.3.desc": {"zh-Hans":"每回合首次攻击牌伤害 +2", "en":"First attack each turn deals +2 damage"},
	"mastery.fox.4.name": {"zh-Hans":"引燃之息", "en":"Kindling Breath"},
	"mastery.fox.4.desc": {"zh-Hans":"战斗开始时对所有敌人施加 1 层灼烧", "en":"Apply 1 Burn to all enemies at battle start"},
	"mastery.fox.5.name": {"zh-Hans":"灵狐爆发", "en":"Fox Spirit Surge"},
	"mastery.fox.5.desc": {"zh-Hans":"每回合首次攻击牌伤害额外 +3（与 3 级共计 +5）", "en":"First attack each turn deals a further +3 damage (total +5 with Lv.3)"},
	"mastery.stone.1.name": {"zh-Hans":"磐岩之体", "en":"Stoneflesh"},
	"mastery.stone.1.desc": {"zh-Hans":"最大生命 +6", "en":"+6 Max HP"},
	"mastery.stone.2.name": {"zh-Hans":"起手布防", "en":"Opening Bulwark"},
	"mastery.stone.2.desc": {"zh-Hans":"战斗开始获得 5 点护盾", "en":"Start battle with 5 Shield"},
	"mastery.stone.3.name": {"zh-Hans":"自愈之核", "en":"Regenerative Core"},
	"mastery.stone.3.desc": {"zh-Hans":"每回合开始回复 1 点生命", "en":"Restore 1 HP at the start of each turn"},
	"mastery.stone.4.name": {"zh-Hans":"重甲加固", "en":"Reinforced Plating"},
	"mastery.stone.4.desc": {"zh-Hans":"战斗开始额外获得 7 点护盾（总计 12 点）", "en":"+7 more Shield at battle start (12 total)"},
	"mastery.stone.5.name": {"zh-Hans":"不朽之躯", "en":"Unbreakable Form"},
	"mastery.stone.5.desc": {"zh-Hans":"最大生命额外 +10（总计 +16）", "en":"+10 more Max HP (16 total)"},
	"mastery.shadow.1.name": {"zh-Hans":"暗影淬体", "en":"Shadow-Honed Body"},
	"mastery.shadow.1.desc": {"zh-Hans":"最大生命 +4", "en":"+4 Max HP"},
	"mastery.shadow.2.name": {"zh-Hans":"破绽初现", "en":"Mark of Weakness"},
	"mastery.shadow.2.desc": {"zh-Hans":"战斗开始时施加敌方 1 层易伤", "en":"Apply 1 Vulnerable to enemies at battle start"},
	"mastery.shadow.3.name": {"zh-Hans":"暗袭之势", "en":"Ambush Momentum"},
	"mastery.shadow.3.desc": {"zh-Hans":"每回合首次攻击牌伤害 +3", "en":"First attack each turn deals +3 damage"},
	"mastery.shadow.4.name": {"zh-Hans":"双重破绽", "en":"Double Mark"},
	"mastery.shadow.4.desc": {"zh-Hans":"战斗开始额外施加 1 层易伤（总计 2 层）", "en":"+1 more Vulnerable at battle start (2 total)"},
	"mastery.shadow.5.name": {"zh-Hans":"夜影绝杀", "en":"Shadow Execution"},
	"mastery.shadow.5.desc": {"zh-Hans":"每回合首次攻击牌伤害额外 +4（总计 +7）", "en":"First attack each turn deals a further +4 damage (total +7)"},
	"mastery.miasma.1.name": {"zh-Hans":"瘴气淬体", "en":"Miasma-Hardened"},
	"mastery.miasma.1.desc": {"zh-Hans":"最大生命 +4", "en":"+4 Max HP"},
	"mastery.miasma.2.name": {"zh-Hans":"腐蚀之息", "en":"Corrosive Breath"},
	"mastery.miasma.2.desc": {"zh-Hans":"战斗开始时对所有敌人施加 1 层毒素", "en":"Apply 1 Poison to all enemies at battle start"},
	"mastery.miasma.3.name": {"zh-Hans":"毒尖锋芒", "en":"Envenomed Edge"},
	"mastery.miasma.3.desc": {"zh-Hans":"每回合首次攻击牌伤害 +2", "en":"First attack each turn deals +2 damage"},
	"mastery.miasma.4.name": {"zh-Hans":"瘟疫蔓延", "en":"Spreading Plague"},
	"mastery.miasma.4.desc": {"zh-Hans":"战斗开始额外施加 1 层毒素（总计 2 层）", "en":"+1 more Poison at battle start (2 total)"},
	"mastery.miasma.5.name": {"zh-Hans":"腐灭一击", "en":"Blight Strike"},
	"mastery.miasma.5.desc": {"zh-Hans":"每回合首次攻击牌伤害额外 +3（总计 +5）", "en":"First attack each turn deals a further +3 damage (total +5)"},
	"ui.hero_art_pending": {"zh-Hans":"美术资源开发中", "en":"Art Coming Soon"},
	"ui.daily_trial_title": {"zh-Hans":"每日试炼", "en":"Daily Trial"},
	"ui.daily_trial_sub": {"zh-Hans":"15 关封印挑战 · 每日重置", "en":"A 15-stage sealed gauntlet, resetting daily"},
	"ui.daily_trial_modifiers_title": {"zh-Hans":"今日封印", "en":"Today's Seals"},
	"ui.daily_trial_progress_fmt": {"zh-Hans":"进度 %d/15", "en":"Progress %d/15"},
	"ui.daily_trial_best_fmt": {"zh-Hans":"历史最佳 %d/15", "en":"Best %d/15"},
	"ui.daily_trial_badges_fmt": {"zh-Hans":"徽章 ×%d", "en":"Badges ×%d"},
	"ui.daily_trial_enter": {"zh-Hans":"进入试炼", "en":"Enter Trial"},
	"ui.daily_trial_done": {"zh-Hans":"今日试炼已通关，明日再来", "en":"Today's trial is cleared — come back tomorrow"},
	"ui.daily_trial_complete": {"zh-Hans":"✦ 试炼徽章 +1！", "en":"✦ Trial Badge +1!"},
	"ui.daily_trial_progress_reward_fmt": {"zh-Hans":"试炼进度 %d/15", "en":"Trial progress %d/15"},
	"ui.abyss_stage_label_fmt": {"zh-Hans":"深渊 · 第%d层", "en":"Abyss · Floor %d"},
	"ui.daily_trial_stage_label_fmt": {"zh-Hans":"每日试炼 · %d/%d", "en":"Daily Trial · %d/%d"},
	"ui.weekly_challenge_title": {"zh-Hans":"每周主题挑战", "en":"Weekly Theme Challenge"},
	"ui.weekly_challenge_sub": {"zh-Hans":"8 关限时挑战 · 每周重置", "en":"An 8-stage timed gauntlet, resetting weekly"},
	"ui.weekly_challenge_modifier_title": {"zh-Hans":"本周主题", "en":"This Week's Theme"},
	"ui.weekly_challenge_progress_fmt": {"zh-Hans":"进度 %d/8", "en":"Progress %d/8"},
	"ui.weekly_challenge_best_fmt": {"zh-Hans":"历史最佳 %d/8", "en":"Best %d/8"},
	"ui.weekly_challenge_badges_fmt": {"zh-Hans":"徽章 ×%d", "en":"Badges ×%d"},
	"ui.weekly_challenge_enter": {"zh-Hans":"进入本周挑战", "en":"Enter Weekly Challenge"},
	"ui.weekly_challenge_done": {"zh-Hans":"本周挑战已通关，下周再来", "en":"This week's challenge is cleared — come back next week"},
	"ui.weekly_challenge_complete": {"zh-Hans":"✦ 本周挑战徽章 +1！", "en":"✦ Weekly Challenge Badge +1!"},
	"ui.weekly_challenge_stage_label_fmt": {"zh-Hans":"每周挑战 · %d/%d", "en":"Weekly Challenge · %d/%d"},
	"ui.weekly_challenge_progress_reward_fmt": {"zh-Hans":"挑战进度 %d/8", "en":"Challenge progress %d/8"},
	"weekly.tag.iron_horde.name": {"zh-Hans":"铁甲军团周", "en":"Iron Horde Week"},
	"weekly.tag.iron_horde.desc": {"zh-Hans":"敌人生命 +60%", "en":"Enemy HP +60%"},
	"weekly.tag.savage_tide.name": {"zh-Hans":"凶蛮潮汐周", "en":"Savage Tide Week"},
	"weekly.tag.savage_tide.desc": {"zh-Hans":"敌人攻击 +60%", "en":"Enemy damage +60%"},
	"weekly.tag.twin_pack.name": {"zh-Hans":"结群狩猎周", "en":"Twin Pack Week"},
	"weekly.tag.twin_pack.desc": {"zh-Hans":"每场战斗额外增加一名敌人", "en":"Every battle adds one extra enemy"},
	"weekly.tag.bounty_week.name": {"zh-Hans":"双倍赏金周", "en":"Bounty Week"},
	"weekly.tag.bounty_week.desc": {"zh-Hans":"每关金币奖励 ×2", "en":"Gold reward ×2 per stage"},
	"trial.tag.double_damage.name": {"zh-Hans":"倍伤浪潮", "en":"Surging Onslaught"},
	"trial.tag.double_damage.desc": {"zh-Hans":"敌人造成的伤害翻倍", "en":"Enemies deal double damage"},
	"trial.tag.juggernaut.name": {"zh-Hans":"巨兽压境", "en":"Juggernaut Foes"},
	"trial.tag.juggernaut.desc": {"zh-Hans":"敌人生命 +75%", "en":"Enemy HP +75%"},
	"trial.tag.swarm.name": {"zh-Hans":"群狼环伺", "en":"Encircling Swarm"},
	"trial.tag.swarm.desc": {"zh-Hans":"额外增加一名敌人", "en":"+1 additional enemy"},
	"trial.tag.undying.name": {"zh-Hans":"不死意志", "en":"Undying Will"},
	"trial.tag.undying.desc": {"zh-Hans":"敌人有几率于死亡后复活", "en":"Enemies may revive after death"},
	"trial.tag.frenzy.name": {"zh-Hans":"狂暴之怒", "en":"Berserk Fury"},
	"trial.tag.frenzy.desc": {"zh-Hans":"敌人攻击力 +5", "en":"Enemy damage +5"},
	"ui.tutorial_next": {"zh-Hans":"下一步", "en":"Next"},
	"ui.tutorial_prev": {"zh-Hans":"上一步", "en":"Back"},
	"ui.tutorial_start": {"zh-Hans":"开始战斗", "en":"Start Battle"},
	"ui.tutorial_skip": {"zh-Hans":"跳过教程", "en":"Skip Tutorial"},
	"ui.tutorial_step_fmt": {"zh-Hans":"%d / %d", "en":"%d / %d"},
	"tutorial.1.title": {"zh-Hans":"手牌与能量", "en":"Hand & Energy"},
	"tutorial.1.desc": {"zh-Hans":"卡牌左上角的数字是能量费用。每回合能量有限，够花才能出牌——没有出牌次数上限，只有能量说了算。", "en":"The number on a card's top-left corner is its Energy cost. Energy is limited each turn — there's no cap on how many cards you can play, only on what you can afford."},
	"tutorial.2.title": {"zh-Hans":"出牌与瞄准", "en":"Playing & Targeting"},
	"tutorial.2.desc": {"zh-Hans":"把卡牌拖到敌人身上即可对其造成效果；没有攻击效果的卡牌（比如护盾、回复）直接拖到空白处使用即可。", "en":"Drag a card onto an enemy to affect them; a card with no attack effect (shield, heal) can be dragged anywhere else to play it."},
	"tutorial.3.title": {"zh-Hans":"回合自动结束", "en":"Turns End Themselves"},
	"tutorial.3.desc": {"zh-Hans":'这里没有"结束回合"按钮：当手牌打不动（能量不够或没牌了），回合会自动结束，进入敌人的行动。', "en":"There's no End Turn button: once nothing left in hand is affordable, the turn ends itself and the enemy acts."},
	"tutorial.4.title": {"zh-Hans":"战报与成长", "en":"Rewards & Growth"},
	"tutorial.4.desc": {"zh-Hans":"获胜后可以选择带走一张新卡加入牌组。营地里还有装备、符文、专精与每日试炼——一步步来，先打赢眼前这一场。", "en":"Winning lets you add a new card to your deck. Camp holds equipment, runes, mastery and the Daily Trial — for now, just win the fight in front of you."},
	"ui.login_reward_title": {"zh-Hans":"本周登录", "en":"This Week's Visits"},
	"ui.login_reward_progress_fmt": {"zh-Hans":"已登录 %d/7 天", "en":"Logged in %d/7 days"},
	"ui.login_reward_tier_fmt": {"zh-Hans":"登录满 %d 天", "en":"Log in %d days"},
	"ui.login_reward_claimed_toast": {"zh-Hans":"登录奖励 +%d 金币", "en":"Login reward +%d gold"},
	"ui.compendium_tab_achievements": {"zh-Hans":"成就", "en":"Achievements"},
	"ui.compendium_tab_chronicle": {"zh-Hans":"编年史", "en":"Chronicle"},
	"ui.chronicle_locked": {"zh-Hans":"尚未抵达", "en":"Not yet reached"},
	"ui.camp_tab_character": {"zh-Hans":"角色", "en":"Character"},
	"ui.camp_tab_challenges": {"zh-Hans":"挑战", "en":"Challenges"},
	"ui.camp_tab_collection": {"zh-Hans":"收藏", "en":"Collection"},
	"ui.challenges_title": {"zh-Hans":"试炼挑战", "en":"Trial Challenges"},
	"ui.challenges_sub": {"zh-Hans":"每日试炼 · 每周挑战 · 无尽深渊 · 难度调控", "en":"Daily Trial · Weekly · Abyss · Difficulty"},
	"ui.achievement_unlocked_toast": {"zh-Hans":"✦ 成就解锁：%s", "en":"✦ Achievement Unlocked: %s"},
	"ui.achievement_locked": {"zh-Hans":"未解锁", "en":"Locked"},
	"ach.win10.name": {"zh-Hans":"初出茅庐", "en":"First Steps"},
	"ach.win10.desc": {"zh-Hans":"累计赢得 10 场战斗", "en":"Win 10 battles total"},
	"ach.win50.name": {"zh-Hans":"身经百战", "en":"Battle-Tested"},
	"ach.win50.desc": {"zh-Hans":"累计赢得 50 场战斗", "en":"Win 50 battles total"},
	"ach.win200.name": {"zh-Hans":"传奇驭灵者", "en":"Legendary Tamer"},
	"ach.win200.desc": {"zh-Hans":"累计赢得 200 场战斗", "en":"Win 200 battles total"},
	"ach.damage10k.name": {"zh-Hans":"灵力初显", "en":"Spirit Power Awakens"},
	"ach.damage10k.desc": {"zh-Hans":"累计造成 10,000 点伤害", "en":"Deal 10,000 total damage"},
	"ach.damage100k.name": {"zh-Hans":"毁天灭地", "en":"World Ender"},
	"ach.damage100k.desc": {"zh-Hans":"累计造成 100,000 点伤害", "en":"Deal 100,000 total damage"},
	"ach.chest10.name": {"zh-Hans":"寻宝人", "en":"Treasure Hunter"},
	"ach.chest10.desc": {"zh-Hans":"累计开启 10 个胜利宝箱", "en":"Open 10 victory chests"},
	"ach.shop20.name": {"zh-Hans":"熟客", "en":"Regular Customer"},
	"ach.shop20.desc": {"zh-Hans":"累计在商店购买 20 次", "en":"Make 20 shop purchases total"},
	"ach.gold1000.name": {"zh-Hans":"小有积蓄", "en":"Modest Savings"},
	"ach.gold1000.desc": {"zh-Hans":"累计获得 1,000 金币", "en":"Earn 1,000 gold total"},
	"ach.gold10000.name": {"zh-Hans":"富甲一方", "en":"Wealthy Tamer"},
	"ach.gold10000.desc": {"zh-Hans":"累计获得 10,000 金币", "en":"Earn 10,000 gold total"},
	"ach.elite_boss20.name": {"zh-Hans":"精英猎手", "en":"Elite Hunter"},
	"ach.elite_boss20.desc": {"zh-Hans":"累计击败 20 场精英或首领战斗", "en":"Clear 20 elite or boss battles"},
	"ach.greatboss5.name": {"zh-Hans":"弑神者", "en":"Godslayer"},
	"ach.greatboss5.desc": {"zh-Hans":"累计击败 5 位大首领", "en":"Defeat 5 Great Bosses"},
	"ach.rune_play50.name": {"zh-Hans":"符文大师", "en":"Rune Adept"},
	"ach.rune_play50.desc": {"zh-Hans":"累计使用 50 次镶嵌符文的卡牌", "en":"Play 50 rune-socketed cards"},
	"ach.collect20.name": {"zh-Hans":"卡牌收藏家", "en":"Card Collector"},
	"ach.collect20.desc": {"zh-Hans":"收集 20 种不同的卡牌", "en":"Collect 20 distinct cards"},
	"ach.collect_all.name": {"zh-Hans":"图书馆管理员", "en":"The Librarian"},
	"ach.collect_all.desc": {"zh-Hans":"收集全部卡牌", "en":"Collect every card"},
	"ach.relics_all.name": {"zh-Hans":"遗物大师", "en":"Relic Master"},
	"ach.relics_all.desc": {"zh-Hans":"获得全部遗物", "en":"Obtain every relic"},
	"ach.mastery5.name": {"zh-Hans":"专精圆满", "en":"Mastery Achieved"},
	"ach.mastery5.desc": {"zh-Hans":"任意英雄专精达到 Lv.5", "en":"Reach Mastery Lv.5 with any hero"},
	"ach.abyss10.name": {"zh-Hans":"深渊行者", "en":"Abyss Walker"},
	"ach.abyss10.desc": {"zh-Hans":"无尽深渊达到第 10 层", "en":"Reach Abyss Floor 10"},
	"ach.abyss30.name": {"zh-Hans":"深渊征服者", "en":"Abyss Conqueror"},
	"ach.abyss30.desc": {"zh-Hans":"无尽深渊达到第 30 层", "en":"Reach Abyss Floor 30"},
	"ach.trial_badges5.name": {"zh-Hans":"试炼常客", "en":"Trial Regular"},
	"ach.trial_badges5.desc": {"zh-Hans":"每日试炼累计获得 5 枚徽章", "en":"Earn 5 Daily Trial badges total"},
	"ach.trial_badges20.name": {"zh-Hans":"试炼英雄", "en":"Trial Hero"},
	"ach.trial_badges20.desc": {"zh-Hans":"每日试炼累计获得 20 枚徽章", "en":"Earn 20 Daily Trial badges total"},
	"ach.compendium50.name": {"zh-Hans":"探索者", "en":"Explorer"},
	"ach.compendium50.desc": {"zh-Hans":"驭灵秘典收集率达到 50%", "en":"Reach 50% Compendium discovery"},
	"ach.compendium100.name": {"zh-Hans":"驭灵秘典·大成", "en":"Compendium Complete"},
	"ach.compendium100.desc": {"zh-Hans":"驭灵秘典收集率达到 100%", "en":"Reach 100% Compendium discovery"},
	"ui.hero_rec_badge": {"zh-Hans":"✦ 新手推荐", "en":"✦ Recommended"},
	"ui.hero_rec_desc": {"zh-Hans":"能量充裕，起手爆发稳定，适合初涉灵界的行者。", "en":"Generous energy and steady burst damage, ideal for newcomers."},
	"ui.lock_clears_ch1": {"zh-Hans":"通关第 1 章解锁", "en":"Clear Chapter 1 to unlock"},
	"ui.lock_clears_ch2": {"zh-Hans":"通关第 2 章解锁", "en":"Clear Chapter 2 to unlock"},
	"ui.lock_clears_ch5": {"zh-Hans":"通关第 5 章解锁", "en":"Clear Chapter 5 to unlock"},
	"ui.daily_trial_streak_fmt": {"zh-Hans":"连胜: %d 天", "en":"Streak: %d Days"},
	"ui.daily_trial_trend_title": {"zh-Hans":"近期进度走势", "en":"Recent Trend"},
	"ui.daily_trial_trend_empty": {"zh-Hans":"完成一次试炼后即可查看走势", "en":"Complete a trial to start tracking your trend"},
	"ui.trial_streak_reward_toast": {"zh-Hans":"每日试炼连续通关 %d 天！获得 %d 金币！", "en":"Daily Trial %d-day streak! Gained %d Gold!"},
	"ui.bestiary_discovery_toast": {"zh-Hans":"图鉴新发现「%s」！+%d 金币", "en":"New Bestiary Entry: %s! +%d Gold"},
	"ui.digest_ready_fmt": {"zh-Hans":"✦ %d 项奖励待领取", "en":"✦ %d rewards ready to claim"},
	"ui.compendium_milestones_title": {"zh-Hans":"探索里程碑", "en":"Discovery Milestones"},
	"ui.compendium_milestone_btn_fmt": {"zh-Hans":"达成 %d%% 探索", "en":"Reach %d%% Catalog"},
	"ui.compendium_milestone_claimed": {"zh-Hans":"已领取", "en":"Claimed"},
	"ui.compendium_milestone_toast": {"zh-Hans":"达成图鉴 %d%% 里程碑！获得奖励！", "en":"Reached Compendium %d%% Milestone! Reward claimed!"},
	"ui.settings_title": {"zh-Hans":"系统设置", "en":"Settings"},
	"ui.settings_sub": {"zh-Hans":"声音、语言与游戏偏好", "en":"Audio, language & preferences"},
	"ui.settings_lang": {"zh-Hans":"界面语言", "en":"Language"},
	"ui.settings_speed": {"zh-Hans":"战斗演出速度", "en":"Battle Speed"},
	"ui.settings_audio": {"zh-Hans":"背景音乐", "en":"Music Audio"},
	"ui.settings_audio_on": {"zh-Hans":"开启 ♫", "en":"Enabled ♫"},
	"ui.settings_audio_off": {"zh-Hans":"静音 ♩", "en":"Muted ♩"},
	"ui.settings_reduce_motion": {"zh-Hans":"减弱动态效果 (辅助功能)", "en":"Reduce Motion (Accessibility)"},
	"ui.settings_reduce_motion_desc": {"zh-Hans":"关闭粒子飘散与剧烈屏幕震颤", "en":"Disable ambient particles and screen shake"},
	"ui.settings_on": {"zh-Hans":"开启", "en":"On"},
	"ui.settings_off": {"zh-Hans":"关闭", "en":"Off"},
	"ui.settings_text_size": {"zh-Hans":"文字大小 (辅助功能)", "en":"Text Size (Accessibility)"},
	"ui.settings_text_size_small": {"zh-Hans":"小", "en":"Small"},
	"ui.settings_text_size_normal": {"zh-Hans":"标准", "en":"Standard"},
	"ui.settings_text_size_large": {"zh-Hans":"大", "en":"Large"},
	"ui.settings_text_size_xlarge": {"zh-Hans":"特大", "en":"Extra Large"},
	"ui.settings_btn": {"zh-Hans":"设置", "en":"Settings"},
	"ui.deck_filter_all": {"zh-Hans":"全部", "en":"All"},
	"ui.deck_filter_attack": {"zh-Hans":"攻击", "en":"Attack"},
	"ui.deck_filter_skill": {"zh-Hans":"技能", "en":"Skill"},
	"ui.deck_filter_power": {"zh-Hans":"能力", "en":"Power"},
	"ui.deck_filter_tactic": {"zh-Hans":"战术", "en":"Tactic"},
	"ui.deck_filter_elem_all": {"zh-Hans":"全部属性", "en":"All Elements"},
	"ui.deck_filter_elem_none": {"zh-Hans":"无属性", "en":"Neutral"},
	"ui.deck_filter_elem_fire": {"zh-Hans":"火", "en":"Fire"},
	"ui.deck_filter_elem_gale": {"zh-Hans":"风", "en":"Gale"},
	"ui.deck_filter_elem_stone": {"zh-Hans":"岩", "en":"Stone"},
	"ui.deck_filter_elem_water": {"zh-Hans":"水", "en":"Water"},
	"ui.deck_filter_elem_poison": {"zh-Hans":"毒", "en":"Poison"},
	"ui.deck_search_placeholder": {"zh-Hans":"搜索卡牌名称或效果...", "en":"Search card name or text..."},
	"ui.recap_title": {"zh-Hans":"✦ 战报数据回顾", "en":"✦ Battle Performance Recap"},
	"ui.recap_damage": {"zh-Hans":"造成伤害: %d", "en":"Damage Dealt: %d"},
	"ui.recap_cards": {"zh-Hans":"出牌次数: %d", "en":"Cards Played: %d"},
	"ui.recap_shield": {"zh-Hans":"获得护盾: %d", "en":"Shield Gained: %d"},
	"ui.settings_account": {"zh-Hans":"账号与云存档", "en":"Account & Cloud Save"},
	"ui.settings_account_desc": {"zh-Hans":"绑定 Apple 或 Google 账号以安全备份游戏进度并实现跨设备同步", "en":"Link Apple or Google account to back up save data and enable cross-device sync"},
	"ui.auth_apple": {"zh-Hans":"通过 Apple 登录", "en":"Sign in with Apple"},
	"ui.auth_google": {"zh-Hans":"通过 Google 登录", "en":"Sign in with Google"},
	"ui.auth_guest": {"zh-Hans":"游客账号", "en":"Guest Account"},
	"ui.auth_status_guest": {"zh-Hans":"当前为游客账号 (未绑定云端)", "en":"Currently Guest Account (Unlinked)"},
	"ui.auth_status_linked": {"zh-Hans":"已绑定 %s 账号", "en":"Linked with %s"},
	"ui.auth_linked_apple": {"zh-Hans":"已绑定 Apple 账号: %s", "en":"Linked Apple Account: %s"},
	"ui.auth_linked_google": {"zh-Hans":"已绑定 Google 账号: %s", "en":"Linked Google Account: %s"},
	"ui.auth_link_success": {"zh-Hans":"账号绑定成功！本地进度已完整合并同步。", "en":"Account linked! Local progress merged & saved."},
	"ui.auth_cloud_status": {"zh-Hans":"云存档状态", "en":"Cloud Save Status"},
	"ui.auth_cloud_synced": {"zh-Hans":"✓ 云端存档已就绪", "en":"✓ Cloud Save Ready"},
	"ui.auth_cloud_sync_now": {"zh-Hans":"立即同步到云端", "en":"Sync to Cloud Now"},
	"ui.auth_cloud_success": {"zh-Hans":"云端存档已成功更新！", "en":"Cloud save updated successfully!"},
	"ui.auth_sign_out": {"zh-Hans":"退出账号", "en":"Sign Out"},
	"ui.auth_sign_out_confirm": {"zh-Hans":"已退出账号，当前保留为本地游客数据。", "en":"Signed out. Retained as local guest data."},
	"ui.auth_quick_title": {"zh-Hans":"快捷登录", "en":"Quick Sign-In"},
	"ui.auth_guest_start": {"zh-Hans":"以游客身份体验", "en":"Continue as Guest"},
	"ui.season_pass_title": {"zh-Hans":"灵界通行证 · 季节远征", "en":"Spirit Pass · Season Journey"},
	"ui.season_pass_sub": {"zh-Hans":"第一赛季「灵火初醒」· 积累经验解锁秘宝", "en":"Season 1 「Awakening of Embers」 · Level up for rewards"},
	"ui.season_pass_level_fmt": {"zh-Hans":"通行证等级: Lv.%d", "en":"Pass Level: Lv.%d"},
	"ui.season_pass_xp_fmt": {"zh-Hans":"赛季经验: %d / %d XP", "en":"Season XP: %d / %d XP"},
	"ui.season_pass_free": {"zh-Hans":"基础远征轨", "en":"Free Track"},
	"ui.season_pass_premium": {"zh-Hans":"灵尊进阶轨", "en":"Spirit Track"},
	"ui.season_pass_claim_all": {"zh-Hans":"一键领取全部", "en":"Claim All"},
	"ui.season_pass_claimed": {"zh-Hans":"已领取", "en":"Claimed"},
	"ui.season_pass_levelup": {"zh-Hans":"灵界通行证升至 Lv.%d！秘宝已解锁！", "en":"Spirit Pass reached Lv.%d! Rewards unlocked!"},
	"ui.season_pass_banner_title": {"zh-Hans":"✦ 灵界通行证 · 第 1 赛季", "en":"✦ Spirit Pass · Season 1"},
	"ui.season_pass_view": {"zh-Hans":"查看远征", "en":"View Pass"},
	"ui.season_pass_claim": {"zh-Hans":"领取", "en":"Claim"},
	"ui.season_pass_locked": {"zh-Hans":"未解锁", "en":"Locked"},
	"ui.season_pass_tier_fmt": {"zh-Hans":"等级 %d", "en":"Tier %d"},
	"ui.season_pass_all_claimed_toast": {"zh-Hans":"已成功领取全部通行证秘宝！", "en":"All pass rewards claimed successfully!"},
	"ui.deck_code_btn_export": {"zh-Hans":"导出卡组", "en":"Export Code"},
	"ui.deck_code_btn_import": {"zh-Hans":"导入卡组", "en":"Import Code"},
	"ui.deck_code_copied": {"zh-Hans":"牌组代码已复制到剪贴板！", "en":"Deck code copied to clipboard!"},
	"ui.deck_code_imported": {"zh-Hans":"牌组代码导入成功！卡组已更新。", "en":"Deck code imported! Loadout updated."},
	"ui.deck_code_import_title": {"zh-Hans":"导入牌组代码", "en":"Import Deck Code"},
	"ui.deck_code_import_desc": {"zh-Hans":"输入或粘贴牌组分享代码：", "en":"Enter or paste a deck share code:"},
	"ui.deck_code_import_err": {"zh-Hans":"无效的牌组代码或卡牌拥有量不足！", "en":"Invalid deck code or insufficient cards in collection!"},
	"ui.draft_arena_title": {"zh-Hans":"灵界轮抽竞技场", "en":"Spirit Draft Arena"},
	"ui.draft_arena_sub": {"zh-Hans":"三选一轮抽卡牌 · 构筑牌组挑战六胜灵关", "en":"Draft 3-pick-1 · Build a deck for a 6-win gauntlet"},
	"ui.draft_round_fmt": {"zh-Hans":"轮抽进度: 第 %d / 7 轮", "en":"Draft Round: %d / 7"},
	"ui.draft_pick_card": {"zh-Hans":"请选择一张卡牌加入竞技场牌组", "en":"Select a card to add to your arena deck"},
	"ui.draft_deck_ready": {"zh-Hans":"竞技场构筑完成！开始试炼对决！", "en":"Arena deck complete! Enter gauntlet battles!"},
	"ui.draft_start_btn": {"zh-Hans":"开启轮抽试炼", "en":"Start Draft"},
	"ui.draft_continue_btn": {"zh-Hans":"继续试炼 (%d/6 胜)", "en":"Continue Run (%d/6 Wins)"},
	"ui.draft_abandon_btn": {"zh-Hans":"放弃本次轮抽", "en":"Abandon Run"},
	"ui.draft_win_fmt": {"zh-Hans":"当前战绩: %d 胜 / %d 负", "en":"Record: %d Wins / %d Losses"},
	"ui.draft_victory_toast": {"zh-Hans":"轮抽斩获第 %d 胜！获得 %d 金币与通行证经验！", "en":"Draft victory %d! Earned %d gold and pass XP!"},
	"ui.draft_grand_champion": {"zh-Hans":"✦ 恭喜达成六胜大圆满！荣膺灵界大宗师！", "en":"✦ 6-Win Grand Champion! Crowned Spirit Grandmaster!"},
	"ui.draft_run_ended": {"zh-Hans":"轮抽试炼结束！最终战绩: %d 胜。", "en":"Draft run completed! Final record: %d wins."},
	"desc.blaze_tempest": {"zh-Hans":"造成 %d 点伤害并施加 2 层灼烧。若目标处于灼烧状态，回复 1 点能量。", "en":"Deal %d damage and apply 2 Burn. If target is Burning, refund 1 Energy."},
	"desc.toxic_quake": {"zh-Hans":"造成 %d 点伤害，施加 3 层剧毒，并根据目标剧毒层数获得等量护盾。", "en":"Deal %d damage, apply 3 Poison, and gain Shield equal to target's Poison."},
	"desc.frost_surge": {"zh-Hans":"获得 %d 点护盾，抽 2 张牌，对所有敌人施加 1 层虚弱。", "en":"Gain %d Shield, draw 2 cards, and apply 1 Weak to all enemies."},
	"desc.soul_pyre": {"zh-Hans":"对所有敌人造成 %d 点伤害并施加 2 层灼烧，抽 1 张牌。", "en":"Deal %d damage and 2 Burn to all enemies. Draw 1 card."},
	"desc.gale_barrier": {"zh-Hans":"获得 %d 点护盾，本回合获得 1 点额外能量。", "en":"Gain %d Shield and +1 Energy this turn."},
	"desc.miasma_shield": {"zh-Hans":"获得 %d 点护盾，回复 3 点生命。", "en":"Gain %d Shield and recover 3 Health."},
	"ui.battle_log_title": {"zh-Hans":"战报详情", "en":"Battle Log"},
	"ui.battle_log_view_btn": {"zh-Hans":"查看战报", "en":"View Battle Log"},
	"ui.battle_log_empty": {"zh-Hans":"暂无战斗记录。", "en":"No battle events recorded."},
	"ui.run_recap_view_btn": {"zh-Hans":"查看战报分享卡", "en":"View Run Recap"},
	"ui.run_recap_title": {"zh-Hans":"首领征服战报", "en":"Boss Conquest Recap"},
	"ui.run_recap_defeated_fmt": {"zh-Hans":"击败了 %s", "en":"Defeated %s"},
	"ui.run_recap_share_hint": {"zh-Hans":"长按截图，分享你的胜利吧！", "en":"Screenshot this card to share your victory!"},
	"ui.run_recap_done": {"zh-Hans":"返回", "en":"Back"},
	"ui.log_turn_fmt": {"zh-Hans":"── 第 %d 回合 ──", "en":"── Turn %d ──"},
	"ui.log_card_damage_fmt": {"zh-Hans":"打出「%s」，造成 %d 点伤害", "en":"Played %s, dealt %d damage"},
	"ui.log_card_play_fmt": {"zh-Hans":"打出「%s」", "en":"Played %s"},
	"ui.log_hit_fmt": {"zh-Hans":"敌方受到 %d 点伤害", "en":"Enemy took %d damage"},
	"ui.log_death": {"zh-Hans":"敌人被击败", "en":"Enemy defeated"},
	"ui.log_player_hit_fmt": {"zh-Hans":"你受到 %d 点伤害", "en":"You took %d damage"},
	"ui.log_player_burn_fmt": {"zh-Hans":"灼烧造成 %d 点伤害", "en":"Burn dealt %d damage"},
	"ui.log_equipment_fmt": {"zh-Hans":"%s 效果触发", "en":"%s triggered"},
	"ui.log_thorns_fmt": {"zh-Hans":"反伤造成 %d 点伤害", "en":"Thorns dealt %d damage"},
	"ui.log_revive_fmt": {"zh-Hans":"敌人复活，恢复至 %d 点生命", "en":"Enemy revived with %d HP"},
	"ui.log_dodge": {"zh-Hans":"敌人闪避了攻击", "en":"Enemy dodged the attack"},
	"ui.log_rune_set": {"zh-Hans":"符文共鸣触发", "en":"Rune Resonance triggered"},
	"ui.boss_rush_title": {"zh-Hans":"首领连战", "en":"Boss Rush"},
	"ui.boss_rush_sub": {"zh-Hans":"连续挑战已征服的首领，负伤不愈合", "en":"Refight bosses you've beaten back-to-back, wounds carry over"},
	"ui.boss_rush_floor_fmt": {"zh-Hans":"连战 %d 场", "en":"Bout %d"},
	"ui.boss_rush_record_fmt": {"zh-Hans":"最佳战绩 %d 场", "en":"Best Streak %d"},
	"ui.boss_rush_enter": {"zh-Hans":"进入连战", "en":"Enter Boss Rush"},
	"ui.boss_rush_stage_label_fmt": {"zh-Hans":"首领连战 · 第 %d 场", "en":"Boss Rush · Bout %d"},
	"ui.boss_rush_progress_reward_fmt": {"zh-Hans":"连战进度 %d 场，敌人愈发强大！", "en":"Boss Rush progress: %d bouts. Enemies grow stronger!"},
	"ui.boss_rush_no_boss": {"zh-Hans":"尚未击败任何首领", "en":"No bosses reached yet"},
	"ui.awaken_btn": {"zh-Hans":"觉醒", "en":"Awaken"},
	"ui.awakened_label": {"zh-Hans":"已觉醒", "en":"Awakened"},
	"ui.awakened_toast_fmt": {"zh-Hans":"%s 已觉醒为 +2！", "en":"%s has Awakened to +2!"},
	"ui.sandbox_title": {"zh-Hans":"沙盘演练", "en":"Sandbox"},
	"ui.sandbox_sub": {"zh-Hans":"用当前牌组自由试练已抵达的关卡，满血进入，胜负均不影响存档", "en":"Freely test your current deck against any stage you've reached — full health, no rewards, win or lose changes nothing"},
	"ui.sandbox_enter": {"zh-Hans":"进入演练", "en":"Enter Sandbox"},
	"ui.sandbox_stage_label_fmt": {"zh-Hans":"沙盘演练 · %s", "en":"Sandbox · %s"},
	"ui.sandbox_complete_toast": {"zh-Hans":"演练结束，存档未受影响", "en":"Practice complete — your save is unaffected"},
	"ui.idle_harvest_title": {"zh-Hans":"宗门灵修", "en":"Spirit Cultivation"},
	"ui.idle_harvest_sub": {"zh-Hans":"离线灵气凝聚 · 关卡越高产出越丰厚", "en":"Offline Spiritual Harvest · Scales with stage progress"},
	"ui.idle_harvest_rate_fmt": {"zh-Hans":"产出速率: %d 灵石/小时", "en":"Rate: %d Gold/Hour"},
	"ui.idle_harvest_acc_fmt": {"zh-Hans":"已凝聚灵石: %d", "en":"Accumulated Gold: %d"},
	"ui.idle_harvest_cap_fmt": {"zh-Hans":"灵气蓄水池: %d / 12 小时", "en":"Reservoir: %d / 12 Hours"},
	"ui.idle_harvest_claim": {"zh-Hans":"收纳灵石", "en":"Harvest Gold"},
	"ui.idle_harvest_fast": {"zh-Hans":"灵脉飞升 (获取2小时收益)", "en":"Burst Cultivation (+2h)"},
	"ui.idle_harvest_fast_done": {"zh-Hans":"今日已飞升", "en":"Claimed Today"},
	"ui.idle_harvest_toast": {"zh-Hans":"成功纳灵获得 %d 灵石！", "en":"Harvested %d Gold!"},
	"ui.idle_harvest_fast_toast": {"zh-Hans":"灵脉飞升！瞬间凝聚获得 %d 灵石！", "en":"Burst Cultivation! Gained %d Gold!"},
	"ui.idle_harvest_nav": {"zh-Hans":"灵修", "en":"Cultivate"},
	"ui.idle_harvest_pill_fmt": {"zh-Hans":"灵修 +%d", "en":"AFK +%d"},
	"ui.stage_purified_title": {"zh-Hans":"灵脉已净化", "en":"Leyline Purified"},
	"ui.stage_purified_desc": {"zh-Hans":"该关卡妖煞已被彻底荡涤，不可重复刷取！\n如遇当前关卡阻碍，请通过宗门灵修、精简卡组或虚影演武突破瓶颈。", "en":"This node is fully purified! Past stages cannot be farmed repeatedly.\nWhen stuck, cultivate AFK, tune your deck, or challenge Phantoms."},
	"ui.stage_purified_goto_cultivate": {"zh-Hans":"宗门灵修", "en":"Cultivate"},
	"ui.stage_purified_goto_deck": {"zh-Hans":"精简卡组", "en":"Tune Deck"},
	"ui.stage_purified_goto_phantom": {"zh-Hans":"虚影演武", "en":"Phantom Arena"},
	"ui.defeat_diag_title": {"zh-Hans":"✦ 仙途复盘与破局建议", "en":"✦ Battle Diagnostics & Tactics"},
	"ui.defeat_diag_high_cost": {"zh-Hans":"【卡组沉重】平均卡牌费用高达 %.1f 费，导致卡手空过。建议封印冗余高费卡，增加低费灵牌。", "en":"【Heavy Deck】Average card cost is %.1f. High-cost cards clog hand. Consider purging heavy cards."},
	"ui.defeat_diag_low_shield": {"zh-Hans":"【防御薄弱】卡组防御牌较少（仅 %d 张）。面对敌方猛烈攻势难以招架，建议携带【灵盾】或护身符。", "en":"【Fragile Defense】Few shield cards (%d). Hard to survive telegraphed hits. Add Spirit Shields or defensive gear."},
	"ui.defeat_diag_boss_thorns": {"zh-Hans":"【反伤克制】敌人拥有荆棘反伤，频繁轻击反受其害。建议携带单次高爆发或破甲重击。", "en":"【Thorns Threat】Enemy has thorns! Multi-hits hurt self. Rely on single-hit bursts or heavy strikes."},
	"ui.defeat_diag_boss_armor": {"zh-Hans":"【坚甲难破】敌人护盾极高。建议在铁匠铺升级贯穿/穿透符文，或选用破甲流派。", "en":"【Armor Wall】Enemy stacks heavy shield. Use armor-piercing or burn runes."},
	"ui.defeat_diag_general": {"zh-Hans":"【修为瓶颈】当前首领战力凶悍。可前往【宗门灵修】积攒灵石升级法宝，或精炼核心卡牌！", "en":"【Bottleneck】Boss is formidable. Gather AFK harvest to upgrade gear, or tune core cards!"},
	"ui.defeat_btn_tune_deck": {"zh-Hans":"去精简卡组", "en":"Tune Deck"},
	"ui.defeat_btn_cultivate": {"zh-Hans":"去宗门灵修", "en":"Cultivate"},
	"ui.phantom_arena_title": {"zh-Hans":"虚影论剑台", "en":"Phantom Arena"},
	"ui.phantom_arena_sub": {"zh-Hans":"同境界修士虚影切磋 · 每日切磋赢取论剑秘宝", "en":"Duel Cultivator Phantoms · Daily chests & rune rewards"},
	"ui.phantom_arena_challenge": {"zh-Hans":"切磋论剑", "en":"Duel Phantom"},
	"ui.phantom_arena_daily_won": {"zh-Hans":"今日胜场: %d / 3", "en":"Today's Wins: %d / 3"},
	"ui.phantom_arena_claimed": {"zh-Hans":"今日论剑宝匣已领取", "en":"Daily Chest Claimed"},
	"ui.phantom_arena_claim_box": {"zh-Hans":"开启论剑宝匣", "en":"Open Duel Chest"},
	"ui.phantom_arena_chest_toast": {"zh-Hans":"论剑宝匣开启：获得 %d 灵石！", "en":"Duel Chest: Gained %d Gold!"},
	"ui.run_recap_deck_highlights": {"zh-Hans":"牌组核心亮点", "en":"Deck Highlights"},
	"ui.run_recap_share_btn": {"zh-Hans":"保存/分享战报", "en":"Share / Save Recap"},
	"ui.run_recap_saved_toast": {"zh-Hans":"战报已生成！截图即可分享给道友。", "en":"Recap generated! Screenshot to share with peers."},
	"ui.currency_gold": {"zh-Hans":"金币", "en":"Gold"},
	"ui.currency_jade": {"zh-Hans":"灵玉", "en":"Spirit Jade"},
	"ui.currency_dust": {"zh-Hans":"灵尘", "en":"Spirit Dust"},
	"ui.shop_tab_curated": {"zh-Hans":"精选行商", "en":"Curated Stock"},
	"ui.shop_tab_exchange": {"zh-Hans":"灵卡置换", "en":"Card Exchange"},
	"ui.shop_recycle_card": {"zh-Hans":"炼化分解", "en":"Recycle"},
	"ui.shop_craft_card": {"zh-Hans":"凝聚置换", "en":"Transmute"},
	"ui.shop_soulbound": {"zh-Hans":"专属绑定不可分解", "en":"Soulbound"},
	"ui.shop_pack_title": {"zh-Hans":"万象灵卡秘袋", "en":"Spirit Mystery Pack"},
	"ui.shop_pack_sub": {"zh-Hans":"随机凝聚 3 张灵卡 · 保底罕见+", "en":"Summon 3 random cards · Guaranteed Uncommon+"},
	"ui.shop_relic_slot": {"zh-Hans":"古灵秘宝", "en":"Ancient Relic"},
	"ui.shop_rune_slot": {"zh-Hans":"太古符文", "en":"Primal Rune"},
	"ui.recycle_success_toast": {"zh-Hans":"炼化成功，获得 +%d 灵尘", "en":"Recycled! Gained +%d Spirit Dust"},
	"ui.transmute_success_toast": {"zh-Hans":"凝聚成功，获得《%s》！", "en":"Transmuted! Obtained %s!"},
	"ui.insufficient_dust": {"zh-Hans":"灵尘不足，无法凝聚！", "en":"Insufficient Spirit Dust!"},
	"ui.insufficient_jade": {"zh-Hans":"灵玉不足！", "en":"Insufficient Spirit Jade!"},
	"ui.shop_pack_opened": {"zh-Hans":"秘袋开启！斩获 3 张全新灵卡！", "en":"Pack opened! Obtained 3 new spirit cards!"},
	"tutorial.understood": {"zh-Hans":"我明白了", "en":"Understood"},
	"tutorial.rune_resonance.title": {"zh-Hans":"符文共鸣机制", "en":"Rune Resonance"},
	"tutorial.rune_resonance.desc": {"zh-Hans":"在同一牌组中镶嵌成套的符文（如疾风+循环、灼烧+处决），将唤醒强力的全场共鸣被动效果，极大增强战斗战力！", "en":"Socket matching rune sets in your deck (e.g. Swift+Cycle, Burning+Execute) to activate powerful passive battle resonance buffs!"},
	"tutorial.card_exchange.title": {"zh-Hans":"灵卡置换与分解", "en":"Card Exchange & Recycling"},
	"tutorial.card_exchange.desc": {"zh-Hans":"多余或闲置的非基础卡牌可以在此炼化为【灵尘】。消耗灵尘可自由凝聚置换你所需的强力流派核心卡牌！未来还将支持驭灵者之间的直接置换交易。", "en":"Recycle extra non-starter cards into Spirit Dust. Spend dust to directly craft and transmute your desired archetype cards! Ready for future player trading."},
	"tutorial.rest_purify.title": {"zh-Hans":"神圣营火仪式", "en":"Sacred Campfire Rituals"},
	"tutorial.rest_purify.desc": {"zh-Hans":"在营火休整点，你不仅能回复生命，还能在净化祭坛将基础卡牌蜕变为精英灵卡，或前往灵匠处永久强化卡牌属性！", "en":"At sacred campfires, you can heal HP, purify basic cards into elite spirit arts at the altar, or forge permanent +1 upgrades at the smith!"},
	"tutorial.daily_trial.title": {"zh-Hans":"每日试炼挑战", "en":"Daily Trial Gauntlet"},
	"tutorial.daily_trial.desc": {"zh-Hans":"每日全服轮换相同的词条组合，挑战 15 层极限试炼，赢取丰厚金币、灵玉与连续通关宝箱！", "en":"Tackle 15 stages with rotating global affixes each day to claim generous Gold, Spirit Jade, and streak rewards!"},
	"tutorial.abyss.title": {"zh-Hans":"无尽深渊幻境", "en":"Endless Abyss"},
	"tutorial.abyss.desc": {"zh-Hans":"向深渊最底层进发！每层战胜后挑选强力恩惠，敌人的攻防随层数无限攀升，测试你牌组构筑的终极极限！", "en":"Descend into the infinite depths! Choose blessings after each floor as foes scale relentlessly. The ultimate deck test!"},
	"ui.treasury_title": {"zh-Hans":"灵界珍宝库", "en":"Spirit Treasury"},
	"ui.treasury_sub": {"zh-Hans":"资产盘点与灵物炼化置换", "en":"Asset Ledger & Resource Alchemy"},
	"ui.treasury_gold_desc": {"zh-Hans":"常规行商货币，用于商店日常购牌、删牌净化与卡牌升级。", "en":"Standard currency for shop items, purges, and upgrades."},
	"ui.treasury_jade_desc": {"zh-Hans":"天地至纯灵玉，章节大捷、成就与试炼斩获，换取高阶秘宝与灵袋。", "en":"Premium meta-currency for booster packs and rare relics."},
	"ui.treasury_dust_desc": {"zh-Hans":"灵卡炼解灵源，用于自由凝聚合成专属流派神卡（兼容P2P）。", "en":"Alchemical dust from card salvage, used to forge target cards."},
	"ui.treasury_convert_gold_dust": {"zh-Hans":"金币提炼灵尘 (80金币 → 35灵尘)", "en":"Alchemize Dust (80 Gold → 35 Dust)"},
	"ui.treasury_convert_jade_gold": {"zh-Hans":"灵玉兑换金币 (10灵玉 → 150金币)", "en":"Exchange Gold (10 Jade → 150 Gold)"},
	"ui.treasury_goto_shop": {"zh-Hans":"前往精选行商", "en":"Visit Curated Shop"},
	"ui.treasury_goto_exchange": {"zh-Hans":"前往灵卡置换", "en":"Visit Card Exchange"},
	"ui.convert_success": {"zh-Hans":"兑换完成！资产已更新。", "en":"Exchange successful! Balance updated."},
	"ui.convert_insufficient": {"zh-Hans":"当前资产不足，无法兑换！", "en":"Insufficient funds for exchange!"},
	"ui.daily_first_win_title": {"zh-Hans":"今日首胜大捷！", "en":"First Win of the Day!"},
	"ui.daily_first_win_desc": {"zh-Hans":"获得首胜天赐：+50 金币 · +5 灵玉", "en":"First Win Bonus: +50 Gold · +5 Spirit Jade"},
	"ui.novice_journey_title": {"zh-Hans":"七日修行录", "en":"7-Day Novice Journey"},
	"ui.novice_journey_sub": {"zh-Hans":"初入灵界的新人试炼 · 达成目标领取海量修行资粮", "en":"New traveler trials · Complete daily goals for bountiful rewards"},
	"ui.novice_day_fmt": {"zh-Hans":"第 %d 天", "en":"Day %d"},
	"ui.novice_completed": {"zh-Hans":"已完成", "en":"Completed"},
	"ui.novice_claim": {"zh-Hans":"领取", "en":"Claim"},
	"ui.novice_claimed": {"zh-Hans":"已领取", "en":"Claimed"},
	"ui.novice_locked": {"zh-Hans":"未达成", "en":"Locked"},
	"ui.novice_reward_toast": {"zh-Hans":"七日修行第 %d 天达成！获得修行大礼包！", "en":"Day %d Novice Trial cleared! Rewards claimed!"},
	"ui.shop_specialties": {"zh-Hans":"秘境灵药与奇珍", "en":"Rare Specialties & Elixirs"},
	"ui.shop_upgrade_stone_pick": {"zh-Hans":"请选择要强化的卡牌 (+1)", "en":"Select a card to upgrade (+1)"},
	"ui.shop_item_bought": {"zh-Hans":"已购买并生效：%s", "en":"Purchased & activated: %s"},
	"ui.shop_card_upgraded": {"zh-Hans":"灵火淬炼成功：%s 已强化为 +1！", "en":"Card forged: %s upgraded to +1!"},
	"tutorial.shop_overview.title": {"zh-Hans":"灵界集市指南", "en":"Bazaar Guide"},
	"tutorial.shop_overview.desc": {"zh-Hans":"集市每日轮换优惠卡牌与秘宝。你可以在此购买强效秘药，或前往【灵卡置换】分解多余卡牌并合成心仪神卡！", "en":"The Bazaar features daily discounted cards and rare items. Purchase powerful battle elixirs, or visit Card Exchange to salvage duplicates and forge target cards!"},
	"tutorial.deck_synergies.title": {"zh-Hans":"卡牌协同指南", "en":"Card Synergy Guide"},
	"tutorial.deck_synergies.desc": {"zh-Hans":"注意卡牌上的属性与协同标记（🔥燃烧、☣剧毒、💢易伤、⬢护盾）。相同流派与属性的卡牌相互呼应，能产生质变的连锁威力！", "en":"Watch for element & synergy tags on your cards (🔥Burn, ☣Poison, 💢Vulnerable, ⬢Shield). Combining cards of the same archetype triggers powerful chain reactions!"},
	"tutorial.combat_survival.title": {"zh-Hans":"危机应对秘诀", "en":"Combat Survival Tip"},
	"tutorial.combat_survival.desc": {"zh-Hans":"生命值较低时，请优先使用护盾牌！密切留意敌人的意图指示（攻击、强化或减益），在敌人蓄力爆发前回合提前叠甲！", "en":"When HP is low, prioritize shield cards! Keep a close eye on enemy intent banners to stack shield before their heavy attacks strike!"},
	"ui.stamina_name": {"zh-Hans":"灵力", "en":"Stamina"},
	"ui.stamina_fmt": {"zh-Hans":"%d / %d", "en":"%d / %d"},
	"ui.stamina_title": {"zh-Hans":"灵元气海 · 体力", "en":"Spiritual Energy Reservoir"},
	"ui.stamina_desc": {"zh-Hans":"挑战关卡消耗 5 点灵力。每 5 分钟自然恢复 1 点灵力。", "en":"Entering a stage costs 5 Stamina. 1 Stamina regenerates every 5 minutes."},
	"ui.stamina_next_regen": {"zh-Hans":"下一点恢复: %s", "en":"Next recharge in: %s"},
	"ui.stamina_full": {"zh-Hans":"灵元已充盈 (100/100)", "en":"Fully Charged (100/100)"},
	"ui.stamina_recharge_btn": {"zh-Hans":"灵玉纳气 (+50 灵力 · 10 灵玉)", "en":"Recharge (+50 Stamina · 10 Jade)"},
	"ui.stamina_recharge_success": {"zh-Hans":"纳气成功！充盈 50 点灵力。", "en":"Recharge successful! +50 Stamina gained."},
	"ui.stamina_recharge_no_jade": {"zh-Hans":"灵玉不足，无法充能！", "en":"Insufficient Spirit Jade for recharge!"},
	"ui.stamina_insufficient": {"zh-Hans":"灵力不足，无法挑战！请稍候恢复或使用灵玉充盈。", "en":"Insufficient Stamina! Please wait for recharge or use Spirit Jade."},
	"ui.auto_battle": {"zh-Hans":"自动", "en":"AUTO"},
	"ui.auto_battle_active": {"zh-Hans":"挂机中", "en":"AUTO ON"},
	"ui.auto_push_btn": {"zh-Hans":"挂机推图", "en":"Auto-Push"},
	"ui.auto_push_title": {"zh-Hans":"一键挂机推图", "en":"Auto-Battle Progression"},
	"ui.auto_push_desc": {"zh-Hans":"自动战斗、自动领取最优战利品并自动步进下一关，直到战败或体力耗尽。", "en":"Auto-battles, collects best card rewards, and advances stages until defeat or out of stamina."},
	"ui.auto_stop_defeat": {"zh-Hans":"挂机推图停止：战斗失败，止步于当前关卡。", "en":"Auto-push stopped: Defeated in battle."},
	"ui.auto_stop_stamina": {"zh-Hans":"挂机推图停止：灵力耗尽，请稍作调息。", "en":"Auto-push stopped: Out of Stamina."},
	"ui.auto_stop_manual": {"zh-Hans":"已停止挂机推图。", "en":"Auto-push stopped manually."},
	"ui.auto_summary_toast": {"zh-Hans":"挂机完成！连克 %d 关，斩获 %d 灵石！", "en":"Auto-push finished! Cleared %d stages, gained %d Gold!"},
	"ui.resonance_combustion": {"zh-Hans":"【灵火燎原】五行共鸣！烈焰波及全场敌人 3 点伤害！", "en":"[Combustion] Elemental Resonance! 3 splash damage to all enemies!"},
	"ui.resonance_sunder": {"zh-Hans":"【破甲震荡】五行共鸣！削减护盾并施加易伤！", "en":"[Sunder] Elemental Resonance! Shattered shield & applied Vulnerable!"},
	"ui.resonance_fortify": {"zh-Hans":"【金石磐石】五行共鸣！稳固身形获得 +4 护盾！", "en":"[Fortify] Elemental Resonance! Gained +4 bonus Shield!"},
}

func ui(key: String, language := "zh-Hans") -> String:
	var entry: Dictionary = UI_TEXT.get(key, {})
	if entry.is_empty(): return text(key, language)
	return str(entry.get(language, entry.get("en", key)))

func equip_name(item: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return item.get("en", item.get("zh", ""))
	return item.get("zh", "")

func equip_detail(item: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return item.get("detail_en", item.get("detail", ""))
	return item.get("detail", "")

func rune_name(rune: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return rune.get("en", rune.get("zh", ""))
	return rune.get("zh", "")

func rune_detail(rune: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return rune.get("detail_en", rune.get("detail", ""))
	return rune.get("detail", "")
