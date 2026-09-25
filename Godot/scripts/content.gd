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
const ENEMIES: Array[Dictionary] = [
	{"id":"m_s001", "realm":1, "tier":1, "element":"wood", "tint":"83e4c1", "name":"雾林小妖", "name_en":"Mistwood Imp", "art":"res://assets/characters/monsters/m_s001.png", "art_key":"m_s001", "lore":"游荡在雾林边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Mistwood, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s002", "realm":1, "tier":1, "element":"earth", "tint":"d4a373", "name":"雾林狂蜂", "name_en":"Mistwood Wasp", "art":"res://assets/characters/monsters/m_s002.png", "art_key":"m_s002", "lore":"驻扎在雾林险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Mistwood's choke points, famed for crushing charges."},
	{"id":"m_s003", "realm":1, "tier":2, "element":"earth", "tint":"d4a373", "name":"雾林守望使", "name_en":"Mistwood Warden", "art":"res://assets/characters/monsters/m_s003.png", "art_key":"m_s003", "lore":"雾林中的精锐守关强者，周身环绕着浓郁的earth之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Mistwood, enveloped in dense earth essence that blunts incoming blows."},
	{"id":"m_s004", "realm":1, "tier":2, "element":"fire", "tint":"f0932b", "name":"雾林暴君护法", "name_en":"Mistwood Tyrant Enforcer", "art":"res://assets/characters/monsters/m_s004.png", "art_key":"m_s004", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s005", "realm":1, "tier":3, "element":"fire", "tint":"f0932b", "name":"雾林领主", "name_en":"Mistwood Lord", "art":"res://assets/characters/monsters/m_s005.png", "art_key":"m_s005", "lore":"盘踞于雾林核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Mistwood, crushing all who dare contest its reign."},
	{"id":"m_s006", "realm":1, "tier":1, "element":"fire", "tint":"f0932b", "name":"烬河三角洲斥候", "name_en":"Ember Delta Scout", "art":"res://assets/characters/monsters/m_s006.png", "art_key":"m_s006", "lore":"游荡在烬河三角洲边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Ember Delta, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s007", "realm":1, "tier":1, "element":"earth", "tint":"d4a373", "name":"烬河三角洲铁甲卫", "name_en":"Ember Delta Armored Guard", "art":"res://assets/characters/monsters/m_s007.png", "art_key":"m_s007", "lore":"驻扎在烬河三角洲险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Ember Delta's choke points, famed for crushing charges."},
	{"id":"m_s008", "realm":1, "tier":2, "element":"earth", "tint":"d4a373", "name":"烬河三角洲精英祭司", "name_en":"Ember Delta High Priest", "art":"res://assets/characters/monsters/m_s008.png", "art_key":"m_s008", "lore":"烬河三角洲中的精锐守关强者，周身环绕着浓郁的earth之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Ember Delta, enveloped in dense earth essence that blunts incoming blows."},
	{"id":"m_s009", "realm":1, "tier":2, "element":"wood", "tint":"83e4c1", "name":"烬河三角洲狂乱使徒", "name_en":"Ember Delta Chaos Apostle", "art":"res://assets/characters/monsters/m_s009.png", "art_key":"m_s009", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s010", "realm":1, "tier":3, "element":"wood", "tint":"83e4c1", "name":"烬河三角洲霸主", "name_en":"Ember Delta Apex Tyrant", "art":"res://assets/characters/monsters/m_s010.png", "art_key":"m_s010", "lore":"盘踞于烬河三角洲核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Ember Delta, crushing all who dare contest its reign."},
	{"id":"m_s011", "realm":1, "tier":1, "element":"thunder", "tint":"58b8ff", "name":"雷鸣群峰幼兽", "name_en":"Thunder Peaks Hatchling", "art":"res://assets/characters/monsters/m_s011.png", "art_key":"m_s011", "lore":"游荡在雷鸣群峰边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Thunder Peaks, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s012", "realm":1, "tier":1, "element":"earth", "tint":"d4a373", "name":"雷鸣群峰灵蛇", "name_en":"Thunder Peaks Serpent", "art":"res://assets/characters/monsters/m_s012.png", "art_key":"m_s012", "lore":"驻扎在雷鸣群峰险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Thunder Peaks's choke points, famed for crushing charges."},
	{"id":"m_s013", "realm":1, "tier":2, "element":"earth", "tint":"d4a373", "name":"雷鸣群峰统领", "name_en":"Thunder Peaks Captain", "art":"res://assets/characters/monsters/m_s013.png", "art_key":"m_s013", "lore":"雷鸣群峰中的精锐守关强者，周身环绕着浓郁的earth之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Thunder Peaks, enveloped in dense earth essence that blunts incoming blows."},
	{"id":"m_s014", "realm":1, "tier":2, "element":"fire", "tint":"f0932b", "name":"雷鸣群峰血契尊者", "name_en":"Thunder Peaks Bloodbound Master", "art":"res://assets/characters/monsters/m_s014.png", "art_key":"m_s014", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s015", "realm":1, "tier":3, "element":"fire", "tint":"f0932b", "name":"雷鸣群峰巨神", "name_en":"Thunder Peaks Colossus King", "art":"res://assets/characters/monsters/m_s015.png", "art_key":"m_s015", "lore":"盘踞于雷鸣群峰核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Thunder Peaks, crushing all who dare contest its reign."},
	{"id":"m_s016", "realm":1, "tier":1, "element":"earth", "tint":"d4a373", "name":"岩甲城塞灵偶", "name_en":"Stone Citadel Effigy", "art":"res://assets/characters/monsters/m_s016.png", "art_key":"m_s016", "lore":"游荡在岩甲城塞边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Stone Citadel, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s017", "realm":1, "tier":1, "element":"wood", "tint":"83e4c1", "name":"岩甲城塞恶犬", "name_en":"Stone Citadel Hound", "art":"res://assets/characters/monsters/m_s017.png", "art_key":"m_s017", "lore":"驻扎在岩甲城塞险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Stone Citadel's choke points, famed for crushing charges."},
	{"id":"m_s018", "realm":1, "tier":2, "element":"wood", "tint":"83e4c1", "name":"岩甲城塞巨像", "name_en":"Stone Citadel Colossus", "art":"res://assets/characters/monsters/m_s018.png", "art_key":"m_s018", "lore":"岩甲城塞中的精锐守关强者，周身环绕着浓郁的wood之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Stone Citadel, enveloped in dense wood essence that blunts incoming blows."},
	{"id":"m_s019", "realm":1, "tier":2, "element":"earth", "tint":"d4a373", "name":"岩甲城塞寂灭行刑官", "name_en":"Stone Citadel Executioner", "art":"res://assets/characters/monsters/m_s019.png", "art_key":"m_s019", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s020", "realm":1, "tier":3, "element":"earth", "tint":"d4a373", "name":"岩甲城塞主宰者", "name_en":"Stone Citadel Dominator", "art":"res://assets/characters/monsters/m_s020.png", "art_key":"m_s020", "lore":"盘踞于岩甲城塞核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Stone Citadel, crushing all who dare contest its reign."},
	{"id":"m_s021", "realm":1, "tier":1, "element":"wood", "tint":"83e4c1", "name":"荆棘荒野微粒", "name_en":"Thorn Wilds Wisp", "art":"res://assets/characters/monsters/m_s021.png", "art_key":"m_s021", "lore":"游荡在荆棘荒野边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Thorn Wilds, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s022", "realm":1, "tier":1, "element":"poison", "tint":"9b59b6", "name":"荆棘荒野巨蜥", "name_en":"Thorn Wilds Lizard", "art":"res://assets/characters/monsters/m_s022.png", "art_key":"m_s022", "lore":"驻扎在荆棘荒野险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Thorn Wilds's choke points, famed for crushing charges."},
	{"id":"m_s023", "realm":1, "tier":2, "element":"poison", "tint":"9b59b6", "name":"荆棘荒野战魁", "name_en":"Thorn Wilds Mauler", "art":"res://assets/characters/monsters/m_s023.png", "art_key":"m_s023", "lore":"荆棘荒野中的精锐守关强者，周身环绕着浓郁的poison之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Thorn Wilds, enveloped in dense poison essence that blunts incoming blows."},
	{"id":"m_s024", "realm":1, "tier":2, "element":"wood", "tint":"83e4c1", "name":"荆棘荒野天罚武尊", "name_en":"Thorn Wilds Punisher", "art":"res://assets/characters/monsters/m_s024.png", "art_key":"m_s024", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s025", "realm":1, "tier":3, "element":"wood", "tint":"83e4c1", "name":"荆棘荒野大祭司长", "name_en":"Thorn Wilds Arch-Hierophant", "art":"res://assets/characters/monsters/m_s025.png", "art_key":"m_s025", "lore":"盘踞于荆棘荒野核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Thorn Wilds, crushing all who dare contest its reign.", "mechanics":{"mark_hand_penalty":6, "mark_hand_threshold":3}},
	{"id":"m_s026", "realm":1, "tier":1, "element":"water", "tint":"3498db", "name":"万灵潮汐哨兵", "name_en":"Spirit Tide Sentry", "art":"res://assets/characters/monsters/m_s026.png", "art_key":"m_s026", "lore":"游荡在万灵潮汐边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Spirit Tide, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s027", "realm":1, "tier":1, "element":"wood", "tint":"83e4c1", "name":"万灵潮汐石蝠", "name_en":"Spirit Tide Bat", "art":"res://assets/characters/monsters/m_s027.png", "art_key":"m_s027", "lore":"驻扎在万灵潮汐险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Spirit Tide's choke points, famed for crushing charges."},
	{"id":"m_s028", "realm":1, "tier":2, "element":"wood", "tint":"83e4c1", "name":"万灵潮汐煞灵使", "name_en":"Spirit Tide Wraith Lord", "art":"res://assets/characters/monsters/m_s028.png", "art_key":"m_s028", "lore":"万灵潮汐中的精锐守关强者，周身环绕着浓郁的wood之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Spirit Tide, enveloped in dense wood essence that blunts incoming blows."},
	{"id":"m_s029", "realm":1, "tier":2, "element":"water", "tint":"3498db", "name":"万灵潮汐灵核掌控者", "name_en":"Spirit Tide Core Keeper", "art":"res://assets/characters/monsters/m_s029.png", "art_key":"m_s029", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s030", "realm":1, "tier":3, "element":"water", "tint":"3498db", "name":"万灵潮汐领主", "name_en":"Spirit Tide Lord", "art":"res://assets/characters/monsters/m_s030.png", "art_key":"m_s030", "lore":"盘踞于万灵潮汐核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Spirit Tide, crushing all who dare contest its reign."},
	{"id":"m_s031", "realm":1, "tier":1, "element":"wood", "tint":"83e4c1", "name":"翠玉圣域步卒", "name_en":"Jade Sanctuary Footman", "art":"res://assets/characters/monsters/m_s031.png", "art_key":"m_s031", "lore":"游荡在翠玉圣域边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Jade Sanctuary, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s032", "realm":1, "tier":1, "element":"celestial", "tint":"ffd700", "name":"翠玉圣域战卒", "name_en":"Jade Sanctuary Fighter", "art":"res://assets/characters/monsters/m_s032.png", "art_key":"m_s032", "lore":"驻扎在翠玉圣域险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Jade Sanctuary's choke points, famed for crushing charges."},
	{"id":"m_s033", "realm":1, "tier":2, "element":"celestial", "tint":"ffd700", "name":"翠玉圣域破空者", "name_en":"Jade Sanctuary Skycleaver", "art":"res://assets/characters/monsters/m_s033.png", "art_key":"m_s033", "lore":"翠玉圣域中的精锐守关强者，周身环绕着浓郁的celestial之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Jade Sanctuary, enveloped in dense celestial essence that blunts incoming blows."},
	{"id":"m_s034", "realm":1, "tier":2, "element":"wood", "tint":"83e4c1", "name":"翠玉圣域先驱尊者", "name_en":"Jade Sanctuary Herald", "art":"res://assets/characters/monsters/m_s034.png", "art_key":"m_s034", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s035", "realm":1, "tier":3, "element":"wood", "tint":"83e4c1", "name":"翠玉圣域霸主", "name_en":"Jade Sanctuary Apex Tyrant", "art":"res://assets/characters/monsters/m_s035.png", "art_key":"m_s035", "lore":"盘踞于翠玉圣域核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Jade Sanctuary, crushing all who dare contest its reign."},
	{"id":"m_s036", "realm":1, "tier":1, "element":"wood", "tint":"83e4c1", "name":"幻雾长原岩蛛", "name_en":"Mirage Expanse Spider", "art":"res://assets/characters/monsters/m_s036.png", "art_key":"m_s036", "lore":"游荡在幻雾长原边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Mirage Expanse, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s037", "realm":1, "tier":1, "element":"void", "tint":"4834d4", "name":"幻雾长原潜行者", "name_en":"Mirage Expanse Prowler", "art":"res://assets/characters/monsters/m_s037.png", "art_key":"m_s037", "lore":"驻扎在幻雾长原险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Mirage Expanse's choke points, famed for crushing charges."},
	{"id":"m_s038", "realm":1, "tier":2, "element":"void", "tint":"4834d4", "name":"幻雾长原督军", "name_en":"Mirage Expanse Overseer", "art":"res://assets/characters/monsters/m_s038.png", "art_key":"m_s038", "lore":"幻雾长原中的精锐守关强者，周身环绕着浓郁的void之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Mirage Expanse, enveloped in dense void essence that blunts incoming blows."},
	{"id":"m_s039", "realm":1, "tier":2, "element":"wood", "tint":"83e4c1", "name":"幻雾长原副统领", "name_en":"Mirage Expanse Vanguard General", "art":"res://assets/characters/monsters/m_s039.png", "art_key":"m_s039", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s040", "realm":1, "tier":3, "element":"wood", "tint":"83e4c1", "name":"幻雾长原巨神", "name_en":"Mirage Expanse Colossus King", "art":"res://assets/characters/monsters/m_s040.png", "art_key":"m_s040", "lore":"盘踞于幻雾长原核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Mirage Expanse, crushing all who dare contest its reign."},
	{"id":"m_s041", "realm":1, "tier":1, "element":"fire", "tint":"f0932b", "name":"怒焰火山水灵", "name_en":"Fury Caldera Sprite", "art":"res://assets/characters/monsters/m_s041.png", "art_key":"m_s041", "lore":"游荡在怒焰火山边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Fury Caldera, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s042", "realm":1, "tier":1, "element":"earth", "tint":"d4a373", "name":"怒焰火山夜枭", "name_en":"Fury Caldera Owl", "art":"res://assets/characters/monsters/m_s042.png", "art_key":"m_s042", "lore":"驻扎在怒焰火山险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Fury Caldera's choke points, famed for crushing charges."},
	{"id":"m_s043", "realm":1, "tier":2, "element":"earth", "tint":"d4a373", "name":"怒焰火山震地兽", "name_en":"Fury Caldera Earthshaker", "art":"res://assets/characters/monsters/m_s043.png", "art_key":"m_s043", "lore":"怒焰火山中的精锐守关强者，周身环绕着浓郁的earth之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Fury Caldera, enveloped in dense earth essence that blunts incoming blows."},
	{"id":"m_s044", "realm":1, "tier":2, "element":"fire", "tint":"f0932b", "name":"怒焰火山巡狩神侍", "name_en":"Fury Caldera Grand Inquisitor", "art":"res://assets/characters/monsters/m_s044.png", "art_key":"m_s044", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s045", "realm":1, "tier":3, "element":"fire", "tint":"f0932b", "name":"怒焰火山主宰者", "name_en":"Fury Caldera Dominator", "art":"res://assets/characters/monsters/m_s045.png", "art_key":"m_s045", "lore":"盘踞于怒焰火山核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Fury Caldera, crushing all who dare contest its reign."},
	{"id":"m_s046", "realm":1, "tier":1, "element":"fire", "tint":"f0932b", "name":"万象熔炉幼苗", "name_en":"Worldforge Sprout", "art":"res://assets/characters/monsters/m_s046.png", "art_key":"m_s046", "lore":"游荡在万象熔炉边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Worldforge, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s047", "realm":1, "tier":1, "element":"earth", "tint":"d4a373", "name":"万象熔炉破阵卒", "name_en":"Worldforge Charger", "art":"res://assets/characters/monsters/m_s047.png", "art_key":"m_s047", "lore":"驻扎在万象熔炉险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Worldforge's choke points, famed for crushing charges."},
	{"id":"m_s048", "realm":1, "tier":2, "element":"earth", "tint":"d4a373", "name":"万象熔炉冥铠将", "name_en":"Worldforge Deathknight", "art":"res://assets/characters/monsters/m_s048.png", "art_key":"m_s048", "lore":"万象熔炉中的精锐守关强者，周身环绕着浓郁的earth之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Worldforge, enveloped in dense earth essence that blunts incoming blows."},
	{"id":"m_s049", "realm":1, "tier":2, "element":"fire", "tint":"f0932b", "name":"万象熔炉守门古尊", "name_en":"Worldforge Gate Warden", "art":"res://assets/characters/monsters/m_s049.png", "art_key":"m_s049", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s050", "realm":1, "tier":4, "element":"fire", "tint":"f0932b", "name":"万象熔炉·大境天灾巨神", "name_en":"Worldforge Realm Calamity", "art":"res://assets/characters/monsters/m_s050.png", "art_key":"m_s050", "lore":"统御整座大境界的至高主宰，凝聚万千灵脉天威，举手投足皆引发天地异象。", "lore_en":"The supreme sovereign of the entire realm, channeling tectonic leylines to unleash cataclysms.", "mechanics":{"absorb_burn_every":3, "shield_per_absorbed_burn":3, "phase2_threshold":0.5, "phase2_damage_boost":8, "phase2_burn_on_hit":2}},
	{"id":"m_s051", "realm":2, "tier":1, "element":"water", "tint":"3498db", "name":"沉沦废墟小妖", "name_en":"Sunken Ruins Imp", "art":"res://assets/characters/monsters/m_s051.png", "art_key":"m_s051", "lore":"游荡在沉沦废墟边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Sunken Ruins, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s052", "realm":2, "tier":1, "element":"void", "tint":"4834d4", "name":"沉沦废墟狂蜂", "name_en":"Sunken Ruins Wasp", "art":"res://assets/characters/monsters/m_s052.png", "art_key":"m_s052", "lore":"驻扎在沉沦废墟险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Sunken Ruins's choke points, famed for crushing charges."},
	{"id":"m_s053", "realm":2, "tier":2, "element":"void", "tint":"4834d4", "name":"沉沦废墟守望使", "name_en":"Sunken Ruins Warden", "art":"res://assets/characters/monsters/m_s053.png", "art_key":"m_s053", "lore":"沉沦废墟中的精锐守关强者，周身环绕着浓郁的void之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Sunken Ruins, enveloped in dense void essence that blunts incoming blows."},
	{"id":"m_s054", "realm":2, "tier":2, "element":"water", "tint":"3498db", "name":"沉沦废墟暴君护法", "name_en":"Sunken Ruins Tyrant Enforcer", "art":"res://assets/characters/monsters/m_s054.png", "art_key":"m_s054", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s055", "realm":2, "tier":3, "element":"water", "tint":"3498db", "name":"沉沦废墟领主", "name_en":"Sunken Ruins Lord", "art":"res://assets/characters/monsters/m_s055.png", "art_key":"m_s055", "lore":"盘踞于沉沦废墟核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Sunken Ruins, crushing all who dare contest its reign."},
	{"id":"m_s056", "realm":2, "tier":1, "element":"water", "tint":"3498db", "name":"暗涌深渊斥候", "name_en":"Abyssal Current Scout", "art":"res://assets/characters/monsters/m_s056.png", "art_key":"m_s056", "lore":"游荡在暗涌深渊边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Abyssal Current, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s057", "realm":2, "tier":1, "element":"void", "tint":"4834d4", "name":"暗涌深渊铁甲卫", "name_en":"Abyssal Current Armored Guard", "art":"res://assets/characters/monsters/m_s057.png", "art_key":"m_s057", "lore":"驻扎在暗涌深渊险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Abyssal Current's choke points, famed for crushing charges."},
	{"id":"m_s058", "realm":2, "tier":2, "element":"void", "tint":"4834d4", "name":"暗涌深渊精英祭司", "name_en":"Abyssal Current High Priest", "art":"res://assets/characters/monsters/m_s058.png", "art_key":"m_s058", "lore":"暗涌深渊中的精锐守关强者，周身环绕着浓郁的void之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Abyssal Current, enveloped in dense void essence that blunts incoming blows."},
	{"id":"m_s059", "realm":2, "tier":2, "element":"water", "tint":"3498db", "name":"暗涌深渊狂乱使徒", "name_en":"Abyssal Current Chaos Apostle", "art":"res://assets/characters/monsters/m_s059.png", "art_key":"m_s059", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s060", "realm":2, "tier":3, "element":"water", "tint":"3498db", "name":"暗涌深渊霸主", "name_en":"Abyssal Current Apex Tyrant", "art":"res://assets/characters/monsters/m_s060.png", "art_key":"m_s060", "lore":"盘踞于暗涌深渊核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Abyssal Current, crushing all who dare contest its reign."},
	{"id":"m_s061", "realm":2, "tier":1, "element":"void", "tint":"4834d4", "name":"亡灵回廊幼兽", "name_en":"Wraith Corridor Hatchling", "art":"res://assets/characters/monsters/m_s061.png", "art_key":"m_s061", "lore":"游荡在亡灵回廊边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Wraith Corridor, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s062", "realm":2, "tier":1, "element":"poison", "tint":"9b59b6", "name":"亡灵回廊灵蛇", "name_en":"Wraith Corridor Serpent", "art":"res://assets/characters/monsters/m_s062.png", "art_key":"m_s062", "lore":"驻扎在亡灵回廊险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Wraith Corridor's choke points, famed for crushing charges."},
	{"id":"m_s063", "realm":2, "tier":2, "element":"poison", "tint":"9b59b6", "name":"亡灵回廊统领", "name_en":"Wraith Corridor Captain", "art":"res://assets/characters/monsters/m_s063.png", "art_key":"m_s063", "lore":"亡灵回廊中的精锐守关强者，周身环绕着浓郁的poison之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Wraith Corridor, enveloped in dense poison essence that blunts incoming blows."},
	{"id":"m_s064", "realm":2, "tier":2, "element":"void", "tint":"4834d4", "name":"亡灵回廊血契尊者", "name_en":"Wraith Corridor Bloodbound Master", "art":"res://assets/characters/monsters/m_s064.png", "art_key":"m_s064", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s065", "realm":2, "tier":3, "element":"void", "tint":"4834d4", "name":"亡灵回廊巨神", "name_en":"Wraith Corridor Colossus King", "art":"res://assets/characters/monsters/m_s065.png", "art_key":"m_s065", "lore":"盘踞于亡灵回廊核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Wraith Corridor, crushing all who dare contest its reign."},
	{"id":"m_s066", "realm":2, "tier":1, "element":"poison", "tint":"9b59b6", "name":"血月峡谷灵偶", "name_en":"Bloodmoon Canyon Effigy", "art":"res://assets/characters/monsters/m_s066.png", "art_key":"m_s066", "lore":"游荡在血月峡谷边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Bloodmoon Canyon, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s067", "realm":2, "tier":1, "element":"fire", "tint":"f0932b", "name":"血月峡谷恶犬", "name_en":"Bloodmoon Canyon Hound", "art":"res://assets/characters/monsters/m_s067.png", "art_key":"m_s067", "lore":"驻扎在血月峡谷险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Bloodmoon Canyon's choke points, famed for crushing charges."},
	{"id":"m_s068", "realm":2, "tier":2, "element":"fire", "tint":"f0932b", "name":"血月峡谷巨像", "name_en":"Bloodmoon Canyon Colossus", "art":"res://assets/characters/monsters/m_s068.png", "art_key":"m_s068", "lore":"血月峡谷中的精锐守关强者，周身环绕着浓郁的fire之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Bloodmoon Canyon, enveloped in dense fire essence that blunts incoming blows."},
	{"id":"m_s069", "realm":2, "tier":2, "element":"poison", "tint":"9b59b6", "name":"血月峡谷寂灭行刑官", "name_en":"Bloodmoon Canyon Executioner", "art":"res://assets/characters/monsters/m_s069.png", "art_key":"m_s069", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s070", "realm":2, "tier":3, "element":"poison", "tint":"9b59b6", "name":"血月峡谷主宰者", "name_en":"Bloodmoon Canyon Dominator", "art":"res://assets/characters/monsters/m_s070.png", "art_key":"m_s070", "lore":"盘踞于血月峡谷核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Bloodmoon Canyon, crushing all who dare contest its reign."},
	{"id":"m_s071", "realm":2, "tier":1, "element":"poison", "tint":"9b59b6", "name":"蚀骨沼泽微粒", "name_en":"Bonerot Marsh Wisp", "art":"res://assets/characters/monsters/m_s071.png", "art_key":"m_s071", "lore":"游荡在蚀骨沼泽边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Bonerot Marsh, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s072", "realm":2, "tier":1, "element":"water", "tint":"3498db", "name":"蚀骨沼泽巨蜥", "name_en":"Bonerot Marsh Lizard", "art":"res://assets/characters/monsters/m_s072.png", "art_key":"m_s072", "lore":"驻扎在蚀骨沼泽险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Bonerot Marsh's choke points, famed for crushing charges."},
	{"id":"m_s073", "realm":2, "tier":2, "element":"water", "tint":"3498db", "name":"蚀骨沼泽战魁", "name_en":"Bonerot Marsh Mauler", "art":"res://assets/characters/monsters/m_s073.png", "art_key":"m_s073", "lore":"蚀骨沼泽中的精锐守关强者，周身环绕着浓郁的water之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Bonerot Marsh, enveloped in dense water essence that blunts incoming blows."},
	{"id":"m_s074", "realm":2, "tier":2, "element":"poison", "tint":"9b59b6", "name":"蚀骨沼泽天罚武尊", "name_en":"Bonerot Marsh Punisher", "art":"res://assets/characters/monsters/m_s074.png", "art_key":"m_s074", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s075", "realm":2, "tier":3, "element":"poison", "tint":"9b59b6", "name":"蚀骨沼泽大祭司长", "name_en":"Bonerot Marsh Arch-Hierophant", "art":"res://assets/characters/monsters/m_s075.png", "art_key":"m_s075", "lore":"盘踞于蚀骨沼泽核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Bonerot Marsh, crushing all who dare contest its reign.", "mechanics":{"shield_per_turn":5, "starting_shield":20}},
	{"id":"m_s076", "realm":2, "tier":1, "element":"void", "tint":"4834d4", "name":"寂静墓园哨兵", "name_en":"Silent Necropolis Sentry", "art":"res://assets/characters/monsters/m_s076.png", "art_key":"m_s076", "lore":"游荡在寂静墓园边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Silent Necropolis, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s077", "realm":2, "tier":1, "element":"earth", "tint":"d4a373", "name":"寂静墓园石蝠", "name_en":"Silent Necropolis Bat", "art":"res://assets/characters/monsters/m_s077.png", "art_key":"m_s077", "lore":"驻扎在寂静墓园险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Silent Necropolis's choke points, famed for crushing charges."},
	{"id":"m_s078", "realm":2, "tier":2, "element":"earth", "tint":"d4a373", "name":"寂静墓园煞灵使", "name_en":"Silent Necropolis Wraith Lord", "art":"res://assets/characters/monsters/m_s078.png", "art_key":"m_s078", "lore":"寂静墓园中的精锐守关强者，周身环绕着浓郁的earth之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Silent Necropolis, enveloped in dense earth essence that blunts incoming blows."},
	{"id":"m_s079", "realm":2, "tier":2, "element":"void", "tint":"4834d4", "name":"寂静墓园灵核掌控者", "name_en":"Silent Necropolis Core Keeper", "art":"res://assets/characters/monsters/m_s079.png", "art_key":"m_s079", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s080", "realm":2, "tier":3, "element":"void", "tint":"4834d4", "name":"寂静墓园领主", "name_en":"Silent Necropolis Lord", "art":"res://assets/characters/monsters/m_s080.png", "art_key":"m_s080", "lore":"盘踞于寂静墓园核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Silent Necropolis, crushing all who dare contest its reign."},
	{"id":"m_s081", "realm":2, "tier":1, "element":"void", "tint":"4834d4", "name":"裂魂断崖步卒", "name_en":"Soulrend Cliffs Footman", "art":"res://assets/characters/monsters/m_s081.png", "art_key":"m_s081", "lore":"游荡在裂魂断崖边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Soulrend Cliffs, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s082", "realm":2, "tier":1, "element":"wind", "tint":"a8e6cf", "name":"裂魂断崖战卒", "name_en":"Soulrend Cliffs Fighter", "art":"res://assets/characters/monsters/m_s082.png", "art_key":"m_s082", "lore":"驻扎在裂魂断崖险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Soulrend Cliffs's choke points, famed for crushing charges."},
	{"id":"m_s083", "realm":2, "tier":2, "element":"wind", "tint":"a8e6cf", "name":"裂魂断崖破空者", "name_en":"Soulrend Cliffs Skycleaver", "art":"res://assets/characters/monsters/m_s083.png", "art_key":"m_s083", "lore":"裂魂断崖中的精锐守关强者，周身环绕着浓郁的wind之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Soulrend Cliffs, enveloped in dense wind essence that blunts incoming blows."},
	{"id":"m_s084", "realm":2, "tier":2, "element":"void", "tint":"4834d4", "name":"裂魂断崖先驱尊者", "name_en":"Soulrend Cliffs Herald", "art":"res://assets/characters/monsters/m_s084.png", "art_key":"m_s084", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s085", "realm":2, "tier":3, "element":"void", "tint":"4834d4", "name":"裂魂断崖霸主", "name_en":"Soulrend Cliffs Apex Tyrant", "art":"res://assets/characters/monsters/m_s085.png", "art_key":"m_s085", "lore":"盘踞于裂魂断崖核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Soulrend Cliffs, crushing all who dare contest its reign."},
	{"id":"m_s086", "realm":2, "tier":1, "element":"void", "tint":"4834d4", "name":"幽冥深渊岩蛛", "name_en":"Netherdeep Abyss Spider", "art":"res://assets/characters/monsters/m_s086.png", "art_key":"m_s086", "lore":"游荡在幽冥深渊边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Netherdeep Abyss, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s087", "realm":2, "tier":1, "element":"water", "tint":"3498db", "name":"幽冥深渊潜行者", "name_en":"Netherdeep Abyss Prowler", "art":"res://assets/characters/monsters/m_s087.png", "art_key":"m_s087", "lore":"驻扎在幽冥深渊险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Netherdeep Abyss's choke points, famed for crushing charges."},
	{"id":"m_s088", "realm":2, "tier":2, "element":"water", "tint":"3498db", "name":"幽冥深渊督军", "name_en":"Netherdeep Abyss Overseer", "art":"res://assets/characters/monsters/m_s088.png", "art_key":"m_s088", "lore":"幽冥深渊中的精锐守关强者，周身环绕着浓郁的water之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Netherdeep Abyss, enveloped in dense water essence that blunts incoming blows."},
	{"id":"m_s089", "realm":2, "tier":2, "element":"void", "tint":"4834d4", "name":"幽冥深渊副统领", "name_en":"Netherdeep Abyss Vanguard General", "art":"res://assets/characters/monsters/m_s089.png", "art_key":"m_s089", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s090", "realm":2, "tier":3, "element":"void", "tint":"4834d4", "name":"幽冥深渊巨神", "name_en":"Netherdeep Abyss Colossus King", "art":"res://assets/characters/monsters/m_s090.png", "art_key":"m_s090", "lore":"盘踞于幽冥深渊核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Netherdeep Abyss, crushing all who dare contest its reign."},
	{"id":"m_s091", "realm":2, "tier":1, "element":"void", "tint":"4834d4", "name":"噬影荒原水灵", "name_en":"Shadowmaw Wastes Sprite", "art":"res://assets/characters/monsters/m_s091.png", "art_key":"m_s091", "lore":"游荡在噬影荒原边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Shadowmaw Wastes, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s092", "realm":2, "tier":1, "element":"poison", "tint":"9b59b6", "name":"噬影荒原夜枭", "name_en":"Shadowmaw Wastes Owl", "art":"res://assets/characters/monsters/m_s092.png", "art_key":"m_s092", "lore":"驻扎在噬影荒原险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Shadowmaw Wastes's choke points, famed for crushing charges."},
	{"id":"m_s093", "realm":2, "tier":2, "element":"poison", "tint":"9b59b6", "name":"噬影荒原震地兽", "name_en":"Shadowmaw Wastes Earthshaker", "art":"res://assets/characters/monsters/m_s093.png", "art_key":"m_s093", "lore":"噬影荒原中的精锐守关强者，周身环绕着浓郁的poison之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Shadowmaw Wastes, enveloped in dense poison essence that blunts incoming blows."},
	{"id":"m_s094", "realm":2, "tier":2, "element":"void", "tint":"4834d4", "name":"噬影荒原巡狩神侍", "name_en":"Shadowmaw Wastes Grand Inquisitor", "art":"res://assets/characters/monsters/m_s094.png", "art_key":"m_s094", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s095", "realm":2, "tier":3, "element":"void", "tint":"4834d4", "name":"噬影荒原主宰者", "name_en":"Shadowmaw Wastes Dominator", "art":"res://assets/characters/monsters/m_s095.png", "art_key":"m_s095", "lore":"盘踞于噬影荒原核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Shadowmaw Wastes, crushing all who dare contest its reign."},
	{"id":"m_s096", "realm":2, "tier":1, "element":"void", "tint":"4834d4", "name":"深渊之王座幼苗", "name_en":"Abyssal Throne Sprout", "art":"res://assets/characters/monsters/m_s096.png", "art_key":"m_s096", "lore":"游荡在深渊之王座边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Abyssal Throne, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s097", "realm":2, "tier":1, "element":"void", "tint":"4834d4", "name":"深渊之王座破阵卒", "name_en":"Abyssal Throne Charger", "art":"res://assets/characters/monsters/m_s097.png", "art_key":"m_s097", "lore":"驻扎在深渊之王座险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Abyssal Throne's choke points, famed for crushing charges."},
	{"id":"m_s098", "realm":2, "tier":2, "element":"void", "tint":"4834d4", "name":"深渊之王座冥铠将", "name_en":"Abyssal Throne Deathknight", "art":"res://assets/characters/monsters/m_s098.png", "art_key":"m_s098", "lore":"深渊之王座中的精锐守关强者，周身环绕着浓郁的void之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Abyssal Throne, enveloped in dense void essence that blunts incoming blows."},
	{"id":"m_s099", "realm":2, "tier":2, "element":"void", "tint":"4834d4", "name":"深渊之王座守门古尊", "name_en":"Abyssal Throne Gate Warden", "art":"res://assets/characters/monsters/m_s099.png", "art_key":"m_s099", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s100", "realm":2, "tier":4, "element":"void", "tint":"4834d4", "name":"深渊之王座·大境天灾巨神", "name_en":"Abyssal Throne Realm Calamity", "art":"res://assets/characters/monsters/m_s100.png", "art_key":"m_s100", "lore":"统御整座大境界的至高主宰，凝聚万千灵脉天威，举手投足皆引发天地异象。", "lore_en":"The supreme sovereign of the entire realm, channeling tectonic leylines to unleash cataclysms.", "mechanics":{"soul_tide_curse":"void_curse", "soul_tide_count":1, "phase2_threshold":0.4, "phase2_soul_tide":2}},
	{"id":"m_s101", "realm":3, "tier":1, "element":"wind", "tint":"a8e6cf", "name":"云海孤峰小妖", "name_en":"Cloudsea Pinnacle Imp", "art":"res://assets/characters/monsters/m_s101.png", "art_key":"m_s101", "lore":"游荡在云海孤峰边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Cloudsea Pinnacle, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s102", "realm":3, "tier":1, "element":"water", "tint":"3498db", "name":"云海孤峰狂蜂", "name_en":"Cloudsea Pinnacle Wasp", "art":"res://assets/characters/monsters/m_s102.png", "art_key":"m_s102", "lore":"驻扎在云海孤峰险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Cloudsea Pinnacle's choke points, famed for crushing charges."},
	{"id":"m_s103", "realm":3, "tier":2, "element":"water", "tint":"3498db", "name":"云海孤峰守望使", "name_en":"Cloudsea Pinnacle Warden", "art":"res://assets/characters/monsters/m_s103.png", "art_key":"m_s103", "lore":"云海孤峰中的精锐守关强者，周身环绕着浓郁的water之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Cloudsea Pinnacle, enveloped in dense water essence that blunts incoming blows."},
	{"id":"m_s104", "realm":3, "tier":2, "element":"wind", "tint":"a8e6cf", "name":"云海孤峰暴君护法", "name_en":"Cloudsea Pinnacle Tyrant Enforcer", "art":"res://assets/characters/monsters/m_s104.png", "art_key":"m_s104", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s105", "realm":3, "tier":3, "element":"wind", "tint":"a8e6cf", "name":"云海孤峰领主", "name_en":"Cloudsea Pinnacle Lord", "art":"res://assets/characters/monsters/m_s105.png", "art_key":"m_s105", "lore":"盘踞于云海孤峰核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Cloudsea Pinnacle, crushing all who dare contest its reign."},
	{"id":"m_s106", "realm":3, "tier":1, "element":"thunder", "tint":"58b8ff", "name":"雷霆天堑斥候", "name_en":"Thunder Rift Scout", "art":"res://assets/characters/monsters/m_s106.png", "art_key":"m_s106", "lore":"游荡在雷霆天堑边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Thunder Rift, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s107", "realm":3, "tier":1, "element":"wind", "tint":"a8e6cf", "name":"雷霆天堑铁甲卫", "name_en":"Thunder Rift Armored Guard", "art":"res://assets/characters/monsters/m_s107.png", "art_key":"m_s107", "lore":"驻扎在雷霆天堑险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Thunder Rift's choke points, famed for crushing charges."},
	{"id":"m_s108", "realm":3, "tier":2, "element":"wind", "tint":"a8e6cf", "name":"雷霆天堑精英祭司", "name_en":"Thunder Rift High Priest", "art":"res://assets/characters/monsters/m_s108.png", "art_key":"m_s108", "lore":"雷霆天堑中的精锐守关强者，周身环绕着浓郁的wind之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Thunder Rift, enveloped in dense wind essence that blunts incoming blows."},
	{"id":"m_s109", "realm":3, "tier":2, "element":"thunder", "tint":"58b8ff", "name":"雷霆天堑狂乱使徒", "name_en":"Thunder Rift Chaos Apostle", "art":"res://assets/characters/monsters/m_s109.png", "art_key":"m_s109", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s110", "realm":3, "tier":3, "element":"thunder", "tint":"58b8ff", "name":"雷霆天堑霸主", "name_en":"Thunder Rift Apex Tyrant", "art":"res://assets/characters/monsters/m_s110.png", "art_key":"m_s110", "lore":"盘踞于雷霆天堑核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Thunder Rift, crushing all who dare contest its reign."},
	{"id":"m_s111", "realm":3, "tier":1, "element":"wind", "tint":"a8e6cf", "name":"风蚀断岭幼兽", "name_en":"Windworn Ridge Hatchling", "art":"res://assets/characters/monsters/m_s111.png", "art_key":"m_s111", "lore":"游荡在风蚀断岭边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Windworn Ridge, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s112", "realm":3, "tier":1, "element":"earth", "tint":"d4a373", "name":"风蚀断岭灵蛇", "name_en":"Windworn Ridge Serpent", "art":"res://assets/characters/monsters/m_s112.png", "art_key":"m_s112", "lore":"驻扎在风蚀断岭险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Windworn Ridge's choke points, famed for crushing charges."},
	{"id":"m_s113", "realm":3, "tier":2, "element":"earth", "tint":"d4a373", "name":"风蚀断岭统领", "name_en":"Windworn Ridge Captain", "art":"res://assets/characters/monsters/m_s113.png", "art_key":"m_s113", "lore":"风蚀断岭中的精锐守关强者，周身环绕着浓郁的earth之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Windworn Ridge, enveloped in dense earth essence that blunts incoming blows."},
	{"id":"m_s114", "realm":3, "tier":2, "element":"wind", "tint":"a8e6cf", "name":"风蚀断岭血契尊者", "name_en":"Windworn Ridge Bloodbound Master", "art":"res://assets/characters/monsters/m_s114.png", "art_key":"m_s114", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s115", "realm":3, "tier":3, "element":"wind", "tint":"a8e6cf", "name":"风蚀断岭巨神", "name_en":"Windworn Ridge Colossus King", "art":"res://assets/characters/monsters/m_s115.png", "art_key":"m_s115", "lore":"盘踞于风蚀断岭核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Windworn Ridge, crushing all who dare contest its reign."},
	{"id":"m_s116", "realm":3, "tier":1, "element":"celestial", "tint":"ffd700", "name":"星陨荒漠灵偶", "name_en":"Starfall Desert Effigy", "art":"res://assets/characters/monsters/m_s116.png", "art_key":"m_s116", "lore":"游荡在星陨荒漠边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Starfall Desert, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s117", "realm":3, "tier":1, "element":"earth", "tint":"d4a373", "name":"星陨荒漠恶犬", "name_en":"Starfall Desert Hound", "art":"res://assets/characters/monsters/m_s117.png", "art_key":"m_s117", "lore":"驻扎在星陨荒漠险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Starfall Desert's choke points, famed for crushing charges."},
	{"id":"m_s118", "realm":3, "tier":2, "element":"earth", "tint":"d4a373", "name":"星陨荒漠巨像", "name_en":"Starfall Desert Colossus", "art":"res://assets/characters/monsters/m_s118.png", "art_key":"m_s118", "lore":"星陨荒漠中的精锐守关强者，周身环绕着浓郁的earth之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Starfall Desert, enveloped in dense earth essence that blunts incoming blows."},
	{"id":"m_s119", "realm":3, "tier":2, "element":"celestial", "tint":"ffd700", "name":"星陨荒漠寂灭行刑官", "name_en":"Starfall Desert Executioner", "art":"res://assets/characters/monsters/m_s119.png", "art_key":"m_s119", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s120", "realm":3, "tier":3, "element":"celestial", "tint":"ffd700", "name":"星陨荒漠主宰者", "name_en":"Starfall Desert Dominator", "art":"res://assets/characters/monsters/m_s120.png", "art_key":"m_s120", "lore":"盘踞于星陨荒漠核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Starfall Desert, crushing all who dare contest its reign."},
	{"id":"m_s121", "realm":3, "tier":1, "element":"celestial", "tint":"ffd700", "name":"极光冰原微粒", "name_en":"Aurora Icefield Wisp", "art":"res://assets/characters/monsters/m_s121.png", "art_key":"m_s121", "lore":"游荡在极光冰原边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Aurora Icefield, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s122", "realm":3, "tier":1, "element":"water", "tint":"3498db", "name":"极光冰原巨蜥", "name_en":"Aurora Icefield Lizard", "art":"res://assets/characters/monsters/m_s122.png", "art_key":"m_s122", "lore":"驻扎在极光冰原险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Aurora Icefield's choke points, famed for crushing charges."},
	{"id":"m_s123", "realm":3, "tier":2, "element":"water", "tint":"3498db", "name":"极光冰原战魁", "name_en":"Aurora Icefield Mauler", "art":"res://assets/characters/monsters/m_s123.png", "art_key":"m_s123", "lore":"极光冰原中的精锐守关强者，周身环绕着浓郁的water之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Aurora Icefield, enveloped in dense water essence that blunts incoming blows."},
	{"id":"m_s124", "realm":3, "tier":2, "element":"celestial", "tint":"ffd700", "name":"极光冰原天罚武尊", "name_en":"Aurora Icefield Punisher", "art":"res://assets/characters/monsters/m_s124.png", "art_key":"m_s124", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s125", "realm":3, "tier":3, "element":"celestial", "tint":"ffd700", "name":"极光冰原大祭司长", "name_en":"Aurora Icefield Arch-Hierophant", "art":"res://assets/characters/monsters/m_s125.png", "art_key":"m_s125", "lore":"盘踞于极光冰原核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Aurora Icefield, crushing all who dare contest its reign.", "mechanics":{"counterspell_threshold":3, "counterspell_burn":1}},
	{"id":"m_s126", "realm":3, "tier":1, "element":"wind", "tint":"a8e6cf", "name":"苍穹回廊哨兵", "name_en":"Skybound Corridor Sentry", "art":"res://assets/characters/monsters/m_s126.png", "art_key":"m_s126", "lore":"游荡在苍穹回廊边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Skybound Corridor, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s127", "realm":3, "tier":1, "element":"celestial", "tint":"ffd700", "name":"苍穹回廊石蝠", "name_en":"Skybound Corridor Bat", "art":"res://assets/characters/monsters/m_s127.png", "art_key":"m_s127", "lore":"驻扎在苍穹回廊险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Skybound Corridor's choke points, famed for crushing charges."},
	{"id":"m_s128", "realm":3, "tier":2, "element":"celestial", "tint":"ffd700", "name":"苍穹回廊煞灵使", "name_en":"Skybound Corridor Wraith Lord", "art":"res://assets/characters/monsters/m_s128.png", "art_key":"m_s128", "lore":"苍穹回廊中的精锐守关强者，周身环绕着浓郁的celestial之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Skybound Corridor, enveloped in dense celestial essence that blunts incoming blows."},
	{"id":"m_s129", "realm":3, "tier":2, "element":"wind", "tint":"a8e6cf", "name":"苍穹回廊灵核掌控者", "name_en":"Skybound Corridor Core Keeper", "art":"res://assets/characters/monsters/m_s129.png", "art_key":"m_s129", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s130", "realm":3, "tier":3, "element":"wind", "tint":"a8e6cf", "name":"苍穹回廊领主", "name_en":"Skybound Corridor Lord", "art":"res://assets/characters/monsters/m_s130.png", "art_key":"m_s130", "lore":"盘踞于苍穹回廊核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Skybound Corridor, crushing all who dare contest its reign."},
	{"id":"m_s131", "realm":3, "tier":1, "element":"celestial", "tint":"ffd700", "name":"天穹裂隙步卒", "name_en":"Heaven's Fissure Footman", "art":"res://assets/characters/monsters/m_s131.png", "art_key":"m_s131", "lore":"游荡在天穹裂隙边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Heaven's Fissure, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s132", "realm":3, "tier":1, "element":"void", "tint":"4834d4", "name":"天穹裂隙战卒", "name_en":"Heaven's Fissure Fighter", "art":"res://assets/characters/monsters/m_s132.png", "art_key":"m_s132", "lore":"驻扎在天穹裂隙险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Heaven's Fissure's choke points, famed for crushing charges."},
	{"id":"m_s133", "realm":3, "tier":2, "element":"void", "tint":"4834d4", "name":"天穹裂隙破空者", "name_en":"Heaven's Fissure Skycleaver", "art":"res://assets/characters/monsters/m_s133.png", "art_key":"m_s133", "lore":"天穹裂隙中的精锐守关强者，周身环绕着浓郁的void之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Heaven's Fissure, enveloped in dense void essence that blunts incoming blows."},
	{"id":"m_s134", "realm":3, "tier":2, "element":"celestial", "tint":"ffd700", "name":"天穹裂隙先驱尊者", "name_en":"Heaven's Fissure Herald", "art":"res://assets/characters/monsters/m_s134.png", "art_key":"m_s134", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s135", "realm":3, "tier":3, "element":"celestial", "tint":"ffd700", "name":"天穹裂隙霸主", "name_en":"Heaven's Fissure Apex Tyrant", "art":"res://assets/characters/monsters/m_s135.png", "art_key":"m_s135", "lore":"盘踞于天穹裂隙核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Heaven's Fissure, crushing all who dare contest its reign."},
	{"id":"m_s136", "realm":3, "tier":1, "element":"celestial", "tint":"ffd700", "name":"流星圣域岩蛛", "name_en":"Meteor Sanctum Spider", "art":"res://assets/characters/monsters/m_s136.png", "art_key":"m_s136", "lore":"游荡在流星圣域边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Meteor Sanctum, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s137", "realm":3, "tier":1, "element":"fire", "tint":"f0932b", "name":"流星圣域潜行者", "name_en":"Meteor Sanctum Prowler", "art":"res://assets/characters/monsters/m_s137.png", "art_key":"m_s137", "lore":"驻扎在流星圣域险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Meteor Sanctum's choke points, famed for crushing charges."},
	{"id":"m_s138", "realm":3, "tier":2, "element":"fire", "tint":"f0932b", "name":"流星圣域督军", "name_en":"Meteor Sanctum Overseer", "art":"res://assets/characters/monsters/m_s138.png", "art_key":"m_s138", "lore":"流星圣域中的精锐守关强者，周身环绕着浓郁的fire之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Meteor Sanctum, enveloped in dense fire essence that blunts incoming blows."},
	{"id":"m_s139", "realm":3, "tier":2, "element":"celestial", "tint":"ffd700", "name":"流星圣域副统领", "name_en":"Meteor Sanctum Vanguard General", "art":"res://assets/characters/monsters/m_s139.png", "art_key":"m_s139", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s140", "realm":3, "tier":3, "element":"celestial", "tint":"ffd700", "name":"流星圣域巨神", "name_en":"Meteor Sanctum Colossus King", "art":"res://assets/characters/monsters/m_s140.png", "art_key":"m_s140", "lore":"盘踞于流星圣域核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Meteor Sanctum, crushing all who dare contest its reign."},
	{"id":"m_s141", "realm":3, "tier":1, "element":"wind", "tint":"a8e6cf", "name":"天狱回音水灵", "name_en":"Skyprison Echo Sprite", "art":"res://assets/characters/monsters/m_s141.png", "art_key":"m_s141", "lore":"游荡在天狱回音边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Skyprison Echo, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s142", "realm":3, "tier":1, "element":"thunder", "tint":"58b8ff", "name":"天狱回音夜枭", "name_en":"Skyprison Echo Owl", "art":"res://assets/characters/monsters/m_s142.png", "art_key":"m_s142", "lore":"驻扎在天狱回音险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Skyprison Echo's choke points, famed for crushing charges."},
	{"id":"m_s143", "realm":3, "tier":2, "element":"thunder", "tint":"58b8ff", "name":"天狱回音震地兽", "name_en":"Skyprison Echo Earthshaker", "art":"res://assets/characters/monsters/m_s143.png", "art_key":"m_s143", "lore":"天狱回音中的精锐守关强者，周身环绕着浓郁的thunder之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Skyprison Echo, enveloped in dense thunder essence that blunts incoming blows."},
	{"id":"m_s144", "realm":3, "tier":2, "element":"wind", "tint":"a8e6cf", "name":"天狱回音巡狩神侍", "name_en":"Skyprison Echo Grand Inquisitor", "art":"res://assets/characters/monsters/m_s144.png", "art_key":"m_s144", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s145", "realm":3, "tier":3, "element":"wind", "tint":"a8e6cf", "name":"天狱回音主宰者", "name_en":"Skyprison Echo Dominator", "art":"res://assets/characters/monsters/m_s145.png", "art_key":"m_s145", "lore":"盘踞于天狱回音核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Skyprison Echo, crushing all who dare contest its reign."},
	{"id":"m_s146", "realm":3, "tier":1, "element":"thunder", "tint":"58b8ff", "name":"苍穹主宰幼苗", "name_en":"Sovereign of the Sky Sprout", "art":"res://assets/characters/monsters/m_s146.png", "art_key":"m_s146", "lore":"游荡在苍穹主宰边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Sovereign of the Sky, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s147", "realm":3, "tier":1, "element":"wind", "tint":"a8e6cf", "name":"苍穹主宰破阵卒", "name_en":"Sovereign of the Sky Charger", "art":"res://assets/characters/monsters/m_s147.png", "art_key":"m_s147", "lore":"驻扎在苍穹主宰险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Sovereign of the Sky's choke points, famed for crushing charges."},
	{"id":"m_s148", "realm":3, "tier":2, "element":"wind", "tint":"a8e6cf", "name":"苍穹主宰冥铠将", "name_en":"Sovereign of the Sky Deathknight", "art":"res://assets/characters/monsters/m_s148.png", "art_key":"m_s148", "lore":"苍穹主宰中的精锐守关强者，周身环绕着浓郁的wind之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Sovereign of the Sky, enveloped in dense wind essence that blunts incoming blows."},
	{"id":"m_s149", "realm":3, "tier":2, "element":"thunder", "tint":"58b8ff", "name":"苍穹主宰守门古尊", "name_en":"Sovereign of the Sky Gate Warden", "art":"res://assets/characters/monsters/m_s149.png", "art_key":"m_s149", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s150", "realm":3, "tier":4, "element":"thunder", "tint":"58b8ff", "name":"苍穹主宰·大境天灾巨神", "name_en":"Sovereign of the Sky Realm Calamity", "art":"res://assets/characters/monsters/m_s150.png", "art_key":"m_s150", "lore":"统御整座大境界的至高主宰，凝聚万千灵脉天威，举手投足皆引发天地异象。", "lore_en":"The supreme sovereign of the entire realm, channeling tectonic leylines to unleash cataclysms.", "mechanics":{"revive_hp_pct":0.3, "revive_attack_pierce":15}},
	{"id":"m_s151", "realm":4, "tier":1, "element":"void", "tint":"4834d4", "name":"虚无之境小妖", "name_en":"Void Reaches Imp", "art":"res://assets/characters/monsters/m_s151.png", "art_key":"m_s151", "lore":"游荡在虚无之境边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Void Reaches, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s152", "realm":4, "tier":1, "element":"void", "tint":"4834d4", "name":"虚无之境狂蜂", "name_en":"Void Reaches Wasp", "art":"res://assets/characters/monsters/m_s152.png", "art_key":"m_s152", "lore":"驻扎在虚无之境险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Void Reaches's choke points, famed for crushing charges."},
	{"id":"m_s153", "realm":4, "tier":2, "element":"void", "tint":"4834d4", "name":"虚无之境守望使", "name_en":"Void Reaches Warden", "art":"res://assets/characters/monsters/m_s153.png", "art_key":"m_s153", "lore":"虚无之境中的精锐守关强者，周身环绕着浓郁的void之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Void Reaches, enveloped in dense void essence that blunts incoming blows."},
	{"id":"m_s154", "realm":4, "tier":2, "element":"void", "tint":"4834d4", "name":"虚无之境暴君护法", "name_en":"Void Reaches Tyrant Enforcer", "art":"res://assets/characters/monsters/m_s154.png", "art_key":"m_s154", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s155", "realm":4, "tier":3, "element":"void", "tint":"4834d4", "name":"虚无之境领主", "name_en":"Void Reaches Lord", "art":"res://assets/characters/monsters/m_s155.png", "art_key":"m_s155", "lore":"盘踞于虚无之境核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Void Reaches, crushing all who dare contest its reign."},
	{"id":"m_s156", "realm":4, "tier":1, "element":"void", "tint":"4834d4", "name":"归墟暗流斥候", "name_en":"Netherfall Current Scout", "art":"res://assets/characters/monsters/m_s156.png", "art_key":"m_s156", "lore":"游荡在归墟暗流边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Netherfall Current, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s157", "realm":4, "tier":1, "element":"water", "tint":"3498db", "name":"归墟暗流铁甲卫", "name_en":"Netherfall Current Armored Guard", "art":"res://assets/characters/monsters/m_s157.png", "art_key":"m_s157", "lore":"驻扎在归墟暗流险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Netherfall Current's choke points, famed for crushing charges."},
	{"id":"m_s158", "realm":4, "tier":2, "element":"water", "tint":"3498db", "name":"归墟暗流精英祭司", "name_en":"Netherfall Current High Priest", "art":"res://assets/characters/monsters/m_s158.png", "art_key":"m_s158", "lore":"归墟暗流中的精锐守关强者，周身环绕着浓郁的water之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Netherfall Current, enveloped in dense water essence that blunts incoming blows."},
	{"id":"m_s159", "realm":4, "tier":2, "element":"void", "tint":"4834d4", "name":"归墟暗流狂乱使徒", "name_en":"Netherfall Current Chaos Apostle", "art":"res://assets/characters/monsters/m_s159.png", "art_key":"m_s159", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s160", "realm":4, "tier":3, "element":"void", "tint":"4834d4", "name":"归墟暗流霸主", "name_en":"Netherfall Current Apex Tyrant", "art":"res://assets/characters/monsters/m_s160.png", "art_key":"m_s160", "lore":"盘踞于归墟暗流核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Netherfall Current, crushing all who dare contest its reign."},
	{"id":"m_s161", "realm":4, "tier":1, "element":"void", "tint":"4834d4", "name":"湮灭回廊幼兽", "name_en":"Oblivion Corridor Hatchling", "art":"res://assets/characters/monsters/m_s161.png", "art_key":"m_s161", "lore":"游荡在湮灭回廊边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Oblivion Corridor, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s162", "realm":4, "tier":1, "element":"void", "tint":"4834d4", "name":"湮灭回廊灵蛇", "name_en":"Oblivion Corridor Serpent", "art":"res://assets/characters/monsters/m_s162.png", "art_key":"m_s162", "lore":"驻扎在湮灭回廊险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Oblivion Corridor's choke points, famed for crushing charges."},
	{"id":"m_s163", "realm":4, "tier":2, "element":"void", "tint":"4834d4", "name":"湮灭回廊统领", "name_en":"Oblivion Corridor Captain", "art":"res://assets/characters/monsters/m_s163.png", "art_key":"m_s163", "lore":"湮灭回廊中的精锐守关强者，周身环绕着浓郁的void之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Oblivion Corridor, enveloped in dense void essence that blunts incoming blows."},
	{"id":"m_s164", "realm":4, "tier":2, "element":"void", "tint":"4834d4", "name":"湮灭回廊血契尊者", "name_en":"Oblivion Corridor Bloodbound Master", "art":"res://assets/characters/monsters/m_s164.png", "art_key":"m_s164", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s165", "realm":4, "tier":3, "element":"void", "tint":"4834d4", "name":"湮灭回廊巨神", "name_en":"Oblivion Corridor Colossus King", "art":"res://assets/characters/monsters/m_s165.png", "art_key":"m_s165", "lore":"盘踞于湮灭回廊核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Oblivion Corridor, crushing all who dare contest its reign."},
	{"id":"m_s166", "realm":4, "tier":1, "element":"void", "tint":"4834d4", "name":"无光深渊灵偶", "name_en":"Lightless Abyss Effigy", "art":"res://assets/characters/monsters/m_s166.png", "art_key":"m_s166", "lore":"游荡在无光深渊边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Lightless Abyss, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s167", "realm":4, "tier":1, "element":"void", "tint":"4834d4", "name":"无光深渊恶犬", "name_en":"Lightless Abyss Hound", "art":"res://assets/characters/monsters/m_s167.png", "art_key":"m_s167", "lore":"驻扎在无光深渊险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Lightless Abyss's choke points, famed for crushing charges."},
	{"id":"m_s168", "realm":4, "tier":2, "element":"void", "tint":"4834d4", "name":"无光深渊巨像", "name_en":"Lightless Abyss Colossus", "art":"res://assets/characters/monsters/m_s168.png", "art_key":"m_s168", "lore":"无光深渊中的精锐守关强者，周身环绕着浓郁的void之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Lightless Abyss, enveloped in dense void essence that blunts incoming blows."},
	{"id":"m_s169", "realm":4, "tier":2, "element":"void", "tint":"4834d4", "name":"无光深渊寂灭行刑官", "name_en":"Lightless Abyss Executioner", "art":"res://assets/characters/monsters/m_s169.png", "art_key":"m_s169", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s170", "realm":4, "tier":3, "element":"void", "tint":"4834d4", "name":"无光深渊主宰者", "name_en":"Lightless Abyss Dominator", "art":"res://assets/characters/monsters/m_s170.png", "art_key":"m_s170", "lore":"盘踞于无光深渊核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Lightless Abyss, crushing all who dare contest its reign."},
	{"id":"m_s171", "realm":4, "tier":1, "element":"void", "tint":"4834d4", "name":"亡界孤岛微粒", "name_en":"Deadworld Isle Wisp", "art":"res://assets/characters/monsters/m_s171.png", "art_key":"m_s171", "lore":"游荡在亡界孤岛边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Deadworld Isle, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s172", "realm":4, "tier":1, "element":"earth", "tint":"d4a373", "name":"亡界孤岛巨蜥", "name_en":"Deadworld Isle Lizard", "art":"res://assets/characters/monsters/m_s172.png", "art_key":"m_s172", "lore":"驻扎在亡界孤岛险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Deadworld Isle's choke points, famed for crushing charges."},
	{"id":"m_s173", "realm":4, "tier":2, "element":"earth", "tint":"d4a373", "name":"亡界孤岛战魁", "name_en":"Deadworld Isle Mauler", "art":"res://assets/characters/monsters/m_s173.png", "art_key":"m_s173", "lore":"亡界孤岛中的精锐守关强者，周身环绕着浓郁的earth之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Deadworld Isle, enveloped in dense earth essence that blunts incoming blows."},
	{"id":"m_s174", "realm":4, "tier":2, "element":"void", "tint":"4834d4", "name":"亡界孤岛天罚武尊", "name_en":"Deadworld Isle Punisher", "art":"res://assets/characters/monsters/m_s174.png", "art_key":"m_s174", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s175", "realm":4, "tier":3, "element":"void", "tint":"4834d4", "name":"亡界孤岛大祭司长", "name_en":"Deadworld Isle Arch-Hierophant", "art":"res://assets/characters/monsters/m_s175.png", "art_key":"m_s175", "lore":"盘踞于亡界孤岛核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Deadworld Isle, crushing all who dare contest its reign.", "mechanics":{"heal_on_attack":5}},
	{"id":"m_s176", "realm":4, "tier":1, "element":"void", "tint":"4834d4", "name":"虚空裂痕哨兵", "name_en":"Voidrift Sentry", "art":"res://assets/characters/monsters/m_s176.png", "art_key":"m_s176", "lore":"游荡在虚空裂痕边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Voidrift, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s177", "realm":4, "tier":1, "element":"celestial", "tint":"ffd700", "name":"虚空裂痕石蝠", "name_en":"Voidrift Bat", "art":"res://assets/characters/monsters/m_s177.png", "art_key":"m_s177", "lore":"驻扎在虚空裂痕险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Voidrift's choke points, famed for crushing charges."},
	{"id":"m_s178", "realm":4, "tier":2, "element":"celestial", "tint":"ffd700", "name":"虚空裂痕煞灵使", "name_en":"Voidrift Wraith Lord", "art":"res://assets/characters/monsters/m_s178.png", "art_key":"m_s178", "lore":"虚空裂痕中的精锐守关强者，周身环绕着浓郁的celestial之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Voidrift, enveloped in dense celestial essence that blunts incoming blows."},
	{"id":"m_s179", "realm":4, "tier":2, "element":"void", "tint":"4834d4", "name":"虚空裂痕灵核掌控者", "name_en":"Voidrift Core Keeper", "art":"res://assets/characters/monsters/m_s179.png", "art_key":"m_s179", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s180", "realm":4, "tier":3, "element":"void", "tint":"4834d4", "name":"虚空裂痕领主", "name_en":"Voidrift Lord", "art":"res://assets/characters/monsters/m_s180.png", "art_key":"m_s180", "lore":"盘踞于虚空裂痕核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Voidrift, crushing all who dare contest its reign."},
	{"id":"m_s181", "realm":4, "tier":1, "element":"void", "tint":"4834d4", "name":"归墟秘境步卒", "name_en":"Netherfall Sanctum Footman", "art":"res://assets/characters/monsters/m_s181.png", "art_key":"m_s181", "lore":"游荡在归墟秘境边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Netherfall Sanctum, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s182", "realm":4, "tier":1, "element":"void", "tint":"4834d4", "name":"归墟秘境战卒", "name_en":"Netherfall Sanctum Fighter", "art":"res://assets/characters/monsters/m_s182.png", "art_key":"m_s182", "lore":"驻扎在归墟秘境险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Netherfall Sanctum's choke points, famed for crushing charges."},
	{"id":"m_s183", "realm":4, "tier":2, "element":"void", "tint":"4834d4", "name":"归墟秘境破空者", "name_en":"Netherfall Sanctum Skycleaver", "art":"res://assets/characters/monsters/m_s183.png", "art_key":"m_s183", "lore":"归墟秘境中的精锐守关强者，周身环绕着浓郁的void之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Netherfall Sanctum, enveloped in dense void essence that blunts incoming blows."},
	{"id":"m_s184", "realm":4, "tier":2, "element":"void", "tint":"4834d4", "name":"归墟秘境先驱尊者", "name_en":"Netherfall Sanctum Herald", "art":"res://assets/characters/monsters/m_s184.png", "art_key":"m_s184", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s185", "realm":4, "tier":3, "element":"void", "tint":"4834d4", "name":"归墟秘境霸主", "name_en":"Netherfall Sanctum Apex Tyrant", "art":"res://assets/characters/monsters/m_s185.png", "art_key":"m_s185", "lore":"盘踞于归墟秘境核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Netherfall Sanctum, crushing all who dare contest its reign."},
	{"id":"m_s186", "realm":4, "tier":1, "element":"void", "tint":"4834d4", "name":"万魂窟岩蛛", "name_en":"Chamber of Ten Thousand Souls Spider", "art":"res://assets/characters/monsters/m_s186.png", "art_key":"m_s186", "lore":"游荡在万魂窟边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Chamber of Ten Thousand Souls, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s187", "realm":4, "tier":1, "element":"poison", "tint":"9b59b6", "name":"万魂窟潜行者", "name_en":"Chamber of Ten Thousand Souls Prowler", "art":"res://assets/characters/monsters/m_s187.png", "art_key":"m_s187", "lore":"驻扎在万魂窟险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Chamber of Ten Thousand Souls's choke points, famed for crushing charges."},
	{"id":"m_s188", "realm":4, "tier":2, "element":"poison", "tint":"9b59b6", "name":"万魂窟督军", "name_en":"Chamber of Ten Thousand Souls Overseer", "art":"res://assets/characters/monsters/m_s188.png", "art_key":"m_s188", "lore":"万魂窟中的精锐守关强者，周身环绕着浓郁的poison之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Chamber of Ten Thousand Souls, enveloped in dense poison essence that blunts incoming blows."},
	{"id":"m_s189", "realm":4, "tier":2, "element":"void", "tint":"4834d4", "name":"万魂窟副统领", "name_en":"Chamber of Ten Thousand Souls Vanguard General", "art":"res://assets/characters/monsters/m_s189.png", "art_key":"m_s189", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s190", "realm":4, "tier":3, "element":"void", "tint":"4834d4", "name":"万魂窟巨神", "name_en":"Chamber of Ten Thousand Souls Colossus King", "art":"res://assets/characters/monsters/m_s190.png", "art_key":"m_s190", "lore":"盘踞于万魂窟核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Chamber of Ten Thousand Souls, crushing all who dare contest its reign."},
	{"id":"m_s191", "realm":4, "tier":1, "element":"void", "tint":"4834d4", "name":"湮灭回音水灵", "name_en":"Oblivion Echo Sprite", "art":"res://assets/characters/monsters/m_s191.png", "art_key":"m_s191", "lore":"游荡在湮灭回音边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Oblivion Echo, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s192", "realm":4, "tier":1, "element":"wind", "tint":"a8e6cf", "name":"湮灭回音夜枭", "name_en":"Oblivion Echo Owl", "art":"res://assets/characters/monsters/m_s192.png", "art_key":"m_s192", "lore":"驻扎在湮灭回音险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Oblivion Echo's choke points, famed for crushing charges."},
	{"id":"m_s193", "realm":4, "tier":2, "element":"wind", "tint":"a8e6cf", "name":"湮灭回音震地兽", "name_en":"Oblivion Echo Earthshaker", "art":"res://assets/characters/monsters/m_s193.png", "art_key":"m_s193", "lore":"湮灭回音中的精锐守关强者，周身环绕着浓郁的wind之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Oblivion Echo, enveloped in dense wind essence that blunts incoming blows."},
	{"id":"m_s194", "realm":4, "tier":2, "element":"void", "tint":"4834d4", "name":"湮灭回音巡狩神侍", "name_en":"Oblivion Echo Grand Inquisitor", "art":"res://assets/characters/monsters/m_s194.png", "art_key":"m_s194", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s195", "realm":4, "tier":3, "element":"void", "tint":"4834d4", "name":"湮灭回音主宰者", "name_en":"Oblivion Echo Dominator", "art":"res://assets/characters/monsters/m_s195.png", "art_key":"m_s195", "lore":"盘踞于湮灭回音核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Oblivion Echo, crushing all who dare contest its reign."},
	{"id":"m_s196", "realm":4, "tier":1, "element":"void", "tint":"4834d4", "name":"归墟主宰幼苗", "name_en":"Sovereign of the Void Sprout", "art":"res://assets/characters/monsters/m_s196.png", "art_key":"m_s196", "lore":"游荡在归墟主宰边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Sovereign of the Void, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s197", "realm":4, "tier":1, "element":"void", "tint":"4834d4", "name":"归墟主宰破阵卒", "name_en":"Sovereign of the Void Charger", "art":"res://assets/characters/monsters/m_s197.png", "art_key":"m_s197", "lore":"驻扎在归墟主宰险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Sovereign of the Void's choke points, famed for crushing charges."},
	{"id":"m_s198", "realm":4, "tier":2, "element":"void", "tint":"4834d4", "name":"归墟主宰冥铠将", "name_en":"Sovereign of the Void Deathknight", "art":"res://assets/characters/monsters/m_s198.png", "art_key":"m_s198", "lore":"归墟主宰中的精锐守关强者，周身环绕着浓郁的void之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Sovereign of the Void, enveloped in dense void essence that blunts incoming blows."},
	{"id":"m_s199", "realm":4, "tier":2, "element":"void", "tint":"4834d4", "name":"归墟主宰守门古尊", "name_en":"Sovereign of the Void Gate Warden", "art":"res://assets/characters/monsters/m_s199.png", "art_key":"m_s199", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s200", "realm":4, "tier":4, "element":"void", "tint":"4834d4", "name":"归墟主宰·大境天灾巨神", "name_en":"Sovereign of the Void Realm Calamity", "art":"res://assets/characters/monsters/m_s200.png", "art_key":"m_s200", "lore":"统御整座大境界的至高主宰，凝聚万千灵脉天威，举手投足皆引发天地异象。", "lore_en":"The supreme sovereign of the entire realm, channeling tectonic leylines to unleash cataclysms.", "mechanics":{"exhaust_hand_every":3, "phase2_threshold":0.35, "phase2_exhaust_every":2}},
	{"id":"m_s201", "realm":5, "tier":1, "element":"genesis", "tint":"f368e0", "name":"创世裂隙小妖", "name_en":"Genesis Rift Imp", "art":"res://assets/characters/monsters/m_s201.png", "art_key":"m_s201", "lore":"游荡在创世裂隙边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Genesis Rift, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s202", "realm":5, "tier":1, "element":"celestial", "tint":"ffd700", "name":"创世裂隙狂蜂", "name_en":"Genesis Rift Wasp", "art":"res://assets/characters/monsters/m_s202.png", "art_key":"m_s202", "lore":"驻扎在创世裂隙险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Genesis Rift's choke points, famed for crushing charges."},
	{"id":"m_s203", "realm":5, "tier":2, "element":"celestial", "tint":"ffd700", "name":"创世裂隙守望使", "name_en":"Genesis Rift Warden", "art":"res://assets/characters/monsters/m_s203.png", "art_key":"m_s203", "lore":"创世裂隙中的精锐守关强者，周身环绕着浓郁的celestial之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Genesis Rift, enveloped in dense celestial essence that blunts incoming blows."},
	{"id":"m_s204", "realm":5, "tier":2, "element":"genesis", "tint":"f368e0", "name":"创世裂隙暴君护法", "name_en":"Genesis Rift Tyrant Enforcer", "art":"res://assets/characters/monsters/m_s204.png", "art_key":"m_s204", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s205", "realm":5, "tier":3, "element":"genesis", "tint":"f368e0", "name":"创世裂隙领主", "name_en":"Genesis Rift Lord", "art":"res://assets/characters/monsters/m_s205.png", "art_key":"m_s205", "lore":"盘踞于创世裂隙核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Genesis Rift, crushing all who dare contest its reign."},
	{"id":"m_s206", "realm":5, "tier":1, "element":"genesis", "tint":"f368e0", "name":"混沌回廊斥候", "name_en":"Chaos Corridor Scout", "art":"res://assets/characters/monsters/m_s206.png", "art_key":"m_s206", "lore":"游荡在混沌回廊边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Chaos Corridor, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s207", "realm":5, "tier":1, "element":"void", "tint":"4834d4", "name":"混沌回廊铁甲卫", "name_en":"Chaos Corridor Armored Guard", "art":"res://assets/characters/monsters/m_s207.png", "art_key":"m_s207", "lore":"驻扎在混沌回廊险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Chaos Corridor's choke points, famed for crushing charges."},
	{"id":"m_s208", "realm":5, "tier":2, "element":"void", "tint":"4834d4", "name":"混沌回廊精英祭司", "name_en":"Chaos Corridor High Priest", "art":"res://assets/characters/monsters/m_s208.png", "art_key":"m_s208", "lore":"混沌回廊中的精锐守关强者，周身环绕着浓郁的void之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Chaos Corridor, enveloped in dense void essence that blunts incoming blows."},
	{"id":"m_s209", "realm":5, "tier":2, "element":"genesis", "tint":"f368e0", "name":"混沌回廊狂乱使徒", "name_en":"Chaos Corridor Chaos Apostle", "art":"res://assets/characters/monsters/m_s209.png", "art_key":"m_s209", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s210", "realm":5, "tier":3, "element":"genesis", "tint":"f368e0", "name":"混沌回廊霸主", "name_en":"Chaos Corridor Apex Tyrant", "art":"res://assets/characters/monsters/m_s210.png", "art_key":"m_s210", "lore":"盘踞于混沌回廊核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Chaos Corridor, crushing all who dare contest its reign."},
	{"id":"m_s211", "realm":5, "tier":1, "element":"genesis", "tint":"f368e0", "name":"星辰熔炉幼兽", "name_en":"Stellar Forge Hatchling", "art":"res://assets/characters/monsters/m_s211.png", "art_key":"m_s211", "lore":"游荡在星辰熔炉边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Stellar Forge, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s212", "realm":5, "tier":1, "element":"fire", "tint":"f0932b", "name":"星辰熔炉灵蛇", "name_en":"Stellar Forge Serpent", "art":"res://assets/characters/monsters/m_s212.png", "art_key":"m_s212", "lore":"驻扎在星辰熔炉险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Stellar Forge's choke points, famed for crushing charges."},
	{"id":"m_s213", "realm":5, "tier":2, "element":"fire", "tint":"f0932b", "name":"星辰熔炉统领", "name_en":"Stellar Forge Captain", "art":"res://assets/characters/monsters/m_s213.png", "art_key":"m_s213", "lore":"星辰熔炉中的精锐守关强者，周身环绕着浓郁的fire之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Stellar Forge, enveloped in dense fire essence that blunts incoming blows."},
	{"id":"m_s214", "realm":5, "tier":2, "element":"genesis", "tint":"f368e0", "name":"星辰熔炉血契尊者", "name_en":"Stellar Forge Bloodbound Master", "art":"res://assets/characters/monsters/m_s214.png", "art_key":"m_s214", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s215", "realm":5, "tier":3, "element":"genesis", "tint":"f368e0", "name":"星辰熔炉巨神", "name_en":"Stellar Forge Colossus King", "art":"res://assets/characters/monsters/m_s215.png", "art_key":"m_s215", "lore":"盘踞于星辰熔炉核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Stellar Forge, crushing all who dare contest its reign."},
	{"id":"m_s216", "realm":5, "tier":1, "element":"genesis", "tint":"f368e0", "name":"永恒回音灵偶", "name_en":"Eternal Echo Effigy", "art":"res://assets/characters/monsters/m_s216.png", "art_key":"m_s216", "lore":"游荡在永恒回音边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Eternal Echo, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s217", "realm":5, "tier":1, "element":"wind", "tint":"a8e6cf", "name":"永恒回音恶犬", "name_en":"Eternal Echo Hound", "art":"res://assets/characters/monsters/m_s217.png", "art_key":"m_s217", "lore":"驻扎在永恒回音险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Eternal Echo's choke points, famed for crushing charges."},
	{"id":"m_s218", "realm":5, "tier":2, "element":"wind", "tint":"a8e6cf", "name":"永恒回音巨像", "name_en":"Eternal Echo Colossus", "art":"res://assets/characters/monsters/m_s218.png", "art_key":"m_s218", "lore":"永恒回音中的精锐守关强者，周身环绕着浓郁的wind之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Eternal Echo, enveloped in dense wind essence that blunts incoming blows."},
	{"id":"m_s219", "realm":5, "tier":2, "element":"genesis", "tint":"f368e0", "name":"永恒回音寂灭行刑官", "name_en":"Eternal Echo Executioner", "art":"res://assets/characters/monsters/m_s219.png", "art_key":"m_s219", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s220", "realm":5, "tier":3, "element":"genesis", "tint":"f368e0", "name":"永恒回音主宰者", "name_en":"Eternal Echo Dominator", "art":"res://assets/characters/monsters/m_s220.png", "art_key":"m_s220", "lore":"盘踞于永恒回音核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Eternal Echo, crushing all who dare contest its reign."},
	{"id":"m_s221", "realm":5, "tier":1, "element":"genesis", "tint":"f368e0", "name":"万象之眼微粒", "name_en":"Eye of Worlds Wisp", "art":"res://assets/characters/monsters/m_s221.png", "art_key":"m_s221", "lore":"游荡在万象之眼边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Eye of Worlds, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s222", "realm":5, "tier":1, "element":"celestial", "tint":"ffd700", "name":"万象之眼巨蜥", "name_en":"Eye of Worlds Lizard", "art":"res://assets/characters/monsters/m_s222.png", "art_key":"m_s222", "lore":"驻扎在万象之眼险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Eye of Worlds's choke points, famed for crushing charges."},
	{"id":"m_s223", "realm":5, "tier":2, "element":"celestial", "tint":"ffd700", "name":"万象之眼战魁", "name_en":"Eye of Worlds Mauler", "art":"res://assets/characters/monsters/m_s223.png", "art_key":"m_s223", "lore":"万象之眼中的精锐守关强者，周身环绕着浓郁的celestial之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Eye of Worlds, enveloped in dense celestial essence that blunts incoming blows."},
	{"id":"m_s224", "realm":5, "tier":2, "element":"genesis", "tint":"f368e0", "name":"万象之眼天罚武尊", "name_en":"Eye of Worlds Punisher", "art":"res://assets/characters/monsters/m_s224.png", "art_key":"m_s224", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s225", "realm":5, "tier":3, "element":"genesis", "tint":"f368e0", "name":"万象之眼大祭司长", "name_en":"Eye of Worlds Arch-Hierophant", "art":"res://assets/characters/monsters/m_s225.png", "art_key":"m_s225", "lore":"盘踞于万象之眼核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Eye of Worlds, crushing all who dare contest its reign.", "mechanics":{"enrage_on_block_threshold":10, "enrage_attack_boost":3}},
	{"id":"m_s226", "realm":5, "tier":1, "element":"genesis", "tint":"f368e0", "name":"创世深渊哨兵", "name_en":"Genesis Abyss Sentry", "art":"res://assets/characters/monsters/m_s226.png", "art_key":"m_s226", "lore":"游荡在创世深渊边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Genesis Abyss, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s227", "realm":5, "tier":1, "element":"water", "tint":"3498db", "name":"创世深渊石蝠", "name_en":"Genesis Abyss Bat", "art":"res://assets/characters/monsters/m_s227.png", "art_key":"m_s227", "lore":"驻扎在创世深渊险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Genesis Abyss's choke points, famed for crushing charges."},
	{"id":"m_s228", "realm":5, "tier":2, "element":"water", "tint":"3498db", "name":"创世深渊煞灵使", "name_en":"Genesis Abyss Wraith Lord", "art":"res://assets/characters/monsters/m_s228.png", "art_key":"m_s228", "lore":"创世深渊中的精锐守关强者，周身环绕着浓郁的water之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Genesis Abyss, enveloped in dense water essence that blunts incoming blows."},
	{"id":"m_s229", "realm":5, "tier":2, "element":"genesis", "tint":"f368e0", "name":"创世深渊灵核掌控者", "name_en":"Genesis Abyss Core Keeper", "art":"res://assets/characters/monsters/m_s229.png", "art_key":"m_s229", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s230", "realm":5, "tier":3, "element":"genesis", "tint":"f368e0", "name":"创世深渊领主", "name_en":"Genesis Abyss Lord", "art":"res://assets/characters/monsters/m_s230.png", "art_key":"m_s230", "lore":"盘踞于创世深渊核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Genesis Abyss, crushing all who dare contest its reign."},
	{"id":"m_s231", "realm":5, "tier":1, "element":"genesis", "tint":"f368e0", "name":"时空裂境步卒", "name_en":"Rift of Time Footman", "art":"res://assets/characters/monsters/m_s231.png", "art_key":"m_s231", "lore":"游荡在时空裂境边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Rift of Time, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s232", "realm":5, "tier":1, "element":"thunder", "tint":"58b8ff", "name":"时空裂境战卒", "name_en":"Rift of Time Fighter", "art":"res://assets/characters/monsters/m_s232.png", "art_key":"m_s232", "lore":"驻扎在时空裂境险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Rift of Time's choke points, famed for crushing charges."},
	{"id":"m_s233", "realm":5, "tier":2, "element":"thunder", "tint":"58b8ff", "name":"时空裂境破空者", "name_en":"Rift of Time Skycleaver", "art":"res://assets/characters/monsters/m_s233.png", "art_key":"m_s233", "lore":"时空裂境中的精锐守关强者，周身环绕着浓郁的thunder之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Rift of Time, enveloped in dense thunder essence that blunts incoming blows."},
	{"id":"m_s234", "realm":5, "tier":2, "element":"genesis", "tint":"f368e0", "name":"时空裂境先驱尊者", "name_en":"Rift of Time Herald", "art":"res://assets/characters/monsters/m_s234.png", "art_key":"m_s234", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s235", "realm":5, "tier":3, "element":"genesis", "tint":"f368e0", "name":"时空裂境霸主", "name_en":"Rift of Time Apex Tyrant", "art":"res://assets/characters/monsters/m_s235.png", "art_key":"m_s235", "lore":"盘踞于时空裂境核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Rift of Time, crushing all who dare contest its reign."},
	{"id":"m_s236", "realm":5, "tier":1, "element":"genesis", "tint":"f368e0", "name":"万灵归一岩蛛", "name_en":"Convergence of Spirits Spider", "art":"res://assets/characters/monsters/m_s236.png", "art_key":"m_s236", "lore":"游荡在万灵归一边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Convergence of Spirits, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s237", "realm":5, "tier":1, "element":"wood", "tint":"83e4c1", "name":"万灵归一潜行者", "name_en":"Convergence of Spirits Prowler", "art":"res://assets/characters/monsters/m_s237.png", "art_key":"m_s237", "lore":"驻扎在万灵归一险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Convergence of Spirits's choke points, famed for crushing charges."},
	{"id":"m_s238", "realm":5, "tier":2, "element":"wood", "tint":"83e4c1", "name":"万灵归一督军", "name_en":"Convergence of Spirits Overseer", "art":"res://assets/characters/monsters/m_s238.png", "art_key":"m_s238", "lore":"万灵归一中的精锐守关强者，周身环绕着浓郁的wood之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Convergence of Spirits, enveloped in dense wood essence that blunts incoming blows."},
	{"id":"m_s239", "realm":5, "tier":2, "element":"genesis", "tint":"f368e0", "name":"万灵归一副统领", "name_en":"Convergence of Spirits Vanguard General", "art":"res://assets/characters/monsters/m_s239.png", "art_key":"m_s239", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s240", "realm":5, "tier":3, "element":"genesis", "tint":"f368e0", "name":"万灵归一巨神", "name_en":"Convergence of Spirits Colossus King", "art":"res://assets/characters/monsters/m_s240.png", "art_key":"m_s240", "lore":"盘踞于万灵归一核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Convergence of Spirits, crushing all who dare contest its reign."},
	{"id":"m_s241", "realm":5, "tier":1, "element":"genesis", "tint":"f368e0", "name":"创世回音水灵", "name_en":"Genesis Echo Sprite", "art":"res://assets/characters/monsters/m_s241.png", "art_key":"m_s241", "lore":"游荡在创世回音边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of Genesis Echo, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s242", "realm":5, "tier":1, "element":"celestial", "tint":"ffd700", "name":"创世回音夜枭", "name_en":"Genesis Echo Owl", "art":"res://assets/characters/monsters/m_s242.png", "art_key":"m_s242", "lore":"驻扎在创世回音险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at Genesis Echo's choke points, famed for crushing charges."},
	{"id":"m_s243", "realm":5, "tier":2, "element":"celestial", "tint":"ffd700", "name":"创世回音震地兽", "name_en":"Genesis Echo Earthshaker", "art":"res://assets/characters/monsters/m_s243.png", "art_key":"m_s243", "lore":"创世回音中的精锐守关强者，周身环绕着浓郁的celestial之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of Genesis Echo, enveloped in dense celestial essence that blunts incoming blows."},
	{"id":"m_s244", "realm":5, "tier":2, "element":"genesis", "tint":"f368e0", "name":"创世回音巡狩神侍", "name_en":"Genesis Echo Grand Inquisitor", "art":"res://assets/characters/monsters/m_s244.png", "art_key":"m_s244", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s245", "realm":5, "tier":3, "element":"genesis", "tint":"f368e0", "name":"创世回音主宰者", "name_en":"Genesis Echo Dominator", "art":"res://assets/characters/monsters/m_s245.png", "art_key":"m_s245", "lore":"盘踞于创世回音核心的绝对霸主，誓言碾碎一切胆敢叩关的生灵。", "lore_en":"The undisputed ruler residing in the heart of Genesis Echo, crushing all who dare contest its reign."},
	{"id":"m_s246", "realm":5, "tier":1, "element":"genesis", "tint":"f368e0", "name":"万象终焉幼苗", "name_en":"The End of All Sprout", "art":"res://assets/characters/monsters/m_s246.png", "art_key":"m_s246", "lore":"游荡在万象终焉边缘的巡哨生灵，身形敏捷，负责向大关深处传递入侵者的异动。", "lore_en":"A scout prowling the perimeter of The End of All, swiftly reporting trespassers to deeper forces."},
	{"id":"m_s247", "realm":5, "tier":1, "element":"genesis", "tint":"f368e0", "name":"万象终焉破阵卒", "name_en":"The End of All Charger", "art":"res://assets/characters/monsters/m_s247.png", "art_key":"m_s247", "lore":"驻扎在万象终焉险隘的强悍前锋，体魄雄壮，以凶狠的撕咬与冲撞著称。", "lore_en":"A rugged vanguard entrenched at The End of All's choke points, famed for crushing charges."},
	{"id":"m_s248", "realm":5, "tier":2, "element":"genesis", "tint":"f368e0", "name":"万象终焉冥铠将", "name_en":"The End of All Deathknight", "art":"res://assets/characters/monsters/m_s248.png", "art_key":"m_s248", "lore":"万象终焉中的精锐守关强者，周身环绕着浓郁的genesis之灵气，寻常攻势难以破其防御。", "lore_en":"An elite guardian of The End of All, enveloped in dense genesis essence that blunts incoming blows."},
	{"id":"m_s249", "realm":5, "tier":2, "element":"genesis", "tint":"f368e0", "name":"万象终焉守门古尊", "name_en":"The End of All Gate Warden", "art":"res://assets/characters/monsters/m_s249.png", "art_key":"m_s249", "lore":"侍奉在首领身侧的副统领，身经百战，每一次挥击都裹挟着狂暴的破阵气魄。", "lore_en":"A battle-hardened champion attending the domain lord, striking with devastating authority."},
	{"id":"m_s250", "realm":5, "tier":4, "element":"genesis", "tint":"f368e0", "name":"万象始源·天道终焉真灵", "name_en":"The Primordial Origin: Final Cosmic Will", "art":"res://assets/characters/monsters/m_s250.png", "art_key":"m_s250", "lore":"统御整座大境界的至高主宰，凝聚万千灵脉天威，举手投足皆引发天地异象。", "lore_en":"The supreme sovereign of the entire realm, channeling tectonic leylines to unleash cataclysms.", "mechanics":{"summon_every":4, "phase2_threshold":0.6, "phase2_mirror_shield":true, "phase3_threshold":0.25, "phase3_damage_boost":15, "phase3_double_attack":true}},
]
const MONSTER_ROSTER: Array[Dictionary] = ENEMIES

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

const EQUIPMENT_TIER_NAMES = [
	{"zh": "凡品", "en": "Mundane", "color": "8fa2a6"},
	{"zh": "灵品", "en": "Spiritual", "color": "5ec880"},
	{"zh": "宝品", "en": "Precious", "color": "58b8ff"},
	{"zh": "仙品", "en": "Celestial", "color": "ffd246"}
]

const EQUIPMENT_TIER_COSTS = [
	{"gold": 100, "dust": 20},
	{"gold": 250, "dust": 50},
	{"gold": 500, "dust": 100}
]

const EQUIPMENT_INSCRIBE_COST = {"gold": 30, "dust": 10}

const EQUIPMENT_TIER_DATA = {
	"emberBlade": [
		{"bonus": 3, "zh": "每回合第一张攻击牌伤害 +3。", "en": "First attack each turn deals +3 damage."},
		{"bonus": 5, "zh": "每回合第一张攻击牌伤害 +5。", "en": "First attack each turn deals +5 damage."},
		{"bonus": 7, "zh": "每回合第一张攻击牌伤害 +7。", "en": "First attack each turn deals +7 damage."},
		{"bonus": 10, "zh": "每回合第一张攻击牌伤害 +10。", "en": "First attack each turn deals +10 damage."}
	],
	"jadePlate": [
		{"shield": 8, "zh": "战斗开始时获得 8 点护盾。", "en": "Start battle with 8 Shield."},
		{"shield": 14, "zh": "战斗开始时获得 14 点护盾。", "en": "Start battle with 14 Shield."},
		{"shield": 20, "zh": "战斗开始时获得 20 点护盾。", "en": "Start battle with 20 Shield."},
		{"shield": 28, "zh": "战斗开始时获得 28 点护盾。", "en": "Start battle with 28 Shield."}
	],
	"soulPendant": [
		{"heal": 2, "max_times": 3, "zh": "击败敌人回复 2 点生命，每场最多 3 次。", "en": "Heal 2 HP on kill, up to 3 times per battle."},
		{"heal": 3, "max_times": 3, "zh": "击败敌人回复 3 点生命，每场最多 3 次。", "en": "Heal 3 HP on kill, up to 3 times per battle."},
		{"heal": 4, "max_times": 4, "zh": "击败敌人回复 4 点生命，每场最多 4 次。", "en": "Heal 4 HP on kill, up to 4 times per battle."},
		{"heal": 6, "max_times": 4, "zh": "击败敌人回复 6 点生命，每场最多 4 次。", "en": "Heal 6 HP on kill, up to 4 times per battle."}
	],
	"moonStaff": [
		{"refund": 1, "shield": 0, "zh": "每回合第一张策略牌返还 1 点能量。", "en": "First Tactic each turn refunds 1 Energy."},
		{"refund": 1, "shield": 2, "zh": "每回合第一张策略牌返还 1 点能量并获得 2 点护盾。", "en": "First Tactic each turn refunds 1 Energy and grants 2 Shield."},
		{"refund": 1, "shield": 4, "zh": "每回合第一张策略牌返还 1 点能量并获得 4 点护盾。", "en": "First Tactic each turn refunds 1 Energy and grants 4 Shield."},
		{"refund": 1, "shield": 7, "zh": "每回合第一张策略牌返还 1 点能量并获得 7 点护盾。", "en": "First Tactic each turn refunds 1 Energy and grants 7 Shield."}
	],
	"thornArmor": [
		{"retaliate": 2, "zh": "受到敌方伤害后反击 2 点。", "en": "Retaliate 2 damage when hit by enemies."},
		{"retaliate": 4, "zh": "受到敌方伤害后反击 4 点。", "en": "Retaliate 4 damage when hit by enemies."},
		{"retaliate": 6, "zh": "受到敌方伤害后反击 6 点。", "en": "Retaliate 6 damage when hit by enemies."},
		{"retaliate": 9, "zh": "受到敌方伤害后反击 9 点。", "en": "Retaliate 9 damage when hit by enemies."}
	],
	"tideCharm": [
		{"draw": 1, "shield": 0, "zh": "每回合首次获得护盾时抽 1 张牌。", "en": "First Shield gained each turn draws 1 card."},
		{"draw": 1, "shield": 2, "zh": "每回合首次获得护盾时抽 1 张牌并额外获得 2 点护盾。", "en": "First Shield gained each turn draws 1 card and gains 2 extra Shield."},
		{"draw": 1, "shield": 4, "zh": "每回合首次获得护盾时抽 1 张牌并额外获得 4 点护盾。", "en": "First Shield gained each turn draws 1 card and gains 4 extra Shield."},
		{"draw": 1, "shield": 6, "zh": "每回合首次获得护盾时抽 1 张牌并额外获得 6 点护盾。", "en": "First Shield gained each turn draws 1 card and gains 6 extra Shield."}
	],
	"stoneSpear": [
		{"bonus": 0, "zh": "攻击牌无视敌方护盾。", "en": "Attacks pierce enemy Shield."},
		{"bonus": 1, "zh": "攻击牌无视敌方护盾，攻击伤害 +1。", "en": "Attacks pierce enemy Shield, and deal +1 damage."},
		{"bonus": 2, "zh": "攻击牌无视敌方护盾，攻击伤害 +2。", "en": "Attacks pierce enemy Shield, and deal +2 damage."},
		{"bonus": 4, "zh": "攻击牌无视敌方护盾，攻击伤害 +4。", "en": "Attacks pierce enemy Shield, and deal +4 damage."}
	],
	"mistCloak": [
		{"shield": 0, "zh": "每第三次敌方攻击伤害归零。", "en": "Every 3rd enemy attack deals 0 damage."},
		{"shield": 3, "zh": "每第三次敌方攻击伤害归零并获得 3 点护盾。", "en": "Every 3rd enemy attack deals 0 damage and grants 3 Shield."},
		{"shield": 6, "zh": "每第三次敌方攻击伤害归零并获得 6 点护盾。", "en": "Every 3rd enemy attack deals 0 damage and grants 6 Shield."},
		{"shield": 10, "zh": "每第三次敌方攻击伤害归零并获得 10 点护盾。", "en": "Every 3rd enemy attack deals 0 damage and grants 10 Shield."}
	],
	"fortuneSeal": [
		{"mult": 1.15, "zh": "胜利金币增加 15%。", "en": "Gold rewards increased by 15%."},
		{"mult": 1.25, "zh": "胜利金币增加 25%。", "en": "Gold rewards increased by 25%."},
		{"mult": 1.35, "zh": "胜利金币增加 35%。", "en": "Gold rewards increased by 35%."},
		{"mult": 1.50, "zh": "胜利金币增加 50%。", "en": "Gold rewards increased by 50%."}
	],
	"stormBow": [
		{"draw": 1, "shield": 0, "zh": "击败敌人时抽 1 张牌。", "en": "Draw 1 card on kill."},
		{"draw": 1, "shield": 2, "zh": "击败敌人时抽 1 张牌并获得 2 点护盾。", "en": "Draw 1 card on kill and gain 2 Shield."},
		{"draw": 1, "shield": 4, "zh": "击败敌人时抽 1 张牌并获得 4 点护盾。", "en": "Draw 1 card on kill and gain 4 Shield."},
		{"draw": 2, "shield": 5, "zh": "击败敌人时抽 2 张牌并获得 5 点护盾。", "en": "Draw 2 cards on kill and gain 5 Shield."}
	],
	"phoenixMail": [
		{"revive_hp": 15, "zh": "每场一次，以 15 点生命抵挡致命伤害。", "en": "Survive lethal damage once with 15 HP."},
		{"revive_hp": 22, "zh": "每场一次，以 22 点生命抵挡致命伤害。", "en": "Survive lethal damage once with 22 HP."},
		{"revive_hp": 30, "zh": "每场一次，以 30 点生命抵挡致命伤害。", "en": "Survive lethal damage once with 30 HP."},
		{"revive_hp": 40, "zh": "每场一次，以 40 点生命抵挡致命伤害。", "en": "Survive lethal damage once with 40 HP."}
	],
	"focusCharm": [
		{"focus": 1, "strength": 0, "zh": "战斗开始时获得 1 层凝神。", "en": "Start battle with 1 Focus."},
		{"focus": 2, "strength": 0, "zh": "战斗开始时获得 2 层凝神。", "en": "Start battle with 2 Focus."},
		{"focus": 2, "strength": 1, "zh": "战斗开始时获得 2 层凝神与 1 点力量。", "en": "Start battle with 2 Focus and 1 Strength."},
		{"focus": 3, "strength": 1, "zh": "战斗开始时获得 3 层凝神与 1 点力量。", "en": "Start battle with 3 Focus and 1 Strength."}
	]
}

const INSCRIPTION_AFFIXES = [
	{"id": "inscr_hp", "name_zh": "气血", "name_en": "Vitality", "values": [3, 5, 8], "fmt_zh": "生命上限 +%d", "fmt_en": "Max HP +%d"},
	{"id": "inscr_shield", "name_zh": "坚甲", "name_en": "Warding", "values": [3, 6, 9], "fmt_zh": "开局护盾 +%d", "fmt_en": "Start Shield +%d"},
	{"id": "inscr_atk", "name_zh": "破煞", "name_en": "Breaker", "values": [1, 2, 3], "fmt_zh": "首击伤害 +%d", "fmt_en": "First Attack +%d Dmg"},
	{"id": "inscr_thorns", "name_zh": "逆鳞", "name_en": "Thorns", "values": [1, 2, 3], "fmt_zh": "受击反伤 +%d", "fmt_en": "Retaliate +%d Dmg"},
	{"id": "inscr_gold", "name_zh": "聚财", "name_en": "Wealth", "values": [5, 10, 15], "fmt_zh": "胜利金币 +%d%%", "fmt_en": "Victory Gold +%d%%"},
	{"id": "inscr_dust", "name_zh": "凝尘", "name_en": "Stardust", "values": [1, 2, 3], "fmt_zh": "胜利灵尘 +%d", "fmt_en": "Victory Dust +%d"},
	{"id": "inscr_heal", "name_zh": "回元", "name_en": "Recovery", "values": [1, 1, 2], "fmt_zh": "回合回复 +%d 气血", "fmt_en": "Restore +%d HP/Turn"},
	{"id": "inscr_crit", "name_zh": "凌厉", "name_en": "Ferocity", "values": [15, 25, 40], "fmt_zh": "首击暴击率 +%d%%", "fmt_en": "First Atk Crit +%d%%"}
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

# One-time "you just unlocked X" toasts (game._check_feature_unlocks()) for every gated Camp
# feature — otherwise a player only ever discovers Daily Trial/Abyss/Curse Run/etc. by noticing
# a new tab appeared. `kind` picks which profile field the threshold compares against
# ("unlocked" = campaign stage index, "difficulty" = challenge tier). Grouped by threshold
# rather than one entry per feature: Compendium, Daily Trial, Weekly Challenge, and Boss Rush
# all gate on the same `unlocked >= 5` (see their own _*_section() functions in
# game_camp_screen.gd), so they fire one combined toast — _toast() has no queue and always
# renders at the same fixed position, so four separate calls back to back would visually stack
# on top of each other, not display in sequence.
const FEATURE_UNLOCKS = [
	{"id":"shop","kind":"unlocked","threshold":2,"title_key":"ui.unlock_shop_title","desc_key":"ui.unlock_shop_desc","toast_key":"ui.unlock_shop_toast","icon":"nav_shop"},
	{"id":"ch1_features","kind":"unlocked","threshold":5,"title_key":"ui.unlock_camp_title","desc_key":"ui.unlock_camp_desc","toast_key":"ui.unlock_ch1_toast","icon":"nav_camp"},
	{"id":"trial_and_quests","kind":"unlocked","threshold":6,"title_key":"ui.unlock_trial_title","desc_key":"ui.unlock_trial_desc","toast_key":"ui.unlock_trial_toast","icon":"nav_trial"},
	{"id":"equipment","kind":"unlocked","threshold":8,"title_key":"ui.unlock_equip_title","desc_key":"ui.unlock_equip_desc","toast_key":"ui.unlock_equip_toast","icon":"nav_equip"},
	{"id":"abyss","kind":"unlocked","threshold":10,"title_key":"ui.unlock_abyss_title","desc_key":"ui.unlock_abyss_desc","toast_key":"ui.unlock_abyss_toast","icon":"nav_trial"},
	{"id":"runes","kind":"unlocked","threshold":12,"title_key":"ui.unlock_runes_title","desc_key":"ui.unlock_runes_desc","toast_key":"ui.unlock_runes_toast","icon":"nav_deck"},
	{"id":"meridians_and_codex","kind":"unlocked","threshold":15,"title_key":"ui.unlock_meridians_title","desc_key":"ui.unlock_meridians_desc","toast_key":"ui.unlock_meridians_toast","icon":"profile"},
	{"id":"difficulty_tiers","kind":"unlocked","threshold":25,"toast_key":"ui.unlock_difficulty_toast"},
	{"id":"curse_run","kind":"difficulty","threshold":2,"toast_key":"ui.unlock_curse_run_toast"},
	{"id":"tier_a2","kind":"unlocked","threshold":50,"toast_key":"ui.unlock_tier_a2_toast"},
	{"id":"tier_a3","kind":"unlocked","threshold":100,"toast_key":"ui.unlock_tier_a3_toast"},
	{"id":"tier_a4","kind":"unlocked","threshold":150,"toast_key":"ui.unlock_tier_a4_toast"},
	{"id":"tier_a5","kind":"unlocked","threshold":200,"toast_key":"ui.unlock_tier_a5_toast"},
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
	{"id":"soulLantern","icon":"✦","icon_mark":"flame","color":"78e9ff","zh":"引魂灯","en":"Soul Lantern","detail":"打出消耗牌时，下回合开始额外获得 1 点能量。","detail_en":"Gain 1 extra Energy next turn when an Exhaust card is played."},
	{"id":"spiritArmor","icon":"⬡","icon_mark":"shield_mark","color":"8ff5cf","zh":"玄甲残片","en":"Spirit Armor","detail":"回合结束时保留最多 30 点未被击破的护盾。","detail_en":"Retain up to 30 unspent Shield at end of turn."},
	{"id":"prismaticRune","icon":"✧","icon_mark":"sparkle","color":"d1a8ff","zh":"万象符石","en":"Prismatic Rune","detail":"战斗开始时，随机为手牌中 1 张卡牌注入回响效果。","detail_en":"Start battle: randomly grant Echo effect to 1 hand card."},
	{"id":"venomFlask","icon":"❥","icon_mark":"drop","color":"80e4c0","zh":"蚀毒灵盅","en":"Venom Flask","detail":"回合开始时，对所有中毒敌人造成其当前中毒层数 50% 的穿透伤害。","detail_en":"At turn start, deal piercing damage equal to 50% of enemy Poison."},
	{"id":"echoMirror","icon":"◎","icon_mark":"rings","color":"ffd47c","zh":"双极古镜","en":"Echo Mirror","detail":"每回合打出的第一张技能牌额外重复触发一次。","detail_en":"First Skill card played each turn triggers twice."},
	{"id":"ironThorns","icon":"✕","icon_mark":"cross_blade","color":"d4a373","zh":"荆棘铁棘","en":"Iron Thorns","detail":"受到直接攻击伤害时，对攻击者反弹 3 点伤害。","detail_en":"Reflect 3 damage when taking attack damage."},
	{"id":"phoenixFeather","icon":"♨","icon_mark":"flame","color":"ff7373","zh":"涅槃翎羽","en":"Phoenix Feather","detail":"受到致命伤害时免死并回复 20% 生命（单场战斗一次）。","detail_en":"Survive lethal damage once per battle, restoring 20% HP."},
	{"id":"jadePendant","icon":"◈","icon_mark":"sparkle","color":"9fd8c9","zh":"清灵玉佩","en":"Jade Pendant","detail":"每打出 3 张同属性卡牌，额外抽 1 张牌。","detail_en":"Every 3 same-element cards played, draw 1 card."},
	{"id":"voidHourglass","icon":"»","icon_mark":"chevrons","color":"b9a2ff","zh":"太虚沙漏","en":"Void Hourglass","detail":"战斗开始时，对所有敌人施加 1 层虚弱与 1 层易伤。","detail_en":"Start of battle: apply 1 Weak and 1 Vulnerable to all enemies."},
	{"id":"gamblerCoin","icon":"◒","icon_mark":"rings","color":"ffe08a","zh":"赌徒金铢","en":"Gambler Coin","detail":"战斗胜利获得的金币奖励提升 30%。","detail_en":"Gain 30% more Gold from battle victories."},
	{"id":"stormOrb","icon":"ϟ","icon_mark":"bolt","color":"78e9ff","zh":"雷暴宝珠","en":"Storm Orb","detail":"每打出 4 张攻击牌，对所有敌人施加 1 层易伤。","detail_en":"Every 4 Attack cards played, apply 1 Vulnerable to all enemies."},
	{"id":"bloodChalice","icon":"❥","icon_mark":"drop","color":"ff5252","zh":"猩红圣杯","en":"Blood Chalice","detail":"击杀敌人时，手牌中所有攻击牌本场伤害永久 +2。","detail_en":"Killing a foe gives +2 damage to all Attacks in hand for this battle."},
	{"id":"heavyAnchor","icon":"⚓","icon_mark":"shield_mark","color":"607d8b","zh":"定海玄锚","en":"Heavy Anchor","detail":"单次获得 15 点以上护盾时，对随机敌人造成 6 点冲击伤害。","detail_en":"Whenever gaining 15+ Shield in one action, deal 6 damage to an enemy."},
	{"id":"spiritCompass","icon":"🧭","icon_mark":"sparkle","color":"a2d9ff","zh":"寻灵罗盘","en":"Spirit Compass","detail":"在地图上选择分叉节点时，立即获得 15 金币。","detail_en":"Gain 15 bonus Gold upon choosing a map fork."},
	{"id":"dragonScale","icon":"⬡","icon_mark":"shield_mark","color":"4caf50","zh":"青龙逆鳞","en":"Dragon Scale","detail":"每当受到生命伤害时，立刻抽 1 张牌。","detail_en":"Draw 1 card whenever you take unblocked HP damage."},
	{"id":"lotusIncense","icon":"❦","icon_mark":"leaf","color":"e1bee7","zh":"静心清莲","en":"Lotus Incense","detail":"回合结束时若手牌为空，下回合初始抽牌数 +2。","detail_en":"If your hand is empty at turn end, draw +2 cards next turn."},
	{"id":"frostNeedle","icon":"»","icon_mark":"chevrons","color":"80deea","zh":"幽霜灵针","en":"Frost Needle","detail":"施加减益状态时，目标敌人失去 2 点护盾。","detail_en":"Applying any debuff strips 2 Shield from the target."},
	{"id":"goldenAbacus","icon":"✦","icon_mark":"rings","color":"ffd54f","zh":"天机金算","en":"Golden Abacus","detail":"强化卡牌的金币消耗降低 25%。","detail_en":"Card upgrade gold costs are reduced by 25%."},
	{"id":"celestialBell","icon":"ϟ","icon_mark":"bolt","color":"fff59d","zh":"惊云玉磬","en":"Celestial Bell","detail":"第 1 回合造成的伤害提升 25%。","detail_en":"Deal 25% more damage on Turn 1."},
	{"id":"shadowCloak","icon":"≋","icon_mark":"wave","color":"90a4ae","zh":"夜行幽斗","en":"Shadow Cloak","detail":"第 1 回合获得 12 点护盾。","detail_en":"Gain 12 Shield on Turn 1."},
	{"id":"vitalityGourd","icon":"❦","icon_mark":"leaf","color":"c8e6c9","zh":"乾坤葫芦","en":"Vitality Gourd","detail":"以满生命值通过关卡时，生命上限永久 +1。","detail_en":"Clearing a stage at full HP permanently grants +1 Max HP."},
	{"id":"blazingBrazier","icon":"♨","icon_mark":"flame","color":"ffab91","zh":"烈阳神鼎","en":"Blazing Brazier","detail":"施加燃烧时有 50% 几率额外追加 2 层。","detail_en":"Applying Burn has a 50% chance to apply 2 extra stacks."},
	{"id":"serpentFang","icon":"✕","icon_mark":"cross_blade","color":"aed581","zh":"青蛇妖牙","en":"Serpent Fang","detail":"攻击中毒敌人时伤害提升 35%。","detail_en":"Attacks against poisoned enemies deal 35% more damage."},
	{"id":"mysticScroll","icon":"🕮","icon_mark":"sparkle","color":"ce93d8","zh":"上古残卷","en":"Mystic Scroll","detail":"战斗开始时，随机从抽牌堆抽取 1 张 0 费用卡牌。","detail_en":"Start of battle: draw 1 random 0-cost card from draw pile."},
	{"id":"obsidianIdol","icon":"⬡","icon_mark":"shield_mark","color":"78909c","zh":"黑曜石偶","en":"Obsidian Idol","detail":"打破敌人护盾时，对其造成 8 点碎盾冲击伤害。","detail_en":"Breaking an enemy Shield deals 8 shatter damage."},
	{"id":"swiftBoots","icon":"»","icon_mark":"chevrons","color":"b2dfdb","zh":"神行飞履","en":"Swift Boots","detail":"每回合第一次打出耗费 2 点以上能量的卡牌时，返还 1 点能量。","detail_en":"First 2+ energy card played each turn refunds 1 Energy."},
	{"id":"cinderBand","icon":"♨","icon_mark":"flame","color":"ff8a65","zh":"烬火戒环","en":"Cinder Band","detail":"自身带有燃烧时，攻击牌伤害 +3。","detail_en":"While you have Burn, your attacks deal +3 damage."},
	{"id":"moonstone","icon":"◈","icon_mark":"rings","color":"b39ddb","zh":"太阴月石","en":"Moonstone","detail":"奇数回合抽牌数 +1，偶数回合获得 6 点护盾。","detail_en":"Odd turns: draw +1 card; Even turns: gain 6 Shield."},
	{"id":"spiritBanner","icon":"✦","icon_mark":"cross_blade","color":"ffcc80","zh":"聚灵战旗","en":"Spirit Banner","detail":"击杀随从敌人时，对主首领造成 12 点震慑伤害。","detail_en":"Defeating an add deals 12 damage to the stage boss."},
	{"id":"harmoniousBell","icon":"≋","icon_mark":"wave","color":"80cbc4","zh":"六合玲珑铎","en":"Harmonious Bell","detail":"牌组中每拥有 4 种不同属性卡牌，开局手牌数 +1。","detail_en":"Every 4 distinct elements in deck grants +1 opening hand card."},
]

# High-stakes, high-impact relics reserved for Great Boss kills specifically — a regular
# boss draws from RELICS minus this list, so these three stay rare and always feel like the
# reward for the hardest fight in a chapter, not something that can also drop from a
# mid-chapter boss.
const BOSS_RELIC_IDS = ["cursedTome", "titanBell", "chaosPrism"]

const RELIC_RESONANCES = [
	{
		"id": "res_sun_moon",
		"icon": "☯",
		"color": "ffe08a",
		"relics": ["thunderSeal", "mirrorScale"],
		"zh": "日月同辉",
		"en": "Sun & Moon Harmony",
		"detail": "每 3 回合额外获得 2 点能量（共+4 点），且回合结束保留 100% 护盾。",
		"detail_en": "Gain +2 extra Energy every 3rd turn (+4 total), and retain 100% Shield at turn end."
	},
	{
		"id": "res_fox_wind",
		"icon": "✦",
		"color": "78e9ff",
		"relics": ["foxCharm", "windChime"],
		"zh": "灵狐引魂",
		"en": "Fox Spirit Guidance",
		"detail": "抽牌堆洗牌时获得 1 点能量；第 2 回合额外多摸 1 张牌。",
		"detail_en": "Gain 1 Energy when draw pile reshuffles; draw +1 extra card on Turn 2."
	},
	{
		"id": "res_star_flame",
		"icon": "♨",
		"color": "ff9868",
		"relics": ["starShard", "emberCore"],
		"zh": "星火燎原",
		"en": "Blazing Star Shards",
		"detail": "首张攻击牌施加 2 层燃烧；燃烧每层结算伤害额外 +1 点（共+2 点）。",
		"detail_en": "First attack each turn applies 2 Burn; Burn deals +1 extra damage per stack (+2 total)."
	},
	{
		"id": "res_blood_seed",
		"icon": "❦",
		"color": "8ff5cf",
		"relics": ["ancientSeed", "bloodJade"],
		"zh": "枯木逢春",
		"en": "Blood & Arbor Vitality",
		"detail": "每回合开始回复 4 点生命（替代原 2 点）；过量回复直接转化为等量护盾！",
		"detail_en": "Restore 4 HP at start of turn (replaces 2 HP); any overheal is converted into Shield!"
	},
	{
		"id": "res_nether_pact",
		"icon": "🕮",
		"color": "ff5577",
		"relics": ["cursedTome", "bloodJade"],
		"zh": "冥渊血契",
		"en": "Nether Blood Pact",
		"detail": "击败敌人时立即多抽 1 张牌，并免疫下一回合死灵禁典的反噬自伤！",
		"detail_en": "Defeating an enemy draws 1 card and negates Cursed Tome self-damage for the next turn."
	},
	{
		"id": "res_chaos_titan",
		"icon": "💎",
		"color": "b359ff",
		"relics": ["titanBell", "chaosPrism"],
		"zh": "太虚混沌",
		"en": "Chaos Horizon",
		"detail": "战斗开始额外获得 +15 最大生命与生命；对易伤敌人造成的所有伤害 +2 点。",
		"detail_en": "Start battle with +15 extra Max HP and HP; all attacks deal +2 damage to Vulnerable targets."
	}
]

# combat.gd's upgrade bonus is already a raw int add with no cap of its own (see
# state.upgrades.get(card.id, 0) in _play_card/_resolve_effects/_preview_damage) — the cap
# lives here, purely as a UI/economy rule, so a card can be Spirit-Smithed to +1 once and,
# on a later rest-site visit, Awakened to +2, then no further.
const MAX_CARD_UPGRADE := 2

# Draft Arena (see game_camp_screen.gd's show_spirit_draft() and game_battle_screen.gd's
# _leave_battle()): a run ends either in a Grand Champion toast at DRAFT_WIN_CAP wins or a
# run-completed toast at DRAFT_LOSS_CAP losses. Both paths must reset the same fields
# _abandon_draft() resets (round/deck/current_pool/wins/losses) so the next run starts clean.
const DRAFT_WIN_CAP := 6
const DRAFT_LOSS_CAP := 3
# Caps profile.friends so a pasted-code-in-a-loop mistake (or a griefing attempt) can't grow the
# leaderboards' `user_id=in.(...)` PostgREST filter into an unbounded URL.
const FRIEND_LIST_MAX := 50

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

# Phase 8 — Curse Run: opt-in, self-selected handicaps for Ascension 2+ players chasing a
# harder fight and a permanent per-mutator badge (profile.curse_run.cleared). Two of the plan's
# named mutators don't map onto this game's actual systems as written — see
# Docs/GROWTH_ROADMAP.md's progress log for the substitutions (Draft Only -> Ironclad Will) and
# why. Every key below is either a modifier combat.gd already reads for another mode
# (extra_enemy, damage_mult) or a small, generic new one added specifically for this phase (see
# combat.gd's own comments at each read site) — a mutator is data, not a new engine branch,
# same principle AGENTS.md documents for encounter mechanics and card effects. `no_relics` and
# `haunted_deck` are handled entirely at the battle-launch call site (an empty relics array / an
# extra decay_blight spliced into the battle-only deck copy), not in combat.gd at all.
const MUTATORS: Array[Dictionary] = [
	{"id":"glass_cannon","nameKey":"mutator.glass_cannon.name","descKey":"mutator.glass_cannon.desc","color":"ff6b6b","player_max_hp":30,"player_dmg_mult":1.5},
	{"id":"energy_famine","nameKey":"mutator.energy_famine.name","descKey":"mutator.energy_famine.desc","color":"6ee3ff","energy_cap":2},
	{"id":"mirror_world","nameKey":"mutator.mirror_world.name","descKey":"mutator.mirror_world.desc","color":"c9a6ff","mirror_hp":true},
	{"id":"haunted_deck","nameKey":"mutator.haunted_deck.name","descKey":"mutator.haunted_deck.desc","color":"9f7bd1","haunted_deck":true},
	{"id":"ironclad_will","nameKey":"mutator.ironclad_will.name","descKey":"mutator.ironclad_will.desc","color":"b8c4c9","no_relics":true},
	{"id":"elite_gauntlet","nameKey":"mutator.elite_gauntlet.name","descKey":"mutator.elite_gauntlet.desc","color":"ff9a4c","extra_enemy":1},
	{"id":"barren_harvest","nameKey":"mutator.barren_harvest.name","descKey":"mutator.barren_harvest.desc","color":"d4b26a","reward_mult":0.5},
	{"id":"berserkers_pact","nameKey":"mutator.berserkers_pact.name","descKey":"mutator.berserkers_pact.desc","color":"e34d4d","player_dmg_mult":1.3,"damage_mult":1.3},
	{"id":"no_mercy","nameKey":"mutator.no_mercy.name","descKey":"mutator.no_mercy.desc","color":"7a7a8c","no_heal":true},
	{"id":"fewer_draws","nameKey":"mutator.fewer_draws.name","descKey":"mutator.fewer_draws.desc","color":"8affc2","draw_penalty":1},
]
# Floor at which a mutator's permanent "cleared" badge unlocks — modest and achievable (matches
# a single chapter's length) since the badge is meant to reward trying every mutator at least
# once, not grinding any single one deep.
const CURSE_RUN_BADGE_FLOOR := 5

func mutator(id: String) -> Dictionary:
	for m in MUTATORS:
		if m.id == id: return m
	return {}

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

# ---------------------------------------------------------------------------------------------
# Signature mechanics for EVERY chapter boss, not just the ten that carry hand-authored data on
# their ENEMIES row.
#
# Before this, only ten chapters (5, 10, 15, ... 50 — the m_s025/m_s050/... rows) had any
# mechanics of their own; the other forty chapter-5 fights were mechanically identical apart
# from their stat block, so "the chapter boss" was a different coat of paint rather than a
# different fight. This table gives all fifty a signature set.
#
# Hard rule for anything added here: **every key must be one combat.gd actually reads.** A key
# nothing consults parses, type-checks, and then silently never happens at runtime — this repo
# has already shipped that bug twice (the unused `thorns` field, and the `mechanics` dict that
# _build_encounters() discarded entirely). The read sites are listed next to each key below so
# the next person can check the claim instead of trusting it.
#
#   absorb_burn_every / shield_per_absorbed_burn  -> _apply_boss_player_turn_end()
#   starting_shield                               -> create()
#   shield_per_turn / regeneration                -> end_turn() (per enemy turn)
#   frost_armor / thorns / dodge_every            -> _damage_enemy()
#   heal_on_attack                                -> _execute_intent()
#   critical_every / below_half                   -> _roll_intent()
#   mark_hand_penalty / counterspell_*            -> _apply_boss_player_turn_end()
#   enrage_on_block_threshold / enrage_attack_boost -> _apply_boss_player_turn_end()
#   soul_tide_* / exhaust_hand_every / summon_every / phase2_mirror_shield
#                                                 -> _apply_boss_player_turn_start()
#   phase2_* / phase3_* thresholds                -> _check_mechanics_phases()
#
# The shape is the archetype; the numbers scale with the realm band (`r`) so no two chapters
# reuse an early chapter's values verbatim. Where a chapter's own ENEMIES row is authored, those
# keys still win — see the merge in _build_encounters().
func boss_mechanics_for(chapter: int) -> Dictionary:
	var r: int = (chapter - 1) / 10        # realm band 0..4
	var archetype: int = (chapter - 1) % 10
	match archetype:
		0:  # Ember Furnace — punishes Burn, then weaponises it.
			return {"absorb_burn_every":3, "shield_per_absorbed_burn":2 + r, "phase2_threshold":0.5, "phase2_burn_on_hit":2 + r}
		1:  # Glacial Bastion — the longer you take, the more it armours up.
			return {"starting_shield":15 + 5 * r, "shield_per_turn":2 + r, "frost_armor":1 + r, "phase2_threshold":0.45, "phase2_damage_boost":2 + r}
		2:  # Undying — must be killed twice; the first death bites back.
			return {"revive_hp_pct":0.3, "revive_attack_pierce":8 + 3 * r, "thorns":1 + r, "phase2_threshold":0.4, "phase2_damage_boost":2 + r}
		3:  # Soul Tide — clogs the hand every turn.
			return {"soul_tide_curse":"void_curse", "soul_tide_count":1, "phase2_threshold":0.4, "phase2_soul_tide":2}
		4:  # Memory Erase — deletes your most expensive card, then does it faster.
			return {"exhaust_hand_every":3, "regeneration":2 + r, "phase2_threshold":0.35, "phase2_exhaust_every":2}
		5:  # Hunter's Mark — punishes ending the turn with cards left in hand.
			return {"mark_hand_penalty":5 + 2 * r, "mark_hand_threshold":3, "phase2_threshold":0.5, "phase2_damage_boost":2 + r}
		6:  # Counterspell — punishes long card chains.
			return {"counterspell_threshold":3, "counterspell_burn":1 + r, "phase2_threshold":0.5, "phase2_damage_boost":3 + r}
		7:  # Blood Price — every swing heals it.
			return {"heal_on_attack":3 + r, "regeneration":1 + r, "phase2_threshold":0.5, "phase2_damage_boost":2 + r}
		8:  # Mirror Shield — negates your first card each turn once phase 2 begins.
			return {"dodge_every":maxi(2, 4 - r), "phase2_threshold":0.5, "phase2_mirror_shield":true, "phase2_damage_boost":2 + r}
		_:  # Enrage Stack — rewards you for not over-blocking.
			return {"enrage_on_block_threshold":10, "enrage_attack_boost":2 + r, "below_half":1 + r, "phase2_threshold":0.5, "phase2_damage_boost":2 + r}

# Returns the two fork options for branch-able map levels (2, 3, 4).
# Empty array means this level has no branch — the node kind is fixed (levels 1 and 5).
# branch_index 0 = left/top option, 1 = right/bottom option.
# The player's choice is persisted in profile.map_choices[str(stage_index)].
func node_branch_options(index: int) -> Array[String]:
	var level := index % 5 + 1
	match level:
		2: return ["event", "merchant"]  # story event vs shop — risk vs spend
		3: return ["elite", "battle"]    # harder fight (better reward) vs normal fight
		4: return ["rest", "bonus"]      # heal 25 HP vs extra card-draft reward
		_: return []                     # level 1 (normal) and level 5 (boss/greatboss) are fixed

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
			"strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike",
			"ward", "ward", "ward", "ward", "ward", "ward",
			"foxfire", "foxfire", "foxfire", "foxfire",
			"wildSpark", "wildSpark", "wildSpark",
			"emberClaw", "emberClaw",
			"foxBlessing", "foxBlessing"
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
			"strike", "strike", "strike", "strike", "strike", "strike",
			"ward", "ward", "ward", "ward", "ward", "ward", "ward", "ward",
			"stoneBreaker", "stoneBreaker", "stoneBreaker", "stoneBreaker",
			"ironHide", "ironHide", "ironHide",
			"steadyPulse", "steadyPulse",
			"stoneRebound", "stoneRebound"
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
			"strike", "strike", "strike", "strike", "strike", "strike", "strike", "strike",
			"ward", "ward", "ward", "ward", "ward", "ward",
			"moonfang", "moonfang", "moonfang", "moonfang",
			"cinderHex", "cinderHex", "cinderHex",
			"twinMoon", "twinMoon",
			"piercingBolt", "piercingBolt"
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
			"strike", "strike", "strike", "strike", "strike", "strike",
			"ward", "ward", "ward", "ward", "ward", "ward",
			"toxinDart", "toxinDart", "toxinDart", "toxinDart", "toxinDart",
			"witherTouch", "witherTouch", "witherTouch", "witherTouch",
			"miasmaBrew", "miasmaBrew",
			"miasma_shield", "miasma_shield"
		]
	}
]

const SEVEN_DAY_JOURNEY = [
	{
		"day": 1,
		"title_zh": "第一日 · 灵狐初醒",
		"title_en": "Day 1: Fox Awakening",
		"desc_zh": "打出 5 张攻击牌",
		"desc_en": "Play 5 Attack cards in combat",
		"target_type": "cards_played",
		"target_count": 5,
		"reward_card": "samadhiFire",
		"gold": 100,
		"jade": 20
	},
	{
		"day": 2,
		"title_zh": "第二日 · 磐石之御",
		"title_en": "Day 2: Bulwark Defense",
		"desc_zh": "累计获得 30 点护盾",
		"desc_en": "Gain 30 total shield in combat",
		"target_type": "shield_gained",
		"target_count": 30,
		"reward_card": "shieldSlam",
		"gold": 150,
		"jade": 20
	},
	{
		"day": 3,
		"title_zh": "第三日 · 幽影连袭",
		"title_en": "Day 3: Shadow Flurry",
		"desc_zh": "单场战斗打出 8 张牌",
		"desc_en": "Play 8 cards in a single combat",
		"target_type": "cards_single_battle",
		"target_count": 8,
		"reward_card": "shadowClone",
		"gold": 200,
		"jade": 25
	},
	{
		"day": 4,
		"title_zh": "第四日 · 瘴毒爆发",
		"title_en": "Day 4: Miasma Eruption",
		"desc_zh": "累计造成 50 点伤害",
		"desc_en": "Deal 50 total damage in combat",
		"target_type": "damage_dealt",
		"target_count": 50,
		"reward_card": "catalyst",
		"gold": 250,
		"jade": 25
	},
	{
		"day": 5,
		"title_zh": "第五日 · 元素共鸣",
		"title_en": "Day 5: Elemental Surge",
		"desc_zh": "完成 2 场战斗胜利",
		"desc_en": "Achieve 2 combat victories",
		"target_type": "victories",
		"target_count": 2,
		"reward_card": "spiritSurge",
		"gold": 300,
		"jade": 30
	},
	{
		"day": 6,
		"title_zh": "第六日 · 潜修深渊",
		"title_en": "Day 6: Deep Cultivation",
		"desc_zh": "击败 1 位精英或领主敌人",
		"desc_en": "Defeat 1 elite or boss enemy",
		"target_type": "elites_or_bosses",
		"target_count": 1,
		"reward_card": "bastionForm",
		"gold": 350,
		"jade": 35
	},
	{
		"day": 7,
		"title_zh": "第七日 · 极道飞升",
		"title_en": "Day 7: Heavenly Ascension",
		"desc_zh": "累计赢得 5 场战斗胜利",
		"desc_en": "Achieve 5 total victories",
		"target_type": "victories",
		"target_count": 5,
		"reward_card": "bloodPact",
		"gold": 500,
		"jade": 50
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

# Samsara / Reincarnation (C2): scaling permanent blessings granted on rebirth
func samsara_bonuses(count: int) -> Dictionary:
	var bonuses := {
		"max_hp": 0,
		"starting_shield": 0,
		"turn1_draw": 0,
		"starting_gold": 0,
	}
	if count <= 0:
		return bonuses
	# Level 1: "凡蜕化灵" (+6 Max HP, +50 Starting Gold upon rebirth)
	bonuses.max_hp += 6
	bonuses.starting_gold += 50
	if count >= 2:
		# Level 2: "太虚凝气" (+4 Starting Shield)
		bonuses.starting_shield += 4
	if count >= 3:
		# Level 3: "灵机顿悟" (+1 Card Draw on Turn 1)
		bonuses.turn1_draw += 1
	if count >= 4:
		# Level 4+: "九转登仙" (+4 Max HP and +2 Starting Shield per additional tier)
		var extra: int = count - 3
		bonuses.max_hp += extra * 4
		bonuses.starting_shield += extra * 2
	return bonuses

func samsara_title(count: int, language := "zh-Hans") -> String:
	if count <= 0:
		return "凡体肉胎" if language == "zh-Hans" else "Mortal"
	elif count == 1:
		return "一转散仙" if language == "zh-Hans" else "1st Samsara (Wandering Immortal)"
	elif count == 2:
		return "二转真仙" if language == "zh-Hans" else "2nd Samsara (True Immortal)"
	elif count == 3:
		return "三转玄仙" if language == "zh-Hans" else "3rd Samsara (Mystic Immortal)"
	elif count == 4:
		return "四转金仙" if language == "zh-Hans" else "4th Samsara (Golden Immortal)"
	else:
		return ("%d转极境天仙" % count) if language == "zh-Hans" else ("%dth Samsara (Celestial Lord)" % count)

# ------------------------------------------------------------------------------
# Cultivation Meridians (Talent Tree / 灵脉修真)
# ------------------------------------------------------------------------------

const MERIDIAN_NODES: Dictionary = {
	# 任脉·气血 (Ren Meridian - Vitality & Defense)
	"ren_1": {
		"id": "ren_1",
		"branch": "ren",
		"max_rank": 5,
		"costs": [20, 30, 40, 50, 60],
		"name_zh": "气血培元",
		"name_en": "Vitality Foundation",
		"desc_zh": "壮大体魄气血，永久提升生命上限 +%d 点",
		"desc_en": "Strengthen physical vessel, +%d Max HP",
		"stat": "max_hp",
		"stat_per_rank": 5
	},
	"ren_2": {
		"id": "ren_2",
		"branch": "ren",
		"max_rank": 5,
		"costs": [25, 35, 45, 55, 65],
		"name_zh": "护体罡气",
		"name_en": "Aegis Barrier",
		"desc_zh": "经络生罡，每场战斗开局获得 +%d 点护盾",
		"desc_en": "Form protective barrier, +%d Starting Shield",
		"stat": "shield_start",
		"stat_per_rank": 4
	},
	"ren_3": {
		"id": "ren_3",
		"branch": "ren",
		"max_rank": 3,
		"costs": [50, 75, 100],
		"name_zh": "生生不息",
		"name_en": "Endless Vitality",
		"desc_zh": "气血循环，战斗中每回合恢复 %d 点生命值",
		"desc_en": "Perpetual regeneration, restore %d HP per turn",
		"stat": "heal_per_turn",
		"stat_per_rank": 1
	},

	# 督脉·罡气 (Du Meridian - Offensive Might)
	"du_1": {
		"id": "du_1",
		"branch": "du",
		"max_rank": 5,
		"costs": [20, 30, 40, 50, 60],
		"name_zh": "首击重创",
		"name_en": "Decisive Strike",
		"desc_zh": "蓄力暴击，每回合首张攻击牌伤害 +%d 点",
		"desc_en": "Concentrated burst, +%d First Attack Damage per turn",
		"stat": "first_attack_bonus",
		"stat_per_rank": 4
	},
	"du_2": {
		"id": "du_2",
		"branch": "du",
		"max_rank": 3,
		"costs": [30, 45, 60],
		"name_zh": "真火附灵",
		"name_en": "Soulflame Infusion",
		"desc_zh": "周天真火，开局向全场敌人施加 %d 层灼烧",
		"desc_en": "Ignite the battlefield, apply %d Starting Burn to all enemies",
		"stat": "burn_start",
		"stat_per_rank": 2
	},
	"du_3": {
		"id": "du_3",
		"branch": "du",
		"max_rank": 2,
		"costs": [60, 100],
		"name_zh": "万象通天",
		"name_en": "Celestial Might",
		"desc_zh": "融汇罡气，战斗开局永久获得 +%d 点力量",
		"desc_en": "Harness boundless power, +%d Starting Strength",
		"stat": "strength_start",
		"stat_per_rank": 1
	},

	# 冲脉·通灵 (Chong Meridian - Flow & Economy)
	"chong_1": {
		"id": "chong_1",
		"branch": "chong",
		"max_rank": 2,
		"costs": [50, 100],
		"name_zh": "聚灵开悟",
		"name_en": "Spiritual Insight",
		"desc_zh": "灵光一闪，战斗第 1 回合额外摸 %d 张牌",
		"desc_en": "Lightning flash of mind, draw +%d bonus card on turn 1",
		"stat": "draw_turn1",
		"stat_per_rank": 1
	},
	"chong_2": {
		"id": "chong_2",
		"branch": "chong",
		"max_rank": 1,
		"costs": [80],
		"name_zh": "天元灌顶",
		"name_en": "Primal Surge",
		"desc_zh": "天地注气，战斗第 1 回合额外获得 +1 点灵力",
		"desc_en": "Surge of pure chi, +1 Energy on turn 1",
		"stat": "energy_turn1",
		"stat_per_rank": 1
	},
	"chong_3": {
		"id": "chong_3",
		"branch": "chong",
		"max_rank": 3,
		"costs": [30, 50, 70],
		"name_zh": "点石成金",
		"name_en": "Midas Fortune",
		"desc_zh": "鸿运当头，通关战役结算时获得灵石加成 +%d%%",
		"desc_en": "Abundant harvest, +%d%% bonus Gold from battle victories",
		"stat": "gold_mult",
		"stat_per_rank": 15
	}
}

func meridian_node(node_id: String) -> Dictionary:
	return MERIDIAN_NODES.get(node_id, {})

func meridian_cost(node_id: String, current_rank: int) -> int:
	var node: Dictionary = meridian_node(node_id)
	if node.is_empty(): return -1
	var costs: Array = node.get("costs", [])
	if current_rank < 0 or current_rank >= costs.size(): return -1
	return int(costs[current_rank])

func meridian_total_spent(allocated: Dictionary) -> int:
	var total: int = 0
	for node_id in allocated:
		var node: Dictionary = meridian_node(str(node_id))
		if node.is_empty(): continue
		var rank: int = mini(int(allocated[node_id]), int(node.get("max_rank", 0)))
		var costs: Array = node.get("costs", [])
		for r in rank:
			if r < costs.size(): total += int(costs[r])
	return total

func meridian_bonuses(allocated: Dictionary) -> Dictionary:
	var bonuses := {
		"max_hp": 0,
		"shield_start": 0,
		"heal_per_turn": 0,
		"first_attack_bonus": 0,
		"burn_start": 0,
		"strength_start": 0,
		"draw_turn1": 0,
		"energy_turn1": 0,
		"gold_mult": 1.0,
	}
	for node_id in allocated:
		var node: Dictionary = meridian_node(str(node_id))
		if node.is_empty(): continue
		var rank: int = mini(int(allocated[node_id]), int(node.get("max_rank", 0)))
		if rank <= 0: continue
		var stat: String = str(node.get("stat", ""))
		var val_per_rank: int = int(node.get("stat_per_rank", 0))
		if stat == "gold_mult":
			bonuses.gold_mult += float(rank * val_per_rank) / 100.0
		elif bonuses.has(stat):
			bonuses[stat] += rank * val_per_rank
	return bonuses

func meridian_name(node_id: String, language := "zh-Hans") -> String:
	var node: Dictionary = meridian_node(node_id)
	if node.is_empty(): return node_id
	return str(node.get("name_zh" if language == "zh-Hans" else "name_en", node_id))

func meridian_desc(node_id: String, rank: int, language := "zh-Hans") -> String:
	var node: Dictionary = meridian_node(node_id)
	if node.is_empty(): return ""
	var tmpl: String = str(node.get("desc_zh" if language == "zh-Hans" else "desc_en", ""))
	var preview_rank: int = maxi(1, rank)
	var val: int = preview_rank * int(node.get("stat_per_rank", 0))
	return tmpl % val

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
	{"id":"collect_all","kind":"card_collection","target":165,"tier":"platinum","nameKey":"ach.collect_all.name","descKey":"ach.collect_all.desc"},
	{"id":"relics_all","kind":"relic_count","target":11,"tier":"platinum","nameKey":"ach.relics_all.name","descKey":"ach.relics_all.desc"},
	{"id":"mastery5","kind":"mastery_level","target":5,"tier":"gold","nameKey":"ach.mastery5.name","descKey":"ach.mastery5.desc"},
	{"id":"abyss10","kind":"abyss_floor","target":10,"tier":"silver","nameKey":"ach.abyss10.name","descKey":"ach.abyss10.desc"},
	{"id":"abyss30","kind":"abyss_floor","target":30,"tier":"platinum","nameKey":"ach.abyss30.name","descKey":"ach.abyss30.desc"},
	{"id":"trial_badges5","kind":"daily_trial_badges","target":5,"tier":"bronze","nameKey":"ach.trial_badges5.name","descKey":"ach.trial_badges5.desc"},
	{"id":"trial_badges20","kind":"daily_trial_badges","target":20,"tier":"gold","nameKey":"ach.trial_badges20.name","descKey":"ach.trial_badges20.desc"},
	{"id":"compendium50","kind":"compendium_percent","target":50,"tier":"silver","nameKey":"ach.compendium50.name","descKey":"ach.compendium50.desc"},
	{"id":"compendium100","kind":"compendium_percent","target":100,"tier":"platinum","nameKey":"ach.compendium100.name","descKey":"ach.compendium100.desc"},
	{"id":"samsara1","kind":"samsara_count","target":1,"tier":"platinum","nameKey":"ach.samsara1.name","descKey":"ach.samsara1.desc"},
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

const RANDOM_STORY_EVENTS: Array[Dictionary] = [
	{
		"id": "ancient_sanctum", "icon": "⛩️", "color": "ffd700",
		"title_zh": "古修遗府", "title_en": "Ancient Sanctum",
		"desc_zh": "你在绝壁间发现了一座上古大能的遗留洞府，石门半掩，古老的符光在昏暗中流转。案几上摆放着灵光闪烁的法宝残片，石榻旁则有一炉温热的洗髓灵泉。",
		"desc_en": "You stumble upon an ancient immortal's hidden dwelling. Glimmering relic fragments rest on a stone altar beside a steaming cleansing spring.",
		"choices": [
			{"label_zh": "取走法宝（失去 12 生命，获得 1 件遗物）", "label_en": "Take Relic (-12 HP, Gain Relic)", "type": "damage_for_relic", "hp_cost": 12},
			{"label_zh": "饮用灵泉（恢复 20 点生命）", "label_en": "Drink Spring (Heal 20 HP)", "type": "heal", "heal_amount": 20},
			{"label_zh": "搜寻古币（获得 45 金币）", "label_en": "Loot Coins (Gain 45 Gold)", "type": "gold", "gold_amount": 45}
		]
	},
	{
		"id": "mystic_spring", "icon": "🍵", "color": "78e9ff",
		"title_zh": "迷雾泉眼", "title_en": "Mystic Spring",
		"desc_zh": "林深雾浓处，一湾泛着幽蓝光晕的泉眼静静流淌。微风拂过，水面荡起净化心灵的涟漪，似乎能涤除体内沉淀的浊气与执念。",
		"desc_en": "Deep in the misty woods lies an azure spring. Its ripples carry pure spiritual essence capable of cleansing corruption.",
		"choices": [
			{"label_zh": "涤净心魔（从牌组移除 1 张卡牌）", "label_en": "Purify Mind (Remove 1 Card)", "type": "purge"},
			{"label_zh": "淬炼道法（强化 1 张卡牌）", "label_en": "Attune Card (Upgrade 1 Card)", "type": "upgrade"},
			{"label_zh": "汲取生机（回复 16 点生命）", "label_en": "Drink Water (Heal 16 HP)", "type": "heal", "heal_amount": 16}
		]
	},
	{
		"id": "sword_graveyard", "icon": "⚔️", "color": "ff7373",
		"title_zh": "万剑古冢", "title_en": "Sword Graveyard",
		"desc_zh": "残阳如血，千百柄锈蚀斑斑的古剑斜插在荒丘之上。其中一柄青锋虽断，却依然发出摄人心魄的龙吟之声，狂暴的煞气环绕其侧。",
		"desc_en": "Countless rusted blades pierce this barren mound. A broken blade among them still hums with lethal intent and lingering wrath.",
		"choices": [
			{"label_zh": "拔出狂刃（获得 65 金币，受到 10 点反噬伤害）", "label_en": "Draw Blade (Gain 65 Gold, Take 10 DMG)", "type": "damage_for_gold", "hp_cost": 10, "gold_amount": 65},
			{"label_zh": "参悟剑意（强化 1 张攻击卡牌）", "label_en": "Meditate (Upgrade 1 Card)", "type": "upgrade"},
			{"label_zh": "静默祭奠（获得 25 金币离开）", "label_en": "Pay Respects (Gain 25 Gold)", "type": "gold", "gold_amount": 25}
		]
	},
	{
		"id": "wishing_well", "icon": "🏺", "color": "ffe08a",
		"title_zh": "祈愿古井", "title_en": "Wishing Well",
		"desc_zh": "一口爬满青苔的古井横在荒野路旁，井底深不见底，偶尔闪过幽绿的金光。路旁的残碑记载：诚心投金者，井神必有所酬。",
		"desc_en": "An ancient moss-covered well sits along the road. Ancient runes suggest that sincere offerings are rewarded.",
		"choices": [
			{"label_zh": "投入 35 金币祈愿法宝（获得 1 件遗物）", "label_en": "Offer 35 Gold (Gain 1 Relic)", "type": "buy_relic", "gold_cost": 35},
			{"label_zh": "投入 15 金币祈愿甘霖（恢复 22 点生命）", "label_en": "Offer 15 Gold (Heal 22 HP)", "type": "buy_heal", "gold_cost": 15, "heal_amount": 22},
			{"label_zh": "不予理会，直接离开", "label_en": "Leave", "type": "leave"}
		]
	},
	{
		"id": "cursed_altar", "icon": "🩸", "color": "ff5252",
		"title_zh": "祭血邪坛", "title_en": "Blood Altar",
		"desc_zh": "幽暗的密林深处耸立着一座以黑曜石雕凿的祭坛，其上刻满了噬血符文。空气中弥漫着淡淡的血腥气，低沉的呢喃声在脑海中回荡。",
		"desc_en": "An ominous obsidian altar pulses in the shadows. Dark whispers promise immense power in exchange for life essence.",
		"choices": [
			{"label_zh": "割腕献血（失去 15 生命，获得 90 金币）", "label_en": "Blood Sacrifice (-15 HP, Gain 90 Gold)", "type": "damage_for_gold", "hp_cost": 15, "gold_amount": 90},
			{"label_zh": "破除邪坛（承受 6 点伤害，净化 1 张卡牌）", "label_en": "Shatter Altar (-6 HP, Purge 1 Card)", "type": "damage_and_purge", "hp_cost": 6},
			{"label_zh": "绕行避开", "label_en": "Walk Away", "type": "leave"}
		]
	},
	{
		"id": "alchemy_furnace", "icon": "♨️", "color": "ff9868",
		"title_zh": "残破丹炉", "title_en": "Ancient Crucible",
		"desc_zh": "一座丈高的青铜丹炉倾覆在废墟中，炉膛内余烬未熄，阵阵奇异的药香扑鼻而来。炉壁上似乎还残留着未成型的极品丹药。",
		"desc_en": "A bronze alchemy furnace rests among ruins. Embers still flicker within, radiating a warm, restorative scent.",
		"choices": [
			{"label_zh": "吸收药气（回复 18 点生命）", "label_en": "Inhale Vapor (Heal 18 HP)", "type": "heal", "heal_amount": 18},
			{"label_zh": "火中取栗（获得 50 金币，受到 8 点灼伤）", "label_en": "Reach Into Flame (Gain 50 Gold, -8 HP)", "type": "damage_for_gold", "hp_cost": 8, "gold_amount": 50},
			{"label_zh": "借火淬牌（强化 1 张卡牌）", "label_en": "Forge Card (Upgrade 1 Card)", "type": "upgrade"}
		]
	},
	{
		"id": "fox_spirit_shrine", "icon": "🦊", "color": "ffb765",
		"title_zh": "灵狐古祠", "title_en": "Fox Spirit Shrine",
		"desc_zh": "一座供奉九尾灵狐神祇的木制小祠，祠前供桌洁净，红烛摇曳。神龛中隐隐传来狐仙的温和呼唤，似乎在注视着同族的求道者。",
		"desc_en": "A delicate wooden shrine dedicated to the celestial nine-tailed fox. Warm candles flicker before a serene effigy.",
		"choices": [
			{"label_zh": "虔诚祈福（强化 1 张卡牌，并回复 10 生命）", "label_en": "Pray (Upgrade Card & Heal 10 HP)", "type": "upgrade_and_heal", "heal_amount": 10},
			{"label_zh": "献上供金（花费 25 金币，获得 1 件遗物）", "label_en": "Tithe 25 Gold (Gain Relic)", "type": "buy_relic", "gold_cost": 25},
			{"label_zh": "恭敬行礼离开", "label_en": "Bow and Leave", "type": "leave"}
		]
	},
	{
		"id": "shadow_gambler", "icon": "🎲", "color": "b9a2ff",
		"title_zh": "幽冥赌坊", "title_en": "Ghost Casino",
		"desc_zh": "黑雾中浮现出一张发光的石桌，一位头戴斗笠的幽冥客正在百无聊赖地抛掷着骨骰。他抬起头，露出一抹诡异的笑容：'道友，要来赌一把命数么？'",
		"desc_en": "A shadowy figure sits by a luminous stone table, tossing bone dice. 'Care to test your destiny, traveler?'",
		"choices": [
			{"label_zh": "下注豪赌（花费 30 金币，50% 获 80 金币，50% 颗粒无收）", "label_en": "Roll Dice (30 Gold: 50% Win 80 Gold)", "type": "gamble", "gold_cost": 30, "win_gold": 80},
			{"label_zh": "讨价还价（用 10 点生命换取 50 金币）", "label_en": "Trade Vitality (-10 HP, Gain 50 Gold)", "type": "damage_for_gold", "hp_cost": 10, "gold_amount": 50},
			{"label_zh": "摇头不赌", "label_en": "Decline", "type": "leave"}
		]
	},
	{
		"id": "spirit_tree", "icon": "🌳", "color": "8ff5cf",
		"title_zh": "通天神木", "title_en": "Spirit Arbor",
		"desc_zh": "一棵遮天蔽日的参天古树傲立在天地之间，每一片碧绿的树叶都在吞吐着纯净的日月精华。树枝上结着数颗青翠欲滴的灵果。",
		"desc_en": "A colossal arbor pierces the clouds. Every emerald leaf breathes cosmic vitality, bearing luminescent spiritual fruits.",
		"choices": [
			{"label_zh": "采摘灵果（恢复全部已损生命的 50%）", "label_en": "Eat Fruit (Heal 25 HP)", "type": "heal", "heal_amount": 25},
			{"label_zh": "折取神枝（从牌组移除 1 张卡牌）", "label_en": "Break Branch (Purge 1 Card)", "type": "purge"},
			{"label_zh": "席地悟道（获得 40 金币）", "label_en": "Meditate (Gain 40 Gold)", "type": "gold", "gold_amount": 40}
		]
	},
	{
		"id": "meteor_crater", "icon": "☄️", "color": "c9a6ff",
		"title_zh": "陨星天坑", "title_en": "Meteor Crater",
		"desc_zh": "地面裂开巨大的焦黑巨坑，天坑中央沉睡着一颗散发着冰冷星辉的天外陨铁，周围环绕着扭曲空间的狂乱引力波。",
		"desc_en": "A smoldering crater cradles fallen celestial meteoric iron, distorting gravity and humming with cosmic power.",
		"choices": [
			{"label_zh": "强取陨星核（承受 14 点伤害，获得 1 件遗物）", "label_en": "Seize Meteor Core (-14 HP, Gain Relic)", "type": "damage_for_relic", "hp_cost": 14},
			{"label_zh": "采集星尘（获得 55 金币）", "label_en": "Gather Stardust (Gain 55 Gold)", "type": "gold", "gold_amount": 55},
			{"label_zh": "退避三舍", "label_en": "Step Back", "type": "leave"}
		]
	},
	{
		"id": "lost_traveler", "icon": "🧳", "color": "fff59d",
		"title_zh": "迷途行商", "title_en": "Lost Peddler",
		"desc_zh": "一名背着巨大行囊的游方行商正对着残缺的地图愁眉苦脸。见到你走来，他如释重负：'多谢仙长！若能为小人指明出山路径，必有重谢！'",
		"desc_en": "A peddler with an enormous pack sighs over a ruined map. 'Noble traveler, guide me through this labyrinth!'",
		"choices": [
			{"label_zh": "指点迷津（获得 50 金币报酬）", "label_en": "Guide Way (Gain 50 Gold)", "type": "gold", "gold_amount": 50},
			{"label_zh": "分享补给（失去 20 金币，获得 1 件遗物）", "label_en": "Share Supplies (Pay 20 Gold, Gain Relic)", "type": "buy_relic", "gold_cost": 20},
			{"label_zh": "互道安好离开", "label_en": "Farewell", "type": "leave"}
		]
	},
	{
		"id": "phantom_duel", "icon": "🪞", "color": "e1bee7",
		"title_zh": "心魔古镜", "title_en": "Mirror of Shadows",
		"desc_zh": "半空中悬浮着一面水银凝固般的平光宝镜，镜中映出的倒影不仅没有你的面容，反而狞笑着拔出利刃，向你的神识刺来！",
		"desc_en": "A mercurial mirror floats in midair. Your reflection grins sinisterly and strikes at your conscious mind.",
		"choices": [
			{"label_zh": "斩破心魔（受到 8 点精神冲击，强化 1 张卡牌）", "label_en": "Conquer Shadow (-8 HP, Upgrade 1 Card)", "type": "damage_and_upgrade", "hp_cost": 8},
			{"label_zh": "碎镜求生（获得 45 金币）", "label_en": "Shatter Mirror (Gain 45 Gold)", "type": "gold", "gold_amount": 45},
			{"label_zh": "紧闭心神后退", "label_en": "Close Mind and Leave", "type": "leave"}
		]
	},
	{
		"id": "monk_meditation", "icon": "🧘", "color": "d4a373",
		"title_zh": "禅林僧庐", "title_en": "Zen Hermitage",
		"desc_zh": "山崖松柏间隐约露出一座枯木草堂，一缕檀香徐徐升起。一位老僧端坐蒲团，闭目合十：'施主风尘仆仆，何不歇息片刻？'",
		"desc_en": "A quiet thatched cottage nestled in pine trees. An elderly monk offers serene shelter from the arduous path.",
		"choices": [
			{"label_zh": "静心歇息（恢复 24 点生命值）", "label_en": "Rest (Heal 24 HP)", "type": "heal", "heal_amount": 24},
			{"label_zh": "断舍离执念（净化移除 1 张卡牌）", "label_en": "Let Go (Purge 1 Card)", "type": "purge"},
			{"label_zh": "合十礼毕离去", "label_en": "Depart Peacefully", "type": "leave"}
		]
	},
	{
		"id": "beast_carcass", "icon": "🦴", "color": "aed581",
		"title_zh": "远古巨兽遗骸", "title_en": "Beast Carcass",
		"desc_zh": "山谷中横陈着一具长达数十丈的上古蛮兽骸骨，骨节晶莹剔透，胸腔内似乎还封存着未曾散尽的狂暴兽核。",
		"desc_en": "The petrified skeleton of a primordial titan lies in the valley. A crystalline core still hums inside its ribs.",
		"choices": [
			{"label_zh": "硬取兽核（获得 70 金币，受到 11 点反震伤害）", "label_en": "Extract Core (Gain 70 Gold, -11 HP)", "type": "damage_for_gold", "hp_cost": 11, "gold_amount": 70},
			{"label_zh": "采集骨粉（强化 1 张卡牌）", "label_en": "Grind Bones (Upgrade 1 Card)", "type": "upgrade"},
			{"label_zh": "敬畏避让", "label_en": "Leave", "type": "leave"}
		]
	},
	{
		"id": "abandoned_mine", "icon": "⛏️", "color": "ffd54f",
		"title_zh": "废弃灵矿", "title_en": "Abandoned Mine",
		"desc_zh": "深邃的灵矿坑道入口散落着数辆生锈的矿车，岩壁深处依稀闪烁着未开采完的灵石光泽，但隐约传来妖兽的低吼。",
		"desc_en": "An overgrown spirit mine opening. Uncut gemstone veins glint deep in the shafts alongside distant beast growls.",
		"choices": [
			{"label_zh": "冒险深采（获得 80 金币，受到 12 点塌方伤害）", "label_en": "Deep Mining (Gain 80 Gold, -12 HP)", "type": "damage_for_gold", "hp_cost": 12, "gold_amount": 80},
			{"label_zh": "外围捡拾（安全获得 35 金币）", "label_en": "Safe Scavenge (Gain 35 Gold)", "type": "gold", "gold_amount": 35},
			{"label_zh": "离开矿洞", "label_en": "Leave", "type": "leave"}
		]
	},
	{
		"id": "celestial_chess", "icon": "♟️", "color": "90a4ae",
		"title_zh": "残局仙弈", "title_en": "Celestial Chess",
		"desc_zh": "青石棋盘上黑白棋子布列玄奥，天元之位空悬。棋局散发出古老悠远的推演法则，仿佛在等待一位有缘人落子破局。",
		"desc_en": "A celestial Weiqi board carved from mountain granite. The unresolved game radiates deep cosmic harmony.",
		"choices": [
			{"label_zh": "落子定乾坤（扣除 10 生命，获得 1 件遗物）", "label_en": "Place Stone (-10 HP, Gain 1 Relic)", "type": "damage_for_relic", "hp_cost": 10},
			{"label_zh": "复盘观局（强化 1 张卡牌）", "label_en": "Observe Strategy (Upgrade 1 Card)", "type": "upgrade"},
			{"label_zh": "拱手作别", "label_en": "Leave", "type": "leave"}
		]
	},
	{
		"id": "poison_swamp", "icon": "🍄", "color": "9b59b6",
		"title_zh": "幽腐毒沼", "title_en": "Putrid Mire",
		"desc_zh": "泥沼中咕嘟冒泡，散发着甜腻而危险的腐臭。几株极其罕见的七彩毒灵芝在烂木上静静绽放，价值连城却剧毒无比。",
		"desc_en": "Bubbling violet bogs emit sweet, perilous vapors. Rare rainbow death-mushrooms blossom atop decaying roots.",
		"choices": [
			{"label_zh": "采摘毒菇（获得 65 金币，受到 9 点腐蚀伤害）", "label_en": "Harvest Shroom (Gain 65 Gold, -9 HP)", "type": "damage_for_gold", "hp_cost": 9, "gold_amount": 65},
			{"label_zh": "以毒攻毒（从牌组移除 1 张卡牌）", "label_en": "Purge Venom (Purge 1 Card)", "type": "purge"},
			{"label_zh": "屏息疾行离开", "label_en": "Hasten Past", "type": "leave"}
		]
	},
	{
		"id": "reincarnation_well", "icon": "🌀", "color": "80cbc4",
		"title_zh": "轮回残碑", "title_en": "Pillar of Rebirth",
		"desc_zh": "断裂的黑玉石碑孤零零矗立在阴阳交界处。碑文记载着上古轮回法门，抚摸石碑能让你窥见几世前斩断宿命的因果。",
		"desc_en": "A fractured black jade stele rests on the threshold of life and death, whispering ancient laws of karmic rebirth.",
		"choices": [
			{"label_zh": "铭刻宿命（失去 8 生命，从牌组移除 1 张卡牌）", "label_en": "Inscribe Fate (-8 HP, Purge 1 Card)", "type": "damage_and_purge", "hp_cost": 8},
			{"label_zh": "勘破前尘（恢复 20 点生命值）", "label_en": "Enlightenment (Heal 20 HP)", "type": "heal", "heal_amount": 20},
			{"label_zh": "默默离开", "label_en": "Walk Away", "type": "leave"}
		]
	},
	{
		"id": "ruined_library", "icon": "📖", "color": "ffcc80",
		"title_zh": "倾塌藏经阁", "title_en": "Ruined Archive",
		"desc_zh": "昔日仙门的藏经重地如今已大半沉入地脉，金丝玉简散落一地。翻阅这些残卷，或许能寻得失传已久的秘术真传。",
		"desc_en": "A half-sunken repository of ancient doctrines. Golden bamboo scrolls litter the dust, holding forgotten arts.",
		"choices": [
			{"label_zh": "精研残经（强化 1 张卡牌）", "label_en": "Study Scroll (Upgrade 1 Card)", "type": "upgrade"},
			{"label_zh": "拾取残卷（获得 45 金币）", "label_en": "Scavenge Texts (Gain 45 Gold)", "type": "gold", "gold_amount": 45},
			{"label_zh": "不予打扰离开", "label_en": "Leave", "type": "leave"}
		]
	},
	{
		"id": "celestial_merchant", "icon": "💎", "color": "ff4081",
		"title_zh": "太虚幻商", "title_en": "Void Smuggler",
		"desc_zh": "一扇虚空裂隙悄然在面前展开，一名浑身裹在星屑斗篷下的商人探出身来：'来自异界的道友，我这里有凡间难得一见的奇珍异宝……'",
		"desc_en": "A rift opens in reality. A smuggler cloaked in starlight emerges, offering wonders beyond mundane realms.",
		"choices": [
			{"label_zh": "倾囊求购（花费 40 金币，获得 1 件遗物）", "label_en": "Purchase Relic (40 Gold: Gain Relic)", "type": "buy_relic", "gold_cost": 40},
			{"label_zh": "出售秘宝（从牌组移除 1 张牌，获得 35 金币）", "label_en": "Sell Card (Purge 1 Card, Gain 35 Gold)", "type": "purge_for_gold", "gold_amount": 35},
			{"label_zh": "拒绝交易离开", "label_en": "Decline", "type": "leave"}
		]
	}
]

func random_story_event(stage_index: int, seed_val: int = 0) -> Dictionary:
	var idx: int = abs(stage_index * 7 + seed_val * 13) % RANDOM_STORY_EVENTS.size()
	return RANDOM_STORY_EVENTS[idx]

# Phase 9 — World Events: a rotating 4-week thematic event, computed purely from a `period`
# integer (game.gd's _ensure_world_event_current() is the one place that turns wall-clock time
# into that integer — see its own comment for why, mirroring daily_trial_tags()'s own
# seed-in/pure-function-out shape so this can be tested at any period without mocking the
# clock). Each event's `modifier` dict is built entirely from combat.gd keys already wired and
# tested by Daily Trial/Boss Rush/Curse Run — no new engine surface for this phase at all.
const WORLD_EVENTS: Array[Dictionary] = [
	{"id":"ember_lord","nameKey":"event.ember_lord.name","descKey":"event.ember_lord.desc","color":"ff6b3d","art":"embercliff","modifier":{"damage_bonus":4}},
	{"id":"frost_widow","nameKey":"event.frost_widow.name","descKey":"event.frost_widow.desc","color":"6ee3ff","art":"runebound","modifier":{"extra_enemy":1}},
	{"id":"withered_king","nameKey":"event.withered_king.name","descKey":"event.withered_king.desc","color":"8a7a5a","art":"sentinel","modifier":{"no_heal":true,"health_scale":1.3}},
	{"id":"storm_judge","nameKey":"event.storm_judge.name","descKey":"event.storm_judge.desc","color":"c9a6ff","art":"fox","modifier":{"damage_mult":1.4}},
]

func world_event_for_period(period: int) -> Dictionary:
	var idx: int = ((period % WORLD_EVENTS.size()) + WORLD_EVENTS.size()) % WORLD_EVENTS.size()
	return WORLD_EVENTS[idx]

func world_event_encounter(period: int, unlocked: int) -> Dictionary:
	var ev: Dictionary = world_event_for_period(period)
	var effective_stage := clampi(unlocked, 1, 250)
	return {
		"chapter": 103, "level": effective_stage,
		"health": 40 + effective_stage * 13,
		"damage": 7 + int(effective_stage * 1.6),
		"reward": 45 + effective_stage * 5,
		"name": ui(str(ev.nameKey), "zh-Hans"), "name_en": ui(str(ev.nameKey), "en"), "art": str(ev.art),
		"mechanics": {},
		"adds": 0,
		"background": 3
	}

# Battle screen's modifier badge reads name/name_en/detail/detail_en unconditionally — same
# requirement content.daily_trial_modifier() already documents at its own definition.
func world_event_modifier(period: int) -> Dictionary:
	var ev: Dictionary = world_event_for_period(period)
	var mod: Dictionary = ev.get("modifier", {}).duplicate(true)
	mod["name"] = ui(str(ev.nameKey), "zh-Hans")
	mod["name_en"] = ui(str(ev.nameKey), "en")
	mod["detail"] = ui(str(ev.descKey), "zh-Hans")
	mod["detail_en"] = ui(str(ev.descKey), "en")
	return mod

func hero_class(id: String) -> Dictionary:
	for h in HERO_CLASSES:
		if h.id == id: return h
	return HERO_CLASSES[0]

func hero_name(h: Dictionary, language := "zh-Hans") -> String:
	return str(h.get("name_en" if language == "en" else "name", h.get("id", "")))

func hero_desc(h: Dictionary, language := "zh-Hans") -> String:
	return str(h.get("desc_en" if language == "en" else "desc", ""))

func seven_day_journey() -> Array:
	return SEVEN_DAY_JOURNEY

func seven_day_journey_day(day: int) -> Dictionary:
	for entry in SEVEN_DAY_JOURNEY:
		if int(entry.get("day", 0)) == day:
			return entry
	return {}

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

# E4 "async ghost battle": combat.gd only models deck-vs-encounter (see AGENTS.md — no PvP
# engine exists here, and building one would be a far bigger lift than this feature needs), so
# a duel against another player's real recorded run reuses the same "opponent as a flavor
# Encounter" shape Phantom Arena already established with its 4 fixed PHANTOM_CULTIVATORS —
# just with identity and strength sourced from a real submitted leaderboard row (game_camp_
# screen.gd's show_leaderboard()) instead of fixed NPC data. No new backend table needed either:
# player_name/character_id/category/score already round-trip through the existing public.
# leaderboards table (see SupabaseClient.fetch_leaderboard()), which is everything this needs.
# health/damage reuse abyss_encounter()'s own tuned curve (already validated by
# balance_probe.gd) parameterized by a normalized "level" from _ghost_difficulty_level() below,
# so a ghost recorded at real floor 40 hits about as hard as floor 40 actually does — this is
# deliberately an approximation of "how strong was this run," not a move-by-move replay of it.
func ghost_arena_encounter(ghost_name: String, ghost_char_id: String, category: String, score: int) -> Dictionary:
	var level: int = clampi(_ghost_difficulty_level(category, score), 1, 250)
	var enc: Dictionary = abyss_encounter(level)
	enc.chapter = 103
	# A real player's submitted name has no localized counterpart the way system-authored
	# flavor text (PHANTOM_CULTIVATORS etc.) does, so it's shown as-is regardless of language.
	enc.name = ghost_name
	enc.name_en = ghost_name
	enc.art = ghost_char_id
	return enc

# Every leaderboard category encodes score differently (see the _submit_*_record() call sites
# in game.gd) — this doesn't attempt an exact decode, since the goal is only "roughly as strong
# as the real thing," not reconstructing the original run.
func _ghost_difficulty_level(category: String, score: int) -> int:
	match category:
		"abyss": return score
		"daily_trial": return int(score / 100.0)
		"samsara": return score * 5
		_: return score

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

func relic_resonance(id: String) -> Dictionary:
	for item in RELIC_RESONANCES:
		if item.id == id: return item
	return {}

func active_relic_resonances(relic_ids: Array) -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for res in RELIC_RESONANCES:
		var req: Array = res.get("relics", [])
		var has_all := true
		for r_id in req:
			if not relic_ids.has(r_id):
				has_all = false
				break
		if has_all:
			active.append(res)
	return active

func relic_resonance_name(res: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return res.get("en", res.get("zh", ""))
	return res.get("zh", "")

func relic_resonance_detail(res: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return res.get("detail_en", res.get("detail", ""))
	return res.get("detail", "")

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
# Tuned against tests/balance_probe.gd (run: ./run_tests.sh --balance) — see
# Docs/ARCHITECTURE.md for the win-rate curve that came out of it and why these constants
# ended up where they did. Band 3's 0.16 (was 0.22 until the 2026-09-17 revalidation) is the
# fixed value — see that section and test_runner.gd's own pinning assertion for what the old
# value broke.
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
# Samsara (轮回): each samsara cycle raises the max selectable tier by one, uncapped (see
# _samsara_section()'s "5 + samsara_count" eligibility, game_camp_screen.gd), so the escalating
# tier ladder is now an actual escalating challenge ladder, not a cosmetic one, and Samsara has
# somewhere real to send a player who has run out of harder content otherwise — every cycle
# raises the bar again rather than a flat, one-time A6 ceiling.
# Tier 0 (A0) is deliberately a no-op: tests/balance_probe.gd's revalidation (see
# Docs/ARCHITECTURE.md) validated the base curve at zero extra scaling, and every existing
# save already defaults to difficulty 0 — this must never retroactively make the validated
# baseline harder.
func difficulty_modifier(tier: int) -> Dictionary:
	if tier <= 0: return {}
	var hp_pct: int = int(round(float(tier) * 12.0))
	var gold_pct: int = int(round(float(tier) * 10.0))
	var mod: Dictionary = {
		"health_scale": 1.0 + float(tier) * 0.12, "damage_bonus": tier, "reward_scale": 1.0 + float(tier) * 0.1,
		"name": "挑战等级 A%d" % tier, "name_en": "Challenge Tier A%d" % tier,
		"tier": tier
	}
	var details: Array[String] = ["生命+%d%% 伤害+%d 金币+%d%%" % [hp_pct, tier, gold_pct]]
	var details_en: Array[String] = ["HP+%d%% DMG+%d Gold+%d%%" % [hp_pct, tier, gold_pct]]
	if tier >= 1:
		mod["elite_shield_start"] = 10
		details.append("精英开场+10护盾")
		details_en.append("Elites start with +10 Shield")
	if tier >= 2:
		mod["enemy_opening_shield"] = 5
		details.append("敌人初始+5护盾")
		details_en.append("Enemies gain +5 initial Shield")
	if tier >= 3:
		mod["draw_penalty"] = 1
		details.append("回合抽牌-1(下限1)")
		details_en.append("-1 Draw per turn (min 1)")
	if tier >= 4:
		mod["inflict_debuffs"] = true
		details.append("敌攻附带虚弱/易伤")
		details_en.append("Enemy hits apply Weak/Vulnerable")
	if tier >= 5:
		mod["boss_enrage_boost"] = 3
		details.append("首领狂怒攻击力额外+3")
		details_en.append("Bosses gain +3 Enrage damage")

	mod["detail"] = " · ".join(details)
	mod["detail_en"] = " · ".join(details_en)
	return mod

# Each tier from A1 up used to become selectable the instant _difficulty_tier_section()'s own
# overall gate (unlocked>=25) opened — all the way to A5 at once, +60% enemy HP and +5 flat
# damage per difficulty_modifier() above, with zero guardrail for a player only 25 stages in.
# Progressive per-tier unlocking instead: A0 is always available (see difficulty_modifier()'s
# own comment on why it's a no-op), and A1's threshold matches the section's own existing
# unlocked>=25 gate exactly, so a first-time unlock still happens at the same moment as before —
# only A2 and up are new gates. Tiers past A5 (Samsara's escalating ceiling) are governed
# entirely by _difficulty_tier_section()'s own "5 + samsara_count" mechanism in
# game_camp_screen.gd, not this table — reaching those already requires a full 250-stage clear,
# a much stronger gate than any stage threshold here could add.
const DIFFICULTY_TIER_UNLOCK_STAGE: Array[int] = [0, 25, 50, 100, 150, 200]

func difficulty_tier_unlock_stage(tier: int) -> int:
	if tier < DIFFICULTY_TIER_UNLOCK_STAGE.size(): return DIFFICULTY_TIER_UNLOCK_STAGE[tier]
	return DIFFICULTY_TIER_UNLOCK_STAGE[DIFFICULTY_TIER_UNLOCK_STAGE.size() - 1]

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

func _get_encounter_enemy(chapter: int, level: int) -> Dictionary:
	var stage_idx: int = (chapter - 1) * 5 + (level - 1)
	if stage_idx >= 0 and stage_idx < ENEMIES.size():
		return ENEMIES[stage_idx]
	return ENEMIES[0]

func _build_encounters() -> void:
	var chapter_count: int = CHAPTER_NAMES_ZH.size()
	for index in chapter_count * 5:
		var chapter: int = index / 5 + 1
		var level := index % 5 + 1
		var enemy: Dictionary = _get_encounter_enemy(chapter, level)
		var is_great_boss: bool = level == 5 and chapter % 10 == 0
		var mechanics := _chapter_mechanics(chapter, is_great_boss)
		# Per-enemy authored mechanics (see the `mechanics` dicts on the ten boss ENEMIES
		# entries: m_s025/050/075/100/125/150/175/200/225/250) are merged *on top of* the
		# chapter band's generic set, so the band still supplies shield/crit/enrage scaling
		# while the boss's own signature keys win where they overlap.
		#
		# This merge is the whole difference between "authored a boss mechanic" and "shipped
		# one": combat.gd reads mechanics off the *encounter* dict, and before this line the
		# encounter only ever carried _chapter_mechanics(). Every key an author added to
		# ENEMIES would have parsed, type-checked, and then silently never been read at
		# runtime — the same silent-no-op shape as a mechanic key nothing consults.
		var authored: Dictionary = enemy.get("mechanics", {})
		for key in authored:
			mechanics[key] = authored[key]
		# Every chapter boss also gets its signature set (boss_mechanics_for). Filled in only
		# where neither the chapter band nor the ENEMIES row already set the key, so an authored
		# boss keeps its written-up identity and the band's scaling is never overwritten — this
		# adds the remaining forty chapters' identities without changing the ten authored ones.
		if level == 5:
			var signature: Dictionary = boss_mechanics_for(chapter)
			for key in signature:
				if not mechanics.has(key): mechanics[key] = signature[key]
		var adds := _chapter_adds(chapter, level, is_great_boss)
		var factor: float = _chapter_factor(chapter)
		var level_health: float = 1.0 + float(level - 1) * 0.12
		var level_damage: float = 1.0 + float(level - 1) * 0.10
		
		# Each chapter has its designated minion name & art for adds:
		var minion_stage_idx: int = (chapter - 1) * 5
		var chapter_minion: Dictionary = ENEMIES[minion_stage_idx] if minion_stage_idx < ENEMIES.size() else enemy
		var add_art_key: String = str(chapter_minion.get("art_key", "m_s%03d" % (minion_stage_idx + 1)))
		var add_name: String = str(chapter_minion.get("name", "灵迹随从"))
		var add_name_en: String = str(chapter_minion.get("name_en", "Spirit Minion"))
		
		encounters.append({
			"chapter":chapter,"level":level,
			"health":maxi(6, int(round(28.0 * factor * level_health))),
			"damage":maxi(2, int(round(4.0 * factor * level_damage))),
			"reward":int(round(16.0 + float(chapter) * 5.0 + float(level) * 2.0 + factor * 4.0)),
			"name":enemy.name,"name_en":enemy.get("name_en", enemy.name),"art":enemy.art,
			"art_key":enemy.get("art_key", enemy.art),"element":enemy.get("element", "wood"),
			"tier":enemy.get("tier", 1),"tint":enemy.get("tint", "83e4c1"),
			"lore":enemy.get("lore", ""),"lore_en":enemy.get("lore_en", ""),
			"mechanics":mechanics,"adds":adds,"background":(chapter - 1) % 5,
			# This flag is what makes the five great-boss phase-2 ultimates in combat.gd
			# (_trigger_great_boss_phase_2) reachable at all. It was read in exactly two places
			# and written in none: combat.gd copies it off the encounter dict into
			# state.is_great_boss, so with the field absent the flag was always false and the
			# chapter 10/20/30/40/50 ultimates could never fire on any code path. The map kind
			# ("greatboss") and the reward/achievement paths were already keyed off node_kind()
			# instead, which is why the gap stayed invisible — the label was right everywhere
			# the player could see it.
			"is_great_boss":is_great_boss,
			"add_art_key":add_art_key,"add_name":add_name,"add_name_en":add_name_en
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
	"ui.relic_resonance_title": {"zh-Hans":"法宝共鸣", "en":"Relic Resonance"},
	"ui.relic_resonance_active": {"zh-Hans":"已激活共鸣", "en":"Active Resonances"},
	"ui.relic_resonance_codex": {"zh-Hans":"法宝共鸣谱", "en":"Resonance Codex"},
	"ui.relic_resonance_none": {"zh-Hans":"暂未激活法宝共鸣", "en":"No active resonances"},
	"ui.relic_resonance_req": {"zh-Hans":"共鸣法宝：%s", "en":"Resonance Relics: %s"},
	"ui.relic_resonance_activated_toast": {"zh-Hans":"⚡ 激活共鸣：%s！", "en":"⚡ Resonance Activated: %s!"},
	"ui.camp_desc": {"zh-Hans":"更高挑战提高敌人生命与伤害；Boss装备奖励会轮换。", "en":"Higher tiers boost enemy HP & ATK; Boss equipment rotates."},
	"ui.camp_tier_samsara_unlocked": {"zh-Hans":"轮回已解锁至 A%d", "en":"Samsara has unlocked up to A%d"},
	"ui.samsara_locked_desc": {"zh-Hans":"通关全部250关，并将挑战等级设为A%d后解锁", "en":"Clear all 250 stages with Challenge Tier set to A%d to unlock"},
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
	"ui.shop_next_price": {"zh-Hans":"下一张", "en":"Next copy"},
	"ui.shop_gold": {"zh-Hans":"◆ %d", "en":"◆ %d"},
	# Confirmation gates. Reported bug: a single tap in the shop bought or recycled outright, with
	# no undo — see ShopDeckScreen._confirm_shop_action().
	"ui.confirm_ok": {"zh-Hans":"确认", "en":"Confirm"},
	"ui.confirm_cancel": {"zh-Hans":"取消", "en":"Cancel"},
	"ui.shop_confirm_card_title": {"zh-Hans":"确认购买这张卡牌？", "en":"Buy this card?"},
	"ui.shop_confirm_relic_title": {"zh-Hans":"确认购买这件遗物？", "en":"Buy this relic?"},
	"ui.shop_confirm_rune_title": {"zh-Hans":"确认购买这枚符文？", "en":"Buy this rune?"},
	"ui.shop_confirm_item_title": {"zh-Hans":"确认购买这件物品？", "en":"Buy this item?"},
	"ui.shop_confirm_pack_title": {"zh-Hans":"确认开启秘袋？", "en":"Open this pack?"},
	"ui.shop_pack_desc": {"zh-Hans":"随机获得 3 张非初始卡牌，其中至少 1 张为精良或更高品质。", "en":"3 random non-starter cards, at least one Uncommon or better."},
	"ui.shop_confirm_recycle_title": {"zh-Hans":"确认分解？", "en":"Recycle this card?"},
	"ui.shop_confirm_recycle_body": {"zh-Hans":"将永久失去 1 张此卡牌，此操作无法撤销。", "en":"This permanently removes 1 copy and cannot be undone."},
	"ui.shop_confirm_craft_title": {"zh-Hans":"确认凝聚这张卡牌？", "en":"Forge this card?"},
	"ui.shop_confirm_pay_prefix": {"zh-Hans":"将扣除", "en":"Will charge"},
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
	"desc.special.samadhi_burst": {"zh-Hans":"引爆并翻倍目标灼烧层数", "en":"Detonates & doubles enemy Burn"},
	"desc.special.spirit_surge": {"zh-Hans":"本回合每出牌抽1张并得2护盾", "en":"Rest of turn: plays draw 1 & gain 2 Shield"},
	"desc.special.shield_slam": {"zh-Hans":"造成相当于当前护盾100%破甲伤害", "en":"Deal pierce damage equal to 100% current Shield"},
	"desc.special.bastion_form": {"zh-Hans":"回合结束至多保留35点护盾", "en":"Retain up to 35 Shield between turns"},
	"desc.special.thousand_blades": {"zh-Hans":"手中每保留1张牌追加4点伤害", "en":"Deals 4 bonus damage per card in hand"},
	"desc.special.shadow_clone": {"zh-Hans":"下张攻击或法术连续触发两次", "en":"Next attack or skill casts twice"},
	"desc.special.catalyst_poison": {"zh-Hans":"使目标的中毒层数翻倍(×2)", "en":"Multiplies target Poison stacks by 2"},
	"desc.special.blood_pact": {"zh-Hans":"扣减5生命：获得2能量并抽3张牌", "en":"Lose 5 HP: gain 2 Energy & draw 3 cards"},
	"ui.reward_skip": {"zh-Hans":"放弃奖励", "en":"Skip Reward"},
	"ui.card_purged_toast": {"zh-Hans":"已从卡组永久移出【%s】", "en":"Permanently removed %s from deck"},
	"ui.deck_too_small": {"zh-Hans":"道心不可空，卡组至少保留12张卡牌", "en":"Deck must contain at least 12 cards"},
	"ui.upgrade_branch_flow": {"zh-Hans":"灵变 (-1能耗)", "en":"Flow (-1 Cost)"},
	"ui.upgrade_branch_surge": {"zh-Hans":"极变 (+3效能)", "en":"Surge (+3 Power)"},
	"ui.upgrade_branch_chosen": {"zh-Hans":"【%s】进阶为【%s】", "en":"%s upgraded to %s"},
	"desc.boomerang": {"zh-Hans":"回旋，回到手牌", "en":"Boomerang: returns to hand"},
	"desc.reverb": {"zh-Hans":"余韵，下回合免费重施", "en":"Reverb: free recast next turn"},
	"desc.overload": {"zh-Hans":"过载%d，下回合能量减少", "en":"Overload %d: next turn's energy is reduced"},
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
	"kw.boomerang": {"zh-Hans":"回旋：打出后不会进入弃牌堆，而是在下回合开始时飞回手牌。", "en":"Boomerang: Instead of going to the discard pile, returns to your hand at the start of next turn."},
	"kw.reverb": {"zh-Hans":"余韵：打出时会在下回合开始时免费再施放一次完整效果。", "en":"Reverb: Queues a free full-power recast of this card's effect for the start of next turn."},
	"kw.overload": {"zh-Hans":"过载：立即产生强力效果，但会削减下回合的能量上限(最低降至1点)。", "en":"Overload: An immediate burst effect that reduces next turn's energy cap (floored at 1)."},
	"ui.rest_title": {"zh-Hans":"灵火营地", "en":"Spirit Campfire"},
	"ui.bonus_title": {"zh-Hans":"额外馈赠", "en":"Bonus Boon"},
	"ui.bonus_prompt": {"zh-Hans":"你舍弃了休憩，换取了更丰厚的回报。", "en":"You forsook rest and claimed a richer prize."},
	"ui.bonus_gold_choice": {"zh-Hans":"厚赐 · 获得 ◆60 灵石", "en":"Rich Boon · Gain ◆60 Gold"},
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
	"ui.compendium_tab_codex": {"zh-Hans":"典籍", "en":"Codex"},
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
	"tutorial.3.desc": {"zh-Hans":'没有"结束回合"按钮：当手牌打不动（能量不够或没牌了），回合会自动结束，进入敌人的行动。想提前结束回合时，也可以点"空过"。', "en":"There's no End Turn button: once nothing left in hand is affordable, the turn ends itself and the enemy acts. To end a turn early, tap Pass."},
	"tutorial.4.title": {"zh-Hans":"战报与成长", "en":"Rewards & Growth"},
	"tutorial.4.desc": {"zh-Hans":"获胜后可以选择带走一张新卡加入牌组。营地里还有装备、符文、专精与每日试炼——一步步来，先打赢眼前这一场。", "en":"Winning lets you add a new card to your deck. Camp holds equipment, runes, mastery and the Daily Trial — for now, just win the fight in front of you."},
	"ui.login_reward_title": {"zh-Hans":"本周登录", "en":"This Week's Visits"},
	"ui.login_reward_progress_fmt": {"zh-Hans":"已登录 %d/7 天", "en":"Logged in %d/7 days"},
	"ui.login_reward_tier_fmt": {"zh-Hans":"登录满 %d 天", "en":"Log in %d days"},
	"ui.login_reward_claimed_toast": {"zh-Hans":"登录奖励 +%d 金币", "en":"Login reward +%d gold"},
	"ui.compendium_tab_achievements": {"zh-Hans":"成就", "en":"Achievements"},
	"ui.compendium_tab_chronicle": {"zh-Hans":"编年史", "en":"Chronicle"},
	"ui.chronicle_locked": {"zh-Hans":"尚未抵达", "en":"Not yet reached"},
	"ui.compendium_tab_career": {"zh-Hans":"典籍", "en":"Codex"},
	"ui.career_overview_title": {"zh-Hans":"战绩概要", "en":"Lifetime Overview"},
	"ui.career_style_title": {"zh-Hans":"战斗风格", "en":"Combat Style"},
	"ui.career_hof_title": {"zh-Hans":"常胜卡组", "en":"Hall of Fame"},
	"ui.career_total_battles_fmt": {"zh-Hans":"总战斗次数：%d", "en":"Total Battles: %d"},
	"ui.career_win_rate_fmt": {"zh-Hans":"胜率：%d%%", "en":"Win Rate: %d%%"},
	"ui.career_longest_streak_fmt": {"zh-Hans":"最长连胜：%d", "en":"Longest Win Streak: %d"},
	"ui.career_abyss_floor_fmt": {"zh-Hans":"深渊最高层数：%d", "en":"Highest Abyss Floor: %d"},
	"ui.career_total_damage_fmt": {"zh-Hans":"造成总伤害：%d", "en":"Total Damage Dealt: %d"},
	"ui.career_cards_played_fmt": {"zh-Hans":"总出牌数：%d", "en":"Total Cards Played: %d"},
	"ui.career_shield_gained_fmt": {"zh-Hans":"获得总护盾：%d", "en":"Total Shield Gained: %d"},
	"ui.career_favorite_hero_fmt": {"zh-Hans":"最常用英雄：%s（%d 胜）", "en":"Favorite Hero: %s (%d wins)"},
	"ui.career_favorite_card_fmt": {"zh-Hans":"最爱卡牌：%s（出牌 %d 次）", "en":"Favorite Card: %s (played %d times)"},
	"ui.career_hof_entry_fmt": {"zh-Hans":"第%d章 · %s · 第%d回合 · %d件遗物", "en":"Chapter %d · %s · Turn %d · %d relics"},
	"ui.career_hof_empty": {"zh-Hans":"尚未击败任何大首领", "en":"No Great Boss victories yet"},
	"ui.camp_tab_character": {"zh-Hans":"角色", "en":"Character"},
	"ui.camp_tab_challenges": {"zh-Hans":"挑战", "en":"Challenges"},
	"ui.camp_tab_collection": {"zh-Hans":"收藏", "en":"Collection"},
	"ui.challenges_title": {"zh-Hans":"试炼挑战", "en":"Trial Challenges"},
	"ui.challenges_sub": {"zh-Hans":"每日试炼 · 每周挑战 · 无尽深渊 · 难度调控", "en":"Daily Trial · Weekly · Abyss · Difficulty"},
	"ui.challenges_group_daily": {"zh-Hans":"每日与每周", "en":"Daily & Weekly"},
	"ui.challenges_group_competitive": {"zh-Hans":"竞技与好友", "en":"Competitive & Friends"},
	"ui.challenges_group_endgame": {"zh-Hans":"终局试炼", "en":"Endgame Trials"},
	"ui.challenges_group_practice": {"zh-Hans":"练习与调控", "en":"Practice & Tuning"},
	"ui.achievement_unlocked_toast": {"zh-Hans":"✦ 成就解锁：%s", "en":"✦ Achievement Unlocked: %s"},
	"ui.achievement_locked": {"zh-Hans":"未解锁", "en":"Locked"},
	"ui.unlock_shop_title": {"zh-Hans":"✦ 灵界商肆开启 ✦", "en":"✦ Spirit Shop Unlocked ✦"},
	"ui.unlock_shop_desc": {"zh-Hans":"云游商贾已在路上设立灵铺！可在战斗间隙选购稀有卡牌，或消耗金币炼化剔除冗余初始卡牌。", "en":"A wandering merchant has set up shop! Buy rare cards between battles, or pay gold to purge unwanted starter cards."},
	"ui.unlock_shop_toast": {"zh-Hans":"✦ 新功能开启：灵界商肆 · 卡牌剔除！", "en":"✦ Unlocked: Spirit Shop & Card Purge!"},
	"ui.lock_shop_req": {"zh-Hans":"通关第2关开启灵铺", "en":"Clear Stage 2 to unlock Shop"},
	"ui.unlock_camp_title": {"zh-Hans":"✦ 修仙营地开启 ✦", "en":"✦ Cultivator Camp Unlocked ✦"},
	"ui.unlock_camp_desc": {"zh-Hans":"成功击破首章妖王，开辟仙家洞府！开启「七日飞升路」新手进阶福利与「离线闭关游历」长线收益。", "en":"Chapter 1 Boss vanquished! Cultivator Camp unlocked with the 7-Day Archetype Journey and deep Offline Expeditions."},
	"ui.lock_camp_req": {"zh-Hans":"通关第1章首领开启营地", "en":"Defeat Chapter 1 Boss to unlock Camp"},
	"ui.unlock_trial_title": {"zh-Hans":"✦ 每日试炼与委托开启 ✦", "en":"✦ Daily Trial & Quests Unlocked ✦"},
	"ui.unlock_trial_desc": {"zh-Hans":"声名渐起，仙门悬赏令现世！开启每日专属词缀试炼、每日委托与战役成就任务。", "en":"Your fame spreads! Daily Trials with unique mutators, daily quests, and season missions are now available."},
	"ui.unlock_trial_toast": {"zh-Hans":"✦ 新功能开启：每日试炼 · 仙门委托！", "en":"✦ Unlocked: Daily Trial & Quests!"},
	"ui.lock_trial_req": {"zh-Hans":"通关第1章开启试炼", "en":"Clear Chapter 1 to unlock Daily Trial"},
	"ui.lock_quest_req": {"zh-Hans":"通关第1章开启委托", "en":"Clear Chapter 1 to unlock Quests"},
	"ui.unlock_equip_title": {"zh-Hans":"✦ 灵装穿戴与铭文开启 ✦", "en":"✦ Equipment & Inscriptions Unlocked ✦"},
	"ui.unlock_equip_desc": {"zh-Hans":"神兵现世，天地灵宝认主！可穿戴武器与防具灵装，并消耗灵尘淬炼铭文词条大幅提升战力。", "en":"Ancient relics awaken! Equip weapons, armor, and forge powerful inscriptions using spirit dust."},
	"ui.unlock_equip_toast": {"zh-Hans":"✦ 新功能开启：灵装穿戴 · 铭文淬炼！", "en":"✦ Unlocked: Equipment & Inscriptions!"},
	"ui.lock_equip_req": {"zh-Hans":"通关第7关开启灵装", "en":"Clear Stage 7 to unlock Equipment"},
	"ui.unlock_abyss_title": {"zh-Hans":"✦ 虚空深渊开启 ✦", "en":"✦ Endless Abyss Unlocked ✦"},
	"ui.unlock_abyss_desc": {"zh-Hans":"太虚裂隙激荡，无尽深渊之门敞开！挑战层层递进的凶残妖魔，登顶全服战力巅峰排行榜。", "en":"The Void Rift tears open! Climb endless floors against brutal adversaries and claim the top of global leaderboards."},
	"ui.lock_abyss_req": {"zh-Hans":"通关第2章开启虚空深渊", "en":"Clear Chapter 2 to unlock Endless Abyss"},
	"ui.unlock_runes_title": {"zh-Hans":"✦ 符文镶嵌与共鸣开启 ✦", "en":"✦ Runes & Resonance Unlocked ✦"},
	"ui.unlock_runes_desc": {"zh-Hans":"领悟五行通幽大阵！可在核心卡牌的符孔中镶嵌烈火、疾风、坚石符文，激活强大元素共鸣羁绊。", "en":"Master the Five Elements! Socket Flame, Gale, and Stone runes into your cards to activate powerful elemental resonances."},
	"ui.unlock_runes_toast": {"zh-Hans":"✦ 新功能开启：卡牌符文镶嵌 · 元素共鸣！", "en":"✦ Unlocked: Rune Socketing & Resonances!"},
	"ui.lock_runes_req": {"zh-Hans":"通关第11关开启符文", "en":"Clear Stage 11 to unlock Runes"},
	"ui.unlock_meridians_title": {"zh-Hans":"✦ 周天经脉与百宝图鉴开启 ✦", "en":"✦ Meridians & Compendium Unlocked ✦"},
	"ui.unlock_meridians_desc": {"zh-Hans":"打通体内奇经八脉！消耗灵力冲穴获得永久属性加成，并开启收录天下奇物百宝图鉴与进阶天梯挑战。", "en":"Unlock the Eight Extraordinary Meridians! Channel spirit power for permanent stat gains, access the Compendium, and challenge high ascension tiers."},
	"ui.unlock_meridians_toast": {"zh-Hans":"✦ 新功能开启：周天经脉冲穴 · 百宝图鉴 · 进阶挑战！", "en":"✦ Unlocked: Meridians, Compendium & Challenge Tiers!"},
	"ui.lock_meridians_req": {"zh-Hans":"通关第3章开启经脉", "en":"Clear Chapter 3 to unlock Meridians"},
	"ui.unlock_modal_confirm": {"zh-Hans":"开启修行新篇章", "en":"Embark on New Chapter"},
	"ui.unlock_congrats": {"zh-Hans":"✦ 破封大吉 · 新机缘开启 ✦", "en":"✦ Seal Broken · New Path Unlocked ✦"},
	"ui.unlock_ch1_toast": {"zh-Hans":"✦ 新功能解锁：驭灵秘典 · 每日试炼 · 每周主题挑战 · 首领连战！", "en":"✦ New: Spirit Compendium, Daily Trial, Weekly Challenge, Boss Rush!"},
	"ui.unlock_abyss_toast": {"zh-Hans":"✦ 新玩法解锁：无尽深渊！", "en":"✦ New mode unlocked: Endless Abyss!"},
	"ui.unlock_difficulty_toast": {"zh-Hans":"✦ 新功能解锁：挑战等级！", "en":"✦ New: Challenge Tiers unlocked!"},
	"ui.unlock_tier_a2_toast": {"zh-Hans":"✦ 新挑战解锁：难度等级 A2！", "en":"✦ New: Challenge Tier A2 available!"},
	"ui.unlock_tier_a3_toast": {"zh-Hans":"✦ 新挑战解锁：难度等级 A3！", "en":"✦ New: Challenge Tier A3 available!"},
	"ui.unlock_tier_a4_toast": {"zh-Hans":"✦ 新挑战解锁：难度等级 A4！", "en":"✦ New: Challenge Tier A4 available!"},
	"ui.unlock_tier_a5_toast": {"zh-Hans":"✦ 新挑战解锁：难度等级 A5！", "en":"✦ New: Challenge Tier A5 available!"},
	"ui.camp_tier_next_unlock": {"zh-Hans":"通关第%d关解锁更高难度", "en":"Clear stage %d to unlock the next tier"},
	"ui.unlock_curse_run_toast": {"zh-Hans":"✦ 新玩法解锁：咒缚试炼！", "en":"✦ New mode unlocked: Curse Run!"},
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
	"ui.settings_audio_on": {"zh-Hans":"音乐 ♫", "en":"Music ♫"},
	"ui.settings_audio_off": {"zh-Hans":"静音 ♩", "en":"Muted ♩"},
	"ui.settings_sfx": {"zh-Hans":"战斗音效", "en":"Combat SFX"},
	"ui.settings_sfx_on": {"zh-Hans":"音效 ⚔", "en":"SFX ⚔"},
	"ui.settings_sfx_off": {"zh-Hans":"静音 ⚔", "en":"Muted ⚔"},
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
	"ui.leaderboard_title": {"zh-Hans":"封神天梯榜", "en":"Celestial Leaderboard"},
	"ui.leaderboard_sub": {"zh-Hans":"全服强者名录 · 万仙争锋", "en":"Global Rankings & Hall of Fame"},
	"ui.leaderboard_tab_abyss": {"zh-Hans":"无尽深渊", "en":"Endless Abyss"},
	"ui.leaderboard_tab_daily": {"zh-Hans":"每日修行", "en":"Daily Trial"},
	"ui.leaderboard_tab_samsara": {"zh-Hans":"六道轮回", "en":"Samsara"},
	"ui.leaderboard_rank": {"zh-Hans":"排名", "en":"Rank"},
	"ui.leaderboard_player": {"zh-Hans":"驭灵道号", "en":"Cultivator"},
	"ui.leaderboard_score": {"zh-Hans":"战绩", "en":"Score"},
	"ui.leaderboard_my_rank": {"zh-Hans":"我的名次", "en":"My Rank"},
	"ui.leaderboard_unranked": {"zh-Hans":"未上榜", "en":"Unranked"},
	"ui.leaderboard_open": {"zh-Hans":"天梯榜 🏆", "en":"Rankings 🏆"},
	"ui.leaderboard_refresh": {"zh-Hans":"刷新 ↻", "en":"Refresh ↻"},
	"ui.leaderboard_score_floor": {"zh-Hans":"第 %d 层", "en":"Floor %d"},
	"ui.leaderboard_score_pts": {"zh-Hans":"%d 分", "en":"%d pts"},
	"ui.leaderboard_score_asc": {"zh-Hans":"难度 A%d · %d 关", "en":"A%d · St.%d"},
	"ui.leaderboard_loading": {"zh-Hans":"正在同步天机名录...", "en":"Fetching celestial rankings..."},
	"ui.leaderboard_empty": {"zh-Hans":"暂无登榜记录，虚位以待！", "en":"No entries yet, awaiting heroes!"},
	"ui.leaderboard_sample_notice": {"zh-Hans":"⚠️ 天梯暂未连通，以下为示例榜单，非真实战绩", "en":"⚠️ Leaderboard unreachable — sample standings, not real scores"},
	"ui.leaderboard_submit_toast": {"zh-Hans":"🏆 新纪录已登入封神榜！", "en":"🏆 New record published to Leaderboard!"},
	"ui.leaderboard_scope_global": {"zh-Hans":"全服", "en":"Global"},
	"ui.leaderboard_scope_friends": {"zh-Hans":"好友", "en":"Friends"},
	"ui.leaderboard_friends_empty": {"zh-Hans":"暂无好友战绩，先添加好友吧", "en":"No friends on this board yet — add some first"},
	"ui.ghost_arena_win_toast": {"zh-Hans":"✦ 击败虚影战绩！获得%d灵币", "en":"✦ Ghost defeated! +%d gold"},
	"ui.friends_title": {"zh-Hans":"好友名录", "en":"Friends"},
	"ui.friends_sub": {"zh-Hans":"添加好友代码，同榜比拼名次", "en":"Add a friend's code to compare rankings"},
	"ui.friends_manage_btn": {"zh-Hans":"管理好友", "en":"Manage Friends"},
	"ui.friends_modal_title": {"zh-Hans":"好友名录", "en":"Friends"},
	"ui.friends_my_code_label": {"zh-Hans":"我的代码", "en":"My Code"},
	"ui.friends_copy_btn": {"zh-Hans":"复制", "en":"Copy"},
	"ui.friends_code_copied": {"zh-Hans":"代码已复制", "en":"Code copied"},
	"ui.friends_need_link": {"zh-Hans":"登录账号后即可获得专属代码，供好友添加", "en":"Sign in to get your own code so friends can add you"},
	"ui.friends_code_placeholder": {"zh-Hans":"好友代码", "en":"Friend's code"},
	"ui.friends_nickname_placeholder": {"zh-Hans":"备注名（可选）", "en":"Nickname (optional)"},
	"ui.friends_add_btn": {"zh-Hans":"添加好友", "en":"Add Friend"},
	"ui.friends_add_err_empty": {"zh-Hans":"请输入好友代码", "en":"Enter a friend code"},
	"ui.friends_add_err_invalid": {"zh-Hans":"代码格式无效", "en":"Invalid code format"},
	"ui.friends_add_err_self": {"zh-Hans":"不能添加自己", "en":"You can't add yourself"},
	"ui.friends_add_err_duplicate": {"zh-Hans":"该好友已添加", "en":"Already added"},
	"ui.friends_add_err_full": {"zh-Hans":"好友数量已达上限", "en":"Friend list is full"},
	"ui.friends_added_toast": {"zh-Hans":"✦ 好友已添加", "en":"✦ Friend added"},
	"ui.friends_removed_toast": {"zh-Hans":"好友已移除", "en":"Friend removed"},
	"ui.friends_empty_list": {"zh-Hans":"还没有好友，添加代码开始比拼吧", "en":"No friends yet — add a code to start comparing"},
	"ui.friends_count": {"zh-Hans":"%d/%d 位好友", "en":"%d/%d friends"},
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
	"ui.recap_turns": {"zh-Hans":"回合数: %d", "en":"Turns Taken: %d"},
	"ui.recap_damage": {"zh-Hans":"造成伤害: %d", "en":"Damage Dealt: %d"},
	"ui.recap_cards": {"zh-Hans":"出牌次数: %d", "en":"Cards Played: %d"},
	"ui.recap_shield": {"zh-Hans":"获得护盾: %d", "en":"Shield Gained: %d"},
	"ui.capstone_card_badge": {"zh-Hans":"极道核心金卡", "en":"Capstone Card"},
	"ui.seven_day_journey_title": {"zh-Hans":"七日飞升路", "en":"7-Day Archetype Journey"},
	"ui.seven_day_journey_sub": {"zh-Hans":"每日流派修行试炼，领取极道核心金卡与海量灵石", "en":"Daily archetype trials to claim capstone gold cards & bountiful rewards"},
	"ui.seven_day_journey_claim": {"zh-Hans":"领取奖励", "en":"Claim Reward"},
	"ui.seven_day_journey_claimed": {"zh-Hans":"已领取", "en":"Claimed"},
	"ui.seven_day_journey_locked": {"zh-Hans":"未解锁", "en":"Locked"},
	"ui.seven_day_journey_go": {"zh-Hans":"前往历练", "en":"Go"},
	"ui.seven_day_journey_day_fmt": {"zh-Hans":"第 %d 天", "en":"Day %d"},
	"ui.seven_day_journey_reward_toast": {"zh-Hans":"成功领取第 %d 日飞升奖励！", "en":"Claimed Day %d Journey Rewards!"},
	"ui.idle_expedition_title": {"zh-Hans":"闭关游历探索", "en":"Offline Expeditions"},
	"ui.idle_expedition_sub": {"zh-Hans":"离线挂机闭关，累计时长解锁珍稀秘宝", "en":"Cultivate offline to unlock timed treasure milestones"},
	"ui.idle_expedition_4h": {"zh-Hans":"4小时里程碑: 灵力尘 + 稀有符文", "en":"4h Milestone: Spirit Dust + Rare Rune"},
	"ui.idle_expedition_8h": {"zh-Hans":"8小时里程碑: 灵玉 + 铭文石", "en":"8h Milestone: Spirit Jade + Inscription"},
	"ui.idle_expedition_12h": {"zh-Hans":"12小时大满贯: 极道核心金卡", "en":"12h Milestone: Capstone Gold Card"},
	"ui.idle_expedition_unlocked": {"zh-Hans":"已达成", "en":"Unlocked"},
	"ui.idle_expedition_in_progress": {"zh-Hans":"闭关中", "en":"Cultivating"},
	"ui.deck_inspector_title": {"zh-Hans":"通关卡组检视", "en":"Deck Inspector"},
	"ui.deck_inspector_btn": {"zh-Hans":"查卡组", "en":"Deck"},
	"ui.deck_inspector_deck_size": {"zh-Hans":"卡组规模: %d 张", "en":"Deck Size: %d Cards"},
	"ui.deck_inspector_runes": {"zh-Hans":"符文与铭文搭配", "en":"Runes & Inscriptions"},
	"ui.deck_inspector_close": {"zh-Hans":"关闭", "en":"Close"},
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
	# Pre-existing bug fix: show_samsara_modal()'s cancel button already calls t("ui.cancel"),
	# but this key never existed in UI_TEXT or core.json's translations table, so it was
	# rendering the literal string "ui.cancel" to real players instead of an actual label —
	# found while looking for a confirmation-modal pattern to reuse for account deletion below.
	"ui.cancel": {"zh-Hans":"取消", "en":"Cancel"},
	"ui.account_delete_btn": {"zh-Hans":"删除账号", "en":"Delete Account"},
	"ui.account_delete_desc": {"zh-Hans":"永久删除云端存档与排行榜记录，且无法撤销", "en":"Permanently deletes your cloud save and leaderboard records — cannot be undone"},
	"ui.account_delete_modal_title": {"zh-Hans":"删除账号？", "en":"Delete Account?"},
	"ui.account_delete_modal_desc": {"zh-Hans":"此操作将永久删除你的云端存档与排行榜记录，且无法撤销。本地进度也会重置为全新状态。", "en":"This permanently deletes your cloud save and leaderboard records — this cannot be undone. Local progress will also reset to a fresh state."},
	"ui.account_delete_confirm_btn": {"zh-Hans":"确认删除", "en":"Delete Permanently"},
	"ui.account_delete_success_toast": {"zh-Hans":"账号已删除", "en":"Account deleted"},
	"ui.account_delete_failed_toast": {"zh-Hans":"删除失败，请检查网络后重试", "en":"Deletion failed — check your connection and try again"},
	"ui.auth_quick_title": {"zh-Hans":"快捷登录", "en":"Quick Sign-In"},
	"ui.auth_guest_start": {"zh-Hans":"以游客身份体验", "en":"Continue as Guest"},
	"ui.auth_email_tab": {"zh-Hans":"邮箱登录", "en":"Email Sign In"},
	"ui.auth_signup_tab": {"zh-Hans":"注册账号", "en":"Sign Up"},
	"ui.auth_email_placeholder": {"zh-Hans":"输入邮箱地址...", "en":"Enter email address..."},
	"ui.auth_password_placeholder": {"zh-Hans":"输入密码 (至少6位)...", "en":"Enter password (min 6 chars)..."},
	"ui.auth_name_placeholder": {"zh-Hans":"驭灵者昵称 (选填)...", "en":"Adventurer name (optional)..."},
	"ui.auth_btn_login": {"zh-Hans":"登录云端账号", "en":"Sign In"},
	"ui.auth_btn_signup": {"zh-Hans":"立即注册并同步", "en":"Register & Sync"},
	"ui.auth_btn_forgot": {"zh-Hans":"找回密码", "en":"Forgot Password"},
	"ui.auth_btn_device": {"zh-Hans":"一键免密上云", "en":"One-Click Cloud Sync"},
	"ui.auth_login_success": {"zh-Hans":"登录成功！云存档已同步。", "en":"Sign in successful! Cloud save synced."},
	"ui.auth_signup_check_email": {"zh-Hans":"注册成功！请前往邮箱查收确认邮件后登录。", "en":"Registered! Please check your email to confirm, then sign in."},
	"ui.auth_rate_limited": {"zh-Hans":"邮件发送过于频繁，请稍后再试。", "en":"Email rate limit reached, please try again later."},
	"ui.auth_reset_sent": {"zh-Hans":"重置密码邮件已发送，请查收邮箱。", "en":"Password reset link sent to your email."},
	"ui.auth_syncing": {"zh-Hans":"正在同步云存档...", "en":"Syncing cloud save..."},
	"ui.auth_invalid_input": {"zh-Hans":"请输入有效的邮箱地址与至少6位密码。", "en":"Please enter a valid email and 6+ char password."},
	"ui.auth_linked_supabase": {"zh-Hans":"已登录云账号: %s", "en":"Signed in with Cloud Account: %s"},
	"ui.auth_modal_title": {"zh-Hans":"账号与云端同步", "en":"Account & Cloud Sync"},
	"ui.auth_switch_to_login": {"zh-Hans":"已有账号？立即登录", "en":"Already have an account? Sign In"},
	"ui.auth_switch_to_signup": {"zh-Hans":"没有账号？注册新账号", "en":"Don't have an account? Sign Up"},
	"ui.auth_start_adventure": {"zh-Hans":"▶ 开始冒险", "en":"▶ Enter Adventure"},
	"ui.auth_switch_account": {"zh-Hans":"切换账号", "en":"Switch Account"},
	"ui.auth_email_not_confirmed": {"zh-Hans":"该邮箱尚未完成验证，请查收邮件点击确认链接后登录。", "en":"Email not verified. Please click confirmation link in your email."},
	"ui.auth_wrong_credentials": {"zh-Hans":"邮箱或密码错误，请检查后重试。", "en":"Incorrect email or password, please try again."},
	"ui.auth_email_taken": {"zh-Hans":"该邮箱已注册，请直接登录。", "en":"Email already registered, please sign in."},
	"ui.title_return": {"zh-Hans":"返回主界面", "en":"Return to Title"},
	"ui.auth_title_account_status": {"zh-Hans":"账号状态", "en":"Account Status"},
	"ui.auth_apple_unavailable": {"zh-Hans":"Apple 登录需在后台配置密钥，请使用【邮箱登录/注册】同步云存档。", "en":"Apple Sign-In requires backend configuration. Please use Email Login to sync."},
	"ui.auth_google_unavailable": {"zh-Hans":"Google 登录需在后台配置密钥，请使用【邮箱登录/注册】同步云存档。", "en":"Google Sign-In requires backend configuration. Please use Email Login to sync."},
	"ui.intro_skip": {"zh-Hans":"跳过 ⏭", "en":"Skip ⏭"},
	"ui.intro_act1": {"zh-Hans":"混沌初开 · 万灵归虚", "en":"From primordial chaos, spirits arose..."},
	"ui.intro_act2": {"zh-Hans":"远古封印 · 灵潮涌动", "en":"Ancient seals shatter, mystical tides surge..."},
	"ui.intro_act3": {"zh-Hans":"灵狐降世 · 宿命抉择", "en":"The Spirit Fox awakens to defy destiny..."},
	"ui.intro_act4_title": {"zh-Hans":"灵界之契", "en":"SPIRITBOUND"},
	"ui.intro_act4_sub": {"zh-Hans":"踏破轮回 · 重铸仙途", "en":"Defy the cycles. Forge your legend."},
	"ui.settings_replay_intro": {"zh-Hans":"重播开场动画", "en":"Replay Intro Video"},
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
	"ui.season_pass_buy": {"zh-Hans":"解锁灵尊进阶轨", "en":"Unlock Spirit Track"},
	"ui.season_pass_restore": {"zh-Hans":"恢复购买", "en":"Restore Purchases"},
	"ui.season_pass_premium_hint": {"zh-Hans":"购买通行证后即可解锁进阶轨奖励", "en":"Premium rewards unlock after purchasing the pass"},
	"ui.season_pass_purchase_pending": {"zh-Hans":"正在验证购买…", "en":"Verifying purchase..."},
	"ui.season_pass_purchase_success": {"zh-Hans":"灵尊进阶轨已解锁！", "en":"Spirit Track unlocked!"},
	"ui.season_pass_purchase_failed": {"zh-Hans":"购买未完成或验证失败", "en":"Purchase not completed or not verified"},
	"ui.season_pass_purchase_unavailable": {"zh-Hans":"商店暂不可用，请稍后再试", "en":"Store unavailable, try again later"},
	"ui.season_pass_restore_none": {"zh-Hans":"未找到可恢复的购买", "en":"No purchases found to restore"},
	"ui.season_pass_restore_done": {"zh-Hans":"已恢复灵尊进阶轨", "en":"Spirit Track restored"},
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
	"ui.draft_card_cost_fmt": {"zh-Hans":"%s (%d 费)", "en":"%s (%d Cost)"},
	"ui.draft_deck_progress_fmt": {"zh-Hans":"当前牌组 (%d/15 张): %s", "en":"Current Deck (%d/15): %s"},
	"ui.draft_deck_label": {"zh-Hans":"竞技场牌组 (15张):", "en":"Arena Deck (15 Cards):"},
	"ui.draft_next_opponent_fmt": {"zh-Hans":"迎战第 %d 位灵界对手", "en":"Face Spirit Opponent #%d"},
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
	"ui.run_recap_share_hint": {"zh-Hans":"点击上方按钮，将战报画卷保存为图片", "en":"Tap the button above to save this recap as an image"},
	"ui.run_recap_save_unavailable": {"zh-Hans":"此设备暂不支持生成战报图片", "en":"Recap image capture isn't available on this device"},
	"ui.recap_poster_title": {"zh-Hans":"战报画卷", "en":"Battle Recap"},
	"ui.recap_poster_footer": {"zh-Hans":"Spiritbound", "en":"Spiritbound"},
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
	"ui.curse_run_title": {"zh-Hans":"咒缚试炼", "en":"Curse Run"},
	"ui.curse_run_sub": {"zh-Hans":"选择一项诅咒，作为自我施加的挑战，层数越深敌人越强", "en":"Pick one curse as a self-imposed handicap — floors escalate the deeper you go"},
	"ui.curse_run_locked": {"zh-Hans":"达到 A2 试炼难度后解锁", "en":"Unlocks at Ascension Tier A2"},
	"ui.curse_run_choose": {"zh-Hans":"点选下方一项诅咒开始", "en":"Tap a curse below to begin"},
	"ui.curse_run_floor_fmt": {"zh-Hans":"第 %d 层", "en":"Floor %d"},
	"ui.curse_run_record_fmt": {"zh-Hans":"最高纪录 第 %d 层", "en":"Best: Floor %d"},
	"ui.curse_run_enter": {"zh-Hans":"进入试炼", "en":"Enter Trial"},
	"ui.curse_run_cleared_fmt": {"zh-Hans":"已获得徽章 %d / 10", "en":"Badges earned: %d / 10"},
	"ui.curse_run_stage_label_fmt": {"zh-Hans":"咒缚试炼 · 第 %d 层", "en":"Curse Run · Floor %d"},
	"ui.curse_run_badge_toast_fmt": {"zh-Hans":"「%s」徽章已解锁！", "en":"\"%s\" badge unlocked!"},
	"mutator.glass_cannon.name": {"zh-Hans":"脆刃", "en":"Glass Cannon"},
	"mutator.glass_cannon.desc": {"zh-Hans":"生命上限锁定为30，造成的伤害提高50%。", "en":"Max HP locked to 30; damage dealt +50%."},
	"mutator.energy_famine.name": {"zh-Hans":"灵力枯竭", "en":"Energy Famine"},
	"mutator.energy_famine.desc": {"zh-Hans":"能量上限永远锁定在2点，不再随回合增长。", "en":"Energy is locked at 2 every turn and never grows."},
	"mutator.mirror_world.name": {"zh-Hans":"颠倒乾坤", "en":"Mirror World"},
	"mutator.mirror_world.desc": {"zh-Hans":"战斗开始时与敌方首领互换生命上限。", "en":"Swaps max HP with the boss at battle start."},
	"mutator.haunted_deck.name": {"zh-Hans":"百鬼夜行", "en":"Haunted Deck"},
	"mutator.haunted_deck.desc": {"zh-Hans":"本场战斗的牌组中混入额外的腐朽枯萎诅咒牌。", "en":"An extra Decay Blight curse is shuffled into this battle's deck."},
	"mutator.ironclad_will.name": {"zh-Hans":"钢铁意志", "en":"Ironclad Will"},
	"mutator.ironclad_will.desc": {"zh-Hans":"本场战斗不可携带任何法宝。", "en":"No relics may be carried into this battle."},
	"mutator.elite_gauntlet.name": {"zh-Hans":"精锐试炼", "en":"Elite Gauntlet"},
	"mutator.elite_gauntlet.desc": {"zh-Hans":"每层额外增加一名敌人。", "en":"Adds one extra enemy to every floor."},
	"mutator.barren_harvest.name": {"zh-Hans":"贫瘠之地", "en":"Barren Harvest"},
	"mutator.barren_harvest.desc": {"zh-Hans":"本模式获得的灵石减半。", "en":"Gold earned from this mode is halved."},
	"mutator.berserkers_pact.name": {"zh-Hans":"嗜血之约", "en":"Berserker's Pact"},
	"mutator.berserkers_pact.desc": {"zh-Hans":"造成的伤害和受到的伤害都提高30%。", "en":"Damage dealt and damage taken are both +30%."},
	"mutator.no_mercy.name": {"zh-Hans":"孤注一掷", "en":"No Mercy"},
	"mutator.no_mercy.desc": {"zh-Hans":"本场战斗中卡牌回复效果完全失效。", "en":"Card-based healing effects do nothing this battle."},
	"mutator.fewer_draws.name": {"zh-Hans":"缩衣节食", "en":"Fewer Draws"},
	"mutator.fewer_draws.desc": {"zh-Hans":"每回合抽牌数量减少1张。", "en":"Draw 1 fewer card every turn."},
	"event.ember_lord.name": {"zh-Hans":"烬王之季", "en":"Season of the Ember Lord"},
	"event.ember_lord.desc": {"zh-Hans":"烈焰吞噬四野，敌人的攻击愈发凶猛。", "en":"Flames consume the land — enemies strike harder than ever."},
	"event.frost_widow.name": {"zh-Hans":"寒霜之季", "en":"Season of the Frost Widow"},
	"event.frost_widow.desc": {"zh-Hans":"刺骨寒霜召来额外的追随者。", "en":"Bitter frost summons an extra attendant."},
	"event.withered_king.name": {"zh-Hans":"荒芜之季", "en":"Season of the Withered King"},
	"event.withered_king.desc": {"zh-Hans":"荒芜的诅咒滋养着敌人，且封锁一切治愈。", "en":"A withering curse swells the foe's ranks and seals away all healing."},
	"event.storm_judge.name": {"zh-Hans":"雷罚之季", "en":"Season of the Storm Judge"},
	"event.storm_judge.desc": {"zh-Hans":"雷霆审判降临，敌方的每一次打击都更为致命。", "en":"Thunderous judgment falls — every enemy strike lands harder."},
	"ui.world_event_title": {"zh-Hans":"世界活动", "en":"World Event"},
	"ui.world_event_sub": {"zh-Hans":"每4周轮换一次的限时主题试炼，可反复挑战，每期首胜额外获得徽章", "en":"A themed trial rotating every 4 weeks — fight it as often as you like, first win each period earns a badge"},
	"ui.world_event_enter": {"zh-Hans":"进入试炼", "en":"Enter Trial"},
	"ui.world_event_stage_label_fmt": {"zh-Hans":"世界活动 · %s", "en":"World Event · %s"},
	"ui.world_event_badges_fmt": {"zh-Hans":"已收集徽章 %d / 4", "en":"Badges collected: %d / 4"},
	"ui.world_event_badge_toast_fmt": {"zh-Hans":"「%s」徽章已解锁！", "en":"\"%s\" badge unlocked!"},
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
	"ui.run_recap_saved_toast": {"zh-Hans":"战报图片已保存！", "en":"Recap image saved!"},
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
	"ui.codex_title": {"zh-Hans":"旅者典籍", "en":"Career Codex"},
	"ui.codex_overview": {"zh-Hans":"战绩总览", "en":"Career Overview"},
	"ui.codex_total_battles": {"zh-Hans":"总战役", "en":"Total Battles"},
	"ui.codex_victories": {"zh-Hans":"胜场", "en":"Victories"},
	"ui.codex_defeats": {"zh-Hans":"败场", "en":"Defeats"},
	"ui.codex_win_rate": {"zh-Hans":"胜率", "en":"Win Rate"},
	"ui.codex_best_streak": {"zh-Hans":"最高连胜", "en":"Best Streak"},
	"ui.codex_current_streak": {"zh-Hans":"当前连胜", "en":"Current Streak"},
	"ui.codex_mastery": {"zh-Hans":"战斗造诣", "en":"Combat Mastery"},
	"ui.codex_total_damage": {"zh-Hans":"累计输出伤害", "en":"Damage Dealt"},
	"ui.codex_total_shield": {"zh-Hans":"累计聚灵护盾", "en":"Shield Gained"},
	"ui.codex_cards_played": {"zh-Hans":"施展卡牌总数", "en":"Cards Played"},
	"ui.codex_elites_slain": {"zh-Hans":"斩获精英", "en":"Elites Slain"},
	"ui.codex_bosses_slain": {"zh-Hans":"降伏首领", "en":"Bosses Slain"},
	"ui.codex_fav_hero": {"zh-Hans":"契约本尊", "en":"Signature Hero"},
	"ui.codex_fav_card": {"zh-Hans":"绝技灵牌", "en":"Signature Card"},
	"ui.codex_hall_of_fame": {"zh-Hans":"常胜画卷 (首领大捷)", "en":"Hall of Fame (Boss Victories)"},
	"ui.codex_no_records": {"zh-Hans":"暂无常胜首领画卷，去战胜领主开启传奇战纪吧！", "en":"No victorious boss records yet. Defeat a boss to forge your legend!"},
	"ui.codex_hof_turns_fmt": {"zh-Hans":"耗时 %d 回合", "en":"%d Turns"},
	"ui.codex_hof_hp_fmt": {"zh-Hans":"残余生命 %d", "en":"%d HP Left"},
	"ui.codex_hof_deck_fmt": {"zh-Hans":"卡组 %d 张", "en":"%d Cards Deck"},
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
	"ui.samsara_title": {"zh-Hans":"轮回仙途 · 逆天重修", "en":"Samsara · Reincarnation"},
	"ui.samsara_realm_fmt": {"zh-Hans":"当前境界: %s", "en":"Current Realm: %s"},
	"ui.samsara_count_fmt": {"zh-Hans":"已渡轮回: %d 次", "en":"Reincarnations: %d"},
	"ui.samsara_active_blessings": {"zh-Hans":"✦ 轮回道果加护", "en":"✦ Active Samsara Blessings"},
	"ui.samsara_blessing_hp": {"zh-Hans":"凡蜕化灵: 最大生命 +%d", "en":"Mortal Shedding: Max HP +%d"},
	"ui.samsara_blessing_shield": {"zh-Hans":"太虚凝气: 战局开局护盾 +%d", "en":"Ether Ward: Battle Start Shield +%d"},
	"ui.samsara_blessing_draw": {"zh-Hans":"灵机顿悟: 首回合摸牌 +%d", "en":"Spiritual Insight: Turn 1 Card Draw +%d"},
	"ui.samsara_blessing_gold": {"zh-Hans":"道基深厚: 轮回开局赠送灵石 +%d", "en":"Abundant Heritage: Rebirth Gold +%d"},
	"ui.samsara_none": {"zh-Hans":"暂未入轮回，尚未激活加护。", "en":"Not yet reincarnated. No active blessings."},
	"ui.samsara_enter_btn": {"zh-Hans":"开启轮回 · 逆天改命", "en":"Enter Samsara"},
	"ui.samsara_modal_title": {"zh-Hans":"六道轮回 · 涅槃重生", "en":"Samsara Rebirth Ceremony"},
	"ui.samsara_modal_lore": {"zh-Hans":"散尽凡躯凡尘路，九死一生踏仙途。\n轮回将重置主线关卡进度，但你收集的所有卡牌、装备、灵石灵玉与流派修为将永驻道基！", "en":"Shed the mortal coil to ascend higher into the immortal path.\nReincarnation restarts campaign stages, while preserving all your cards, equipment, currencies, masteries, and memories!"},
	"ui.samsara_modal_kept": {"zh-Hans":"✅ 永久保留: 全卡组收藏、强化、装备符文、灵石灵玉、流派熟练度与图鉴成就", "en":"✅ Preserved: All cards, upgrades, equipment, runes, currencies, masteries, and achievements"},
	"ui.samsara_modal_reset": {"zh-Hans":"🔄 重新开始: 关卡进度重置为第1章第1关，刷新奇遇与推图奖励", "en":"🔄 Reset: Campaign progress resets to Chapter 1, Stage 1 to earn new rewards"},
	"ui.samsara_modal_gain": {"zh-Hans":"🌟 获得加护: 轮回等级提升，解锁永久战斗属性加成与更高难度挑战！", "en":"🌟 Gained: Reincarnation tier rises, granting permanent combat boosts & higher difficulty"},
	"ui.samsara_confirm_btn": {"zh-Hans":"确认轮回 · 散功再修", "en":"Confirm Reincarnation"},
	"ui.samsara_toast_success": {"zh-Hans":"轮回成功！褪去凡胎，道行晋升为: %s", "en":"Reincarnation complete! Ascended to: %s"},
	"ui.camp_tier_a6_name": {"zh-Hans":"A6 · 万劫归一", "en":"A6 · Cataclysm"},
	"ach.samsara1.name": {"zh-Hans":"轮回证道", "en":"Path of Samsara"},
	"ach.samsara1.desc": {"zh-Hans":"首次经历六道轮回，散功重修登临仙境", "en":"Complete your first Samsara reincarnation"},
	"ui.meridian_title": {"zh-Hans":"灵脉修真", "en":"Cultivation Meridians"},
	"ui.meridian_sub": {"zh-Hans":"打通周天三大经脉 · 凝炼万古道基", "en":"Attune the Three Meridians · Forge Eternal Foundation"},
	"ui.meridian_ren": {"zh-Hans":"任脉 · 气血守御", "en":"Ren · Vitality & Defense"},
	"ui.meridian_du": {"zh-Hans":"督脉 · 罡气神威", "en":"Du · Offensive Might"},
	"ui.meridian_chong": {"zh-Hans":"冲脉 · 通灵造化", "en":"Chong · Flow & Fortune"},
	"ui.meridian_upgrade": {"zh-Hans":"冲穴提升", "en":"Attune"},
	"ui.meridian_maxed": {"zh-Hans":"已圆满", "en":"Maxed"},
	"ui.meridian_reset": {"zh-Hans":"洗髓归元", "en":"Reset Meridians"},
	"ui.meridian_reset_confirm": {"zh-Hans":"确定散去所有已通经脉？将 100% 全额返还所有消耗的灵尘！", "en":"Reset all attuned meridians? 100% of spent Spirit Dust will be refunded!"},
	"ui.meridian_reset_toast": {"zh-Hans":"洗髓完成！已归还 %d 灵尘。", "en":"Meridians reset! Refunded %d Spirit Dust."},
	"ui.meridian_upgrade_toast": {"zh-Hans":"经脉突破！《%s》提升至第 %d 重！", "en":"Breakthrough! %s reached Rank %d!"},
	"ui.meridian_dust_cost": {"zh-Hans":"%d 灵尘", "en":"%d Dust"},
	"ui.meridian_rank_fmt": {"zh-Hans":"第 %d / %d 重", "en":"Rank %d / %d"},
	"ui.meridian_summary_btn": {"zh-Hans":"灵脉修真 🎋", "en":"Meridians 🎋"},
	"ui.meridian_summary_title": {"zh-Hans":"已通经络加护", "en":"Active Meridian Attunements"},
	"ui.meridian_summary_none": {"zh-Hans":"尚未打通周天经络，前往修真提升战力！", "en":"No meridians attuned yet. Attune nodes to empower your hero!"},
	"ui.reforge_title": {"zh-Hans":"器灵重铸与灵纹洗练", "en":"Equipment Reforge & Inscription"},
	"ui.reforge_tab_title": {"zh-Hans":"器灵重铸", "en":"Equipment Reforge"},
	"ui.reforge_btn": {"zh-Hans":"重铸", "en":"Reforge"},
	"ui.reforge_upgrade_btn": {"zh-Hans":"进阶重铸", "en":"Ascend Tier"},
	"ui.reforge_maxed": {"zh-Hans":"已达仙品极境", "en":"Max Tier Reached"},
	"ui.reforge_cost_fmt": {"zh-Hans":"消耗: %d 金币 + %d 灵尘", "en":"Cost: %d Gold + %d Dust"},
	"ui.reforge_current_tier": {"zh-Hans":"当前品阶: %s", "en":"Current Tier: %s"},
	"ui.reforge_next_tier": {"zh-Hans":"进阶效果: %s", "en":"Next Tier: %s"},
	"ui.reforge_toast_success": {"zh-Hans":"重铸成功！%s 进阶为【%s】！", "en":"Reforge success! %s reached [%s]!"},
	"ui.reforge_insufficient": {"zh-Hans":"金币或灵尘不足！", "en":"Insufficient Gold or Spirit Dust!"},
	"ui.inscribe_title": {"zh-Hans":"灵纹洗练", "en":"Inscription Affixes"},
	"ui.inscribe_btn": {"zh-Hans":"洗练灵纹", "en":"Roll Inscriptions"},
	"ui.inscribe_cost_fmt": {"zh-Hans":"洗练消耗: %d 金币 + %d 灵尘", "en":"Roll Cost: %d Gold + %d Dust"},
	"ui.inscribe_slot_locked": {"zh-Hans":"🔒 升至【%s】解锁此灵纹槽", "en":"🔒 Reach [%s] to unlock slot"},
	"ui.inscribe_empty": {"zh-Hans":"尚未洗练灵纹，点击下方洗练！", "en":"No inscriptions yet. Tap below to roll!"},
	"ui.inscribe_toast_success": {"zh-Hans":"洗练完成！已为装备淬炼出新灵纹！", "en":"Inscriptions rolled successfully!"},
	"ui.inscribe_no_slots": {"zh-Hans":"当前品阶暂无可用灵纹槽，请先升阶！", "en":"No affix slots unlocked. Ascend tier first!"},
	"ui.inscribe_affix_prefix": {"zh-Hans":"✦ 灵纹: ", "en":"✦ Inscription: "},
	# Local-notification copy (Godot/scripts/notify_bridge.gd). Every string lives here like every
	# other user-facing string, even though a native call site consumes it rather than a Control —
	# that keeps the one place a translator looks actually complete.
	"push.daily.title": {"zh-Hans":"每日试炼已重置", "en":"Your Daily Trial has reset"},
	"push.daily.body": {"zh-Hans":"新的一天，新的十五重试炼。今日连续通关还有额外灵玉。", "en":"A new day, a fresh 15-stage trial. Streak clears pay bonus jade."},
	"push.weekly.title": {"zh-Hans":"周常挑战已换题", "en":"This week's challenge is up"},
	"push.weekly.body": {"zh-Hans":"本周新词条已生效，八重关卡与周榜一并刷新。", "en":"A new weekly affix is live — 8 stages and the weekly board have reset."},
	"push.login.title": {"zh-Hans":"今日签到还没领", "en":"Today's check-in is still unclaimed"},
	"push.login.body": {"zh-Hans":"本周已累计登录，别断了连续奖励。", "en":"You've logged in this week — don't break the streak."},
	"push.return.title": {"zh-Hans":"灵界还在等你", "en":"The spirit realm is waiting"},
	"push.return.body": {"zh-Hans":"体力已回满，远征与悬赏都刷新了。", "en":"Your stamina is full and new bounties have appeared."},
	"ui.rate_prompt_btn": {"zh-Hans":"⭐ 喜欢的话，留个好评吧", "en":"⭐ Enjoying it? Leave a review"},
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

func equip_tier_name(tier: int, language := "zh-Hans") -> String:
	var idx := clampi(tier, 0, EQUIPMENT_TIER_NAMES.size() - 1)
	var entry: Dictionary = EQUIPMENT_TIER_NAMES[idx]
	return str(entry.get("en" if language == "en" else "zh", ""))

func equip_tier_color(tier: int) -> Color:
	var idx := clampi(tier, 0, EQUIPMENT_TIER_NAMES.size() - 1)
	var entry: Dictionary = EQUIPMENT_TIER_NAMES[idx]
	return Color(str(entry.get("color", "8fa2a6")))

func equip_tier_cost(current_tier: int) -> Dictionary:
	if current_tier < 0 or current_tier >= EQUIPMENT_TIER_COSTS.size(): return {}
	return EQUIPMENT_TIER_COSTS[current_tier]

func equip_inscribe_cost() -> Dictionary:
	return EQUIPMENT_INSCRIBE_COST

func equip_detail_tiered(item: Dictionary, tier: int, language := "zh-Hans") -> String:
	var id: String = str(item.get("id", ""))
	if EQUIPMENT_TIER_DATA.has(id):
		var tiers: Array = EQUIPMENT_TIER_DATA[id]
		var t := clampi(tier, 0, tiers.size() - 1)
		var entry: Dictionary = tiers[t]
		return str(entry.get("en" if language == "en" else "zh", ""))
	return equip_detail(item, language)

func roll_inscription_affixes(tier: int, rng: RandomNumberGenerator = null) -> Array:
	var slots: int = clampi(tier, 0, 3)
	if slots <= 0: return []
	var r: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	if rng == null: r.randomize()
	var res: Array = []
	var pool: Array = INSCRIPTION_AFFIXES.duplicate()
	pool.shuffle()
	for i in range(slots):
		var aff: Dictionary = pool[i % pool.size()]
		var vals: Array = aff.get("values", [1, 2, 3])
		var max_idx: int = clampi(tier - 1, 0, vals.size() - 1)
		var val_idx: int = r.randi_range(0, max_idx)
		var val: int = int(vals[val_idx])
		res.append({"id": aff.id, "val": val})
	return res

func inscription_text(affix: Dictionary, language := "zh-Hans") -> String:
	var aid: String = str(affix.get("id", ""))
	var val: int = int(affix.get("val", 0))
	for aff in INSCRIPTION_AFFIXES:
		if aff.id == aid:
			var fmt: String = str(aff.get("fmt_en" if language == "en" else "fmt_zh", ""))
			return fmt % val
	return ""

func aggregate_inscriptions(equipped_ids: Array, equipment_inscriptions: Dictionary) -> Dictionary:
	var res := {
		"hp": 0,
		"shield": 0,
		"atk": 0,
		"thorns": 0,
		"gold": 0,
		"dust": 0,
		"heal": 0,
		"crit": 0
	}
	for id in equipped_ids:
		var affixes: Array = equipment_inscriptions.get(id, [])
		for aff in affixes:
			if not aff is Dictionary: continue
			var aid: String = str(aff.get("id", ""))
			var val: int = int(aff.get("val", 0))
			match aid:
				"inscr_hp": res.hp += val
				"inscr_shield": res.shield += val
				"inscr_atk": res.atk += val
				"inscr_thorns": res.thorns += val
				"inscr_gold": res.gold += val
				"inscr_dust": res.dust += val
				"inscr_heal": res.heal += val
				"inscr_crit": res.crit += val
	return res

func rune_name(rune: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return rune.get("en", rune.get("zh", ""))
	return rune.get("zh", "")

func rune_detail(rune: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return rune.get("detail_en", rune.get("detail", ""))
	return rune.get("detail", "")
