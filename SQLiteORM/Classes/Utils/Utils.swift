//
//  Utils.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/5.
//

import Foundation

@_silgen_name("simplifiedString")
func simplifiedString(_ string: NSString) -> NSString {
    return (string as String).simplified as NSString
}

@_silgen_name("traditionalString")
func traditionalString(_ string: NSString) -> NSString {
    return (string as String).traditional as NSString
}

/// 拼音相关
fileprivate final class PinYin {
    static let shared: PinYin = PinYin()
    private let gbCodes = "锕皑蔼碍爱嗳嫒瑷暧霭谙铵鹌肮袄奥媪骜鳌坝罢钯摆败呗颁办绊钣帮绑镑谤剥饱宝报鲍鸨龅辈贝钡狈备惫鹎贲锛绷笔毕毙币闭荜哔滗铋筚跸边编贬变辩辫苄缏笾标骠飑飙镖镳鳔鳖别瘪濒滨宾摈傧缤槟殡膑镔髌鬓饼禀拨钵铂驳饽钹鹁补钸财参蚕残惭惨灿骖黪苍舱仓沧厕侧册测恻层诧锸侪钗搀掺蝉馋谗缠铲产阐颤冁谄谶蒇忏婵骣觇禅镡场尝长偿肠厂畅伥苌怅阊鲳钞车彻砗尘陈衬伧谌榇碜龀撑称惩诚骋枨柽铖铛痴迟驰耻齿炽饬鸱冲冲虫宠铳畴踌筹绸俦帱雠橱厨锄雏础储触处刍绌蹰传钏疮闯创怆锤缍纯鹑绰辍龊辞词赐鹚聪葱囱从丛苁骢枞凑辏蹿窜撺错锉鹾达哒鞑带贷骀绐担单郸掸胆惮诞弹殚赕瘅箪当挡党荡档谠砀裆捣岛祷导盗焘灯邓镫敌涤递缔籴诋谛绨觌镝颠点垫电巅钿癫钓调铫鲷谍叠鲽钉顶锭订铤丢铥东动栋冻岽鸫窦犊独读赌镀渎椟牍笃黩锻断缎簖兑队对怼镦吨顿钝炖趸夺堕铎鹅额讹恶饿谔垩阏轭锇锷鹗颚颛鳄诶儿尔饵贰迩铒鸸鲕发罚阀珐矾钒烦贩饭访纺钫鲂飞诽废费绯镄鲱纷坟奋愤粪偾丰枫锋风疯冯缝讽凤沣肤辐抚辅赋复负讣妇缚凫驸绂绋赙麸鲋鳆钆该钙盖赅杆赶秆赣尴擀绀冈刚钢纲岗戆镐睾诰缟锆搁鸽阁铬个纥镉颍给亘赓绠鲠龚宫巩贡钩沟苟构购够诟缑觏蛊顾诂毂钴锢鸪鹄鹘剐挂鸹掴关观馆惯贯诖掼鹳鳏广犷规归龟闺轨诡贵刽匦刿妫桧鲑鳜辊滚衮绲鲧锅国过埚呙帼椁蝈铪骇韩汉阚绗颉号灏颢阂鹤贺诃阖蛎横轰鸿红黉讧荭闳鲎壶护沪户浒鹕哗华画划话骅桦铧怀坏欢环还缓换唤痪焕涣奂缳锾鲩黄谎鳇挥辉毁贿秽会烩汇讳诲绘诙荟哕浍缋珲晖荤浑诨馄阍获货祸钬镬击机积饥迹讥鸡绩缉极辑级挤几蓟剂济计记际继纪讦诘荠叽哜骥玑觊齑矶羁虿跻霁鲚鲫夹荚颊贾钾价驾郏浃铗镓蛲歼监坚笺间艰缄茧检碱硷拣捡简俭减荐槛鉴践贱见键舰剑饯渐溅涧谏缣戋戬睑鹣笕鲣鞯将浆蒋桨奖讲酱绛缰胶浇骄娇搅铰矫侥脚饺缴绞轿较挢峤鹪鲛阶节洁结诫届疖颌鲒紧锦仅谨进晋烬尽劲荆茎卺荩馑缙赆觐鲸惊经颈静镜径痉竞净刭泾迳弪胫靓纠厩旧阄鸠鹫驹举据锯惧剧讵屦榉飓钜锔窭龃鹃绢锩镌隽觉决绝谲珏钧军骏皲开凯剀垲忾恺铠锴龛闶钪铐颗壳课骒缂轲钶锞颔垦恳龈铿抠库裤喾块侩郐哙脍宽狯髋矿旷况诓诳邝圹纩贶亏岿窥馈溃匮蒉愦聩篑阃锟鲲扩阔蛴蜡腊莱来赖崃徕涞濑赉睐铼癞籁蓝栏拦篮阑兰澜谰揽览懒缆烂滥岚榄斓镧褴琅阆锒捞劳涝唠崂铑铹痨乐鳓镭垒类泪诔缧篱狸离鲤礼丽厉励砾历沥隶俪郦坜苈莅蓠呖逦骊缡枥栎轹砺锂鹂疠粝跞雳鲡鳢俩联莲连镰怜涟帘敛脸链恋炼练蔹奁潋琏殓裢裣鲢粮凉两辆谅魉疗辽镣缭钌鹩猎临邻鳞凛赁蔺廪檩辚躏龄铃灵岭领绫棂蛏鲮馏刘浏骝绺镏鹨龙聋咙笼垄拢陇茏泷珑栊胧砻楼娄搂篓偻蒌喽嵝镂瘘耧蝼髅芦卢颅庐炉掳卤虏鲁赂禄录陆垆撸噜闾泸渌栌橹轳辂辘氇胪鸬鹭舻鲈峦挛孪滦乱脔娈栾鸾銮抡轮伦仑沦纶论囵萝罗逻锣箩骡骆络荦猡泺椤脶镙驴吕铝侣屡缕虑滤绿榈褛锊呒妈玛码蚂马骂吗唛嬷杩买麦卖迈脉劢瞒馒蛮满谩缦镘颡鳗猫锚铆贸麽没镁门闷们扪焖懑钔锰梦眯谜弥觅幂芈谧猕祢绵缅渑腼黾庙缈缪灭悯闽闵缗鸣铭谬谟蓦馍殁镆谋亩钼呐钠纳难挠脑恼闹铙讷馁内拟腻铌鲵撵辇鲶酿鸟茑袅聂啮镊镍陧蘖嗫颟蹑柠狞宁拧泞苎咛聍钮纽脓浓农侬哝驽钕诺傩疟欧鸥殴呕沤讴怄瓯盘蹒庞抛疱赔辔喷鹏纰罴铍骗谝骈飘缥频贫嫔苹凭评泼颇钋扑铺朴谱镤镨栖脐齐骑岂启气弃讫蕲骐绮桤碛颀颃鳍牵钎铅迁签谦钱钳潜浅谴堑佥荨悭骞缱椠钤枪呛墙蔷强抢嫱樯戗炝锖锵镪羟跄锹桥乔侨翘窍诮谯荞缲硗跷窃惬锲箧钦亲寝锓轻氢倾顷请庆揿鲭琼穷茕蛱巯赇虮鳅趋区躯驱龋诎岖阒觑鸲颧权劝诠绻辁铨却鹊确阕阙悫让饶扰绕荛娆桡热韧认纫饪轫荣绒嵘蝾缛铷颦软锐蚬闰润洒萨飒鳃赛伞毵糁丧骚扫缫涩啬铯穑杀刹纱铩鲨筛晒酾删闪陕赡缮讪姗骟钐鳝墒伤赏垧殇觞烧绍赊摄慑设厍滠畲绅审婶肾渗诜谂渖声绳胜师狮湿诗时蚀实识驶势适释饰视试谥埘莳弑轼贳铈鲥寿兽绶枢输书赎属术树竖数摅纾帅闩双谁税顺说硕烁铄丝饲厮驷缌锶鸶耸怂颂讼诵擞薮馊飕锼苏诉肃谡稣虽随绥岁谇孙损笋荪狲缩琐锁唢睃獭挞闼铊鳎台态钛鲐摊贪瘫滩坛谭谈叹昙钽锬顸汤烫傥饧铴镗涛绦讨韬铽腾誊锑题体屉缇鹈阗条粜龆鲦贴铁厅听烃铜统恸头钭秃图钍团抟颓蜕饨脱鸵驮驼椭箨鼍袜娲腽弯湾顽万纨绾网辋韦违围为潍维苇伟伪纬谓卫诿帏闱沩涠玮韪炜鲔温闻纹稳问阌瓮挝蜗涡窝卧莴龌呜钨乌诬无芜吴坞雾务误邬庑怃妩骛鹉鹜锡牺袭习铣戏细饩阋玺觋虾辖峡侠狭厦吓硖鲜纤贤衔闲显险现献县馅羡宪线苋莶藓岘猃娴鹇痫蚝籼跹厢镶乡详响项芗饷骧缃飨萧嚣销晓啸哓潇骁绡枭箫协挟携胁谐写泻谢亵撷绁缬锌衅兴陉荥凶汹锈绣馐鸺虚嘘须许叙绪续诩顼轩悬选癣绚谖铉镟学谑泶鳕勋询寻驯训讯逊埙浔鲟压鸦鸭哑亚讶垭娅桠氩阉烟盐严岩颜阎艳厌砚彦谚验厣赝俨兖谳恹闫酽魇餍鼹鸯杨扬疡阳痒养样炀瑶摇尧遥窑谣药轺鹞鳐爷页业叶靥谒邺晔烨医铱颐遗仪蚁艺亿忆义诣议谊译异绎诒呓峄饴怿驿缢轶贻钇镒镱瘗舣荫阴银饮隐铟瘾樱婴鹰应缨莹萤营荧蝇赢颖茔莺萦蓥撄嘤滢潆璎鹦瘿颏罂哟拥佣痈踊咏镛优忧邮铀犹诱莸铕鱿舆鱼渔娱与屿语狱誉预驭伛俣谀谕蓣嵛饫阈妪纡觎欤钰鹆鹬龉鸳渊辕园员圆缘远橼鸢鼋约跃钥粤悦阅钺郧匀陨运蕴酝晕韵郓芸恽愠纭韫殒氲杂灾载攒暂赞瓒趱錾赃脏驵凿枣责择则泽赜啧帻箦贼谮赠综缯轧铡闸栅诈斋债毡盏斩辗崭栈战绽谵张涨帐账胀赵诏钊蛰辙锗这谪辄鹧贞针侦诊镇阵浈缜桢轸赈祯鸩挣睁狰争帧症郑证诤峥钲铮筝织职执纸挚掷帜质滞骘栉栀轵轾贽鸷蛳絷踬踯觯钟终种肿众锺诌轴皱昼骤纣绉猪诸诛烛瞩嘱贮铸驻伫槠铢专砖转赚啭馔颞桩庄装妆壮状锥赘坠缀骓缒谆准着浊诼镯兹资渍谘缁辎赀眦锱龇鲻踪总纵偬邹诹驺鲰诅组镞钻缵躜鳟翱并卜沉丑淀迭斗范干皋硅柜后伙秸杰诀夸里凌么霉捻凄扦圣尸抬涂洼喂污锨咸蝎彝涌游吁御愿岳云灶扎札筑于志注凋讠谫郄勐凼坂垅垴埯埝苘荬荮莜莼菰藁揸吒吣咔咝咴噘噼嚯幞岙嵴彷徼犸狍馀馇馓馕愣憷懔丬溆滟溷漤潴澹甯纟绔绱珉枧桊桉槔橥轱轷赍肷胨飚煳煅熘愍淼砜磙眍钚钷铘铞锃锍锎锏锘锝锪锫锿镅镎镢镥镩镲稆鹋鹛鹱疬疴痖癯裥襁耢颥螨麴鲅鲆鲇鲞鲴鲺鲼鳊鳋鳘鳙鞒鞴齄丢并乱亘亚汲夫伫布占徊并来仑侣局俣系侠伥俩仓个们幸仿伦伟侧侦咱伪杰伧伞备家佣偬传伛债伤倾偻仅戮佥侨仆侥偾雇价仪侬亿当侩俭傧俦侪尽偿优储俪罗傩傥俨凶兑儿兖内两册胄幂净冻凛凯别删刭则克刹刚剥剐剀创铲划剧刘刽刿剑剂匡劲动勖务勋胜劳势积剿劢励劝匀匦汇匮区协恤却厍厌厉厣参丛寸吴呐吕尺呙员呗念问哑启衔唤丧吃乔单哟呛啬吗呜唢哔叹喽呕啧尝唛哗唠啸叽哓呒恶嘘哒哝哕嗳哙喷吨当咛吓哜噜啮咽呖咙向喾严嘤啭嗫嚣冁呓罗苏嘱囱囵国围园圆图团垧垭执坚垩埚尧报场碱块茔垲埘涂坞埙尘堑垫墒坠堕坟墙垦坛埙压垒圹垆坏垄坜坝壮壶寿够梦夹奂奥奁夺奋妆你姗奸侄娱娄妇娅娲妫媪妈妪妩娴娆婵娇嫱袅嫒嬷嫔婴婶娘娈孙学孪宫寝实宁审写宽宠宝将专寻对导尴届屉扉屡层屦属冈迢岘岛峡崃岗仑岽峥嵛岚岩嵝崭岖崂峤峄嵘岭屿岳岿漓峦巅岩巯卺帅师帐带帧帏帼帻帜币帮帱干几仄库厕厢厩厦厨厮庙厂庑废广廪庐痈厅弑吊弪张强别弹强弥弯汇彦雕佛径从徕复旁彻恒耻悦怅闷凄恶恼恽恻爱惬悫怆恺忾栗殷态愠惨惭恸惯怄怂虑悭庆戚忧惫怜凭愦惮愤悯怃宪忆恳应怿檩蒙怼懑恹惩懒怀悬忏惧慑恋戆钺戋戗戬战戏户仂叉扦抵拚擦殒曳抛局挟扞舍扪卷扫抡挣挂采拣扬换挥背构损摇捣擀抢掴掼搂挚抠抟掺捞撑挠捻挢掸掸拨抚扑揿挞挝捡拥掳择击挡担据挤捣拟摈拧搁掷扩撷摆擞撸扰摅撵拢拦撄搀撺携摄攒挛摊搅揽考败叙敌数敛毙斓斩断旗时晋昼曦晕晖阳畅暂昵了晔历昙晓暧旷晒书会胧术圬东栀拐栅杆栀条枭弃枨枣栋栈栖桠杨枫桢业极干杩荣桤盘构枪杠椠椁桨桩乐枞梁楼标枢样朴树桦桡桥机椭横檩柽档桧检樯台槟柠槛柜橹榈栉椟橼栎橱槠栌枥榇栊榉棂樱栏权椤栾榄棂钦叹欧欤欢岁历归殁残殒殇殚殓殡歼杀壳毁殴毋球毵毡氇气氢氩氲泛丸泛污决没冲况泄汹里浃泾凉凄泪渌净沦渊涞浅涣减涡测浑凑浈涌汤沩准沟温湿沧灭涤荥沪滞渗卤浒滚满渔沤汉涟渍涨渐浆颍泼洁潜泻润浔溃滗涠涩浇涝涧渑泽泶浍淀浊浓湿泞蒙济涛滥潍滨溅泺滤滢渎泻渖浏濒泸沥潇潆泷濑弥潋澜沣滠洒漓滩灏湾滦灾为乌烃无炼炜烟茕焕烦炀荧炝热炽烨焰灯炖磷烧烫焖营灿毁烛烩烬焘烁炉烂争爷尔墙牍瘪抵牵荦犁犊牺状狭狈狰犹狲狱狮奖独狯猃猕狞获猎犷兽獭献猕猡兹珏佩现珐珲玮琐瑶莹玛琅琏玑瑷环玺琼珑璎镶瓒瓯瓮产苏亩毕画畲异当畴叠痱痉酸麻麻痹疯疡痪瘗疮疟瘘疗痨痫瘅疠瘪痴痒疖症癞癣瘿瘾痈瘫癫发皑疱皲皱隳盗盏尽监盘卢荡眦众困睁睐睾眯瞒了睑蒙胧瞩矫炮朱硖砗砚硕砀确码砖碜碛矶硗础碍矿砺砾矾砻祆只佑秘禄祸祯御禅礼祢祷秃籼税秆棱禀种称谷稣积颖穑秽稳获窝洼穷窑窭窥窜窍窦窃竞筇笔笋笕箅个笺筝节范筑箧筱笃筛筚箦篓蓑箪简篑箫檐签帘篮筹藤箨籁笼签龠笾簖篱箩吁粤糁粪馍粮团粝籴粜纠纪纣约红纡纥纨纫纹纳纽纾纯纰纱纸级纷纭纺细绂绁绅绍绀绋绐绌终弦组绊绗结绝绦绞络绚给绒统丝绦绢绑绡绠绨绥经综缍绿绸绻绶维绾纲网缀彩纶绺绮绽绰绫绵绲缁紧绯绪缃缄缂线缉缎缔缗缘缌编缓缅纬缑缈练缏缇致萦缙缢缒绉缣绦缚缜缟缛县缝缡缩演纵缧缚纤缦絷缕缥总绩绷缫缪襁缯织缮缭绕绣缋绳绘系茧缳缲缴绎继缤缱缬纩续累缠缨才纤缵缆钵坛罂罚骂罢罗罴羁芈羟羡义习翘端耧圣闻联聪声耸聩聂职聍听聋肃胁脉胫唇睃修脱胀肾脶脑肿脚肠腽肤胶腻胆脍脓脸脐膑腊胪脏脔卧临台与兴举旧舱橹舣舰舻艰艳艹苄刍苎苟兹荆庄茎荚苋华庵苌莱万莴叶荭着苇药荤莳莅苍荪盖莲苁荜菱卜蒌蒋葱茑荫荨蒇荞芸莸荛蒉荡芜萧蓣荟蓟芗姜蔷莶荐槁萨荠蓝荩艺药薮苈薯蔼蔺蕲芦苏蕴苹蘖藓蔹茏兰蓠萝处虚虏号亏蛱蜕蚬蚀虾蜗蛳蚂萤蝼蛰蝈虮蝉蛲虫蛏蚁蝇虿蛴蝾蚝蜡蛎蛊蚕蛮蔑术卫冲只衮袅里补装里制复裤裢褛亵袄裣裆褴袜摆衬袭核见规觅视觇觋觎亲觊觏觐觑觉览觌观筋觞觯触订讣计讯讧讨讦训讪讫托记讹讶讼欣诀讷访设许诉诃诊注证诂诋讵诈诒诏评诎诅词咏诩询诣试诗诧诟诡诠诘话该详诜诙诖诔诛诓夸志认诳诶诞诱诮语诚诫诬误诰诵诲说谁课谇诽谊调谄谆谈诿请诤诹诼谅论谂谀谍谝诨谔谛谐谏谕谘讳谙谌讽诸谚谖诺谋谒谓誊诌谎谜谧谑谡谤谦谥讲谢谣谟谪谬讴谨谩证谲讥谮识谯谭谱噪谵译议谴护誉读变雠谗让谰谶赞谠谳岂竖丰艳猪狸猫贝贞负财贡贫货贩贪贯责贮贳赀贰贵贬买贷贶费贴贻贸贺贲赂赁贿赅资贾贼赈赊宾赇赉赐赏赔赓贤卖贱赋赕质账赌赖赚赙购赛赜贽赘赠赞赡赢赆赃赎赝赣赶赵趋趱迹局践蜷碰踊跄跸跖蹒踪跷趸踌跻跃踯跞踬蹰跹蹑蹿躜躏躯车轧轨军轩轫轭软轸轴轵轺轲轶轼较辂辁载轾辄挽辅轻辆辎辉辋辍辊辇辈轮辑辏输辐辗舆毂辖辕辘转辙轿辚轰辔轹轳办辞辫辩农迤回乃迳这连周进游运过达违遥逊递远适迟迁选遗辽迈还迩边逻逦合郏邮郓乡邹邬郧邓郑邻郸邺郐邝郦腌丑酝医酱酿衅酾酽释厘钆钇钌钊钉钋针钓钐扣钏钒钎钗钍钕钯钫钭钠钝钤钣钞钮钧钙钬钛钪铌铈钶铃钴钹铍钰钸铀钿钾钜钻铊铉刨铋铂钳铆铅钺钩钲钼钽铰铒铬铪银铳铜铣铨铢铭铫衔铑铷铱铟铵铥铕铯铐焊锐销锈锑锉铝锒锌钡铤铗锋锊锓锄锔锇铺铖锆锂铽锯钢锞录锖锩锥锕锟锤锱铮锛锬锭钱锦锚锡锢错锰表铼钔锴链锅镀锷铡锻锸锲锹锾键锶锗锺镁镑熔锁枪镉钨蓥镏铠铩锼镐镇镒镍镓镞镟链镆镙镝铿锵镗镘镛铲镜镖镂錾铧镤镪锈铙铣铴镣铹镦镡钟镫镨镄镌镰镯镭铁铎铛钽镱铸镬镔监鉴铄镳刨镧钥镶镊锣钻銮凿长门闩闪闫闭开闶闳闰闲闲间闵闸阂阁合阀闺闽阃阆闾阅阊阉阎阏阍阈阌阒板闱阔阕阑阗阖阙闯关阚阐辟闼厄址陉陕陕阵阴陈陆阳堤陧队阶陨际随险隐陇隶只隽虽双雏杂鸡离难云电沾溜雾霁雳霭灵靓静腼靥巩秋缰鞑千鞯韦韧韩韪韬韫韵响页顶顷项顺顸须顼颂颀颃预顽颁顿颇领颌颉颐颏头颊颔颈颓频颗题额颚颜颛愿颡颠类颟颢顾颤显颦颅颞颧风飑飒台刮飓扬飕飘飙飞饥饨饪饫饬饭饮饴饲饱饰饺饼饷养饵饽馁饿余肴馄饯馅馆饧喂饩馈馏馊馍馒馐馑馈馔饥饶飨餍馋马驭冯驮驰驯驳驻驽驹驵驾骀驸驶驼驷骈骇骆骏骋骓骒骑骐骛骗骞骘骝腾驺骚骟骡蓦骜骖骠骢驱骅骁骣骄验惊驿骤驴骧骥骊肮髅脏体髌髋发松胡须鬓斗闹哄阋阄郁魉魇鱼鲁鲂鱿鲐鲍鲋鲒鲕鲔鲛鲑鲜鲧鲠鲩鲤鲨鲻鲭鲷鲱鲵鲲鲳鲸鲮鲰鲶鲫鲽鳇鳅鳆鳃鲥鳏鳎鳐鳍鲢鳌鳓鲦鲣鳗鳔鳕鳖鳟鳝鳜鳞鲟鲎鳢鲚鳄鲈鲡鸟凫鸠凤鸣鸢鸩鸨鸦鸵鸳鸲鸱鸪鸯鸭鸸鸹鸿鸽鸺鹃鹆鹁鹈鹅鹄鹉鹌鹏鹎鹊鸫鹑鹕鹗鹜莺骞鹤鹘鹣鹚鹞鹧鸥鸷鹨鸶鹪鹩鹫鹇鹇鹬鹰鹭鸬鹦鹳鹂鸾卤咸鹾硷盐丽麦麸面麽黄黉点党黪霉黩黾鼋鳌鼍冬鼹齐斋齑齿龀龅龇龃龆龄出龈啮龊龉龋龌龙庞龚龛龟"

    private let big5Codes = "锕皚藹礙愛嗳嫒瑷暧霭谙铵鹌肮襖奧媪骜鳌壩罷钯擺敗呗頒辦絆钣幫綁鎊謗剝飽寶報鮑鸨龅輩貝鋇狽備憊鹎贲锛繃筆畢斃幣閉荜哔滗铋筚跸邊編貶變辯辮苄缏邊標骠飑飙镖镳鳔鼈別癟瀕濱賓擯傧缤槟殡膑镔髌鬓餅禀撥缽鉑駁饽钹鹁補钸財參蠶殘慚慘燦骖黪蒼艙倉滄廁側冊測測層詫锸侪钗攙摻蟬饞讒纏鏟産闡顫冁谄谶蒇忏婵骣觇禅镡場嘗長償腸廠暢伥苌怅阊鲳鈔車徹砗塵陳襯伧谌榇碜龀撐稱懲誠騁枨柽铖铛癡遲馳恥齒熾饬鸱沖沖蟲寵铳疇躊籌綢俦疇雠櫥廚鋤雛礎儲觸處刍礎蹰傳钏瘡闖創怆錘缍純鹑綽辍龊辭詞賜鹚聰蔥囪從叢從骢縱湊辏躥竄撺錯锉鹾達哒鞑帶貸骀绐擔單鄲撣膽憚誕彈殚赕瘅箪當擋黨蕩檔谠砀裆搗島禱導盜焘燈鄧镫敵滌遞締籴诋谛绨觌镝顛點墊電巅钿癫釣調铫鲷諜疊鲽釘頂錠訂铤丟铥東動棟凍凍鸫窦犢獨讀賭鍍犢椟牍笃黩鍛斷緞簖兌隊對對镦噸頓鈍炖趸奪墮铎鵝額訛惡餓谔垩阏轭锇锷鹗颚颛鳄诶兒爾餌貳迩铒鸸鲕發罰閥琺礬釩煩販飯訪紡钫鲂飛誹廢費绯镄鲱紛墳奮憤糞偾豐楓鋒風瘋馮縫諷鳳沣膚輻撫輔賦複負訃婦縛凫驸绂绋赙麸鲋鳆钆該鈣蓋赅杆趕稈贛尴擀绀岡剛鋼綱崗戆鎬睾诰缟锆擱鴿閣鉻個纥镉颍給亘赓绠鲠龔宮鞏貢鈎溝苟構購夠诟缑觏蠱顧估毂沽锢鸪鹄鹘剮挂鸹掴關觀館慣貫诖掼鹳鳏廣犷規歸龜閨軌詭貴劊軌刿妫桧鲑鳜輥滾衮绲鲧鍋國過埚呙帼椁蝈哈駭韓漢阚绗颉號灏颢閡鶴賀诃阖蛎橫轟鴻紅黉讧荭闳鲎壺護滬戶浒鹕嘩華畫劃話骅桦铧懷壞歡環還緩換喚瘓煥渙奂缳锾鲩黃謊鳇揮輝毀賄穢會燴彙諱誨繪诙荟哕會缋珲晖葷渾诨馄阍獲貨禍夥獲擊機積饑迹譏雞績緝極輯級擠幾薊劑濟計記際繼紀讦诘荠叽擠骥玑觊齑矶羁虿跻霁鲚鲫夾莢頰賈鉀價駕郏浃铗镓蛲殲監堅箋間艱緘繭檢堿鹼揀撿簡儉減薦檻鑒踐賤見鍵艦劍餞漸濺澗谏缣戋戬睑鹣笕鲣鞯將漿蔣槳獎講醬绛缰膠澆驕嬌攪鉸矯僥腳餃繳絞轎較挢峤鹪鲛階節潔結誡屆疖颌鲒緊錦僅謹進晉燼盡勁荊莖卺荩馑缙赆觐鯨驚經頸靜鏡徑痙競淨刭泾迳弪胫靓糾廄舊阄鸠鹫駒舉據鋸懼劇讵屦榉飓钜锔窭龃鵑絹锩镌隽覺決絕谲珏鈞軍駿皲開凱凱垲忾恺铠锴龛闶钪铐顆殼課骒缂轲钶锞颔墾懇龈铿摳庫褲喾塊儈郐哙脍寬狯髋礦曠況诓诳邝圹礦贶虧巋窺饋潰匮蒉愦聩篑阃锟鲲擴闊蛴蠟臘萊來賴崃徕涞濑赉睐铼癞籁藍欄攔籃闌蘭瀾讕攬覽懶纜爛濫岚榄斓镧褴琅阆锒撈勞澇唠撈铑铹痨樂鳓鐳壘類淚诔缧籬狸離鯉禮麗厲勵礫曆瀝隸俪郦坜苈位離曆逦骊缡枥栎轹砺锂鹂厲粝躍雳鲡鳢倆聯蓮連鐮憐漣簾斂臉鏈戀煉練蔹奁斂琏殓裢裣鲢糧涼兩輛諒魉療遼鐐缭钌鹩獵臨鄰鱗凜賃蔺廪檩辚躏齡鈴靈嶺領绫棂蛏鲮餾劉浏骝绺镏鹨龍聾嚨籠壟攏隴嚨壟珑栊胧砻樓婁摟簍偻蒌喽摟镂瘘耧蝼髅蘆盧顱廬爐擄鹵虜魯賂祿錄陸垆撸魯闾泸渌栌橹轳辂辘氇胪鸬鹭舻鲈巒攣孿灤亂脔娈栾鸾銮掄輪倫侖淪綸論掄蘿羅邏鑼籮騾駱絡荦猡樂椤脶镙驢呂鋁侶屢縷慮濾綠榈褛锊呒媽瑪碼螞馬罵嗎唛嬷杩買麥賣邁脈劢瞞饅蠻滿謾缦镘颡鳗貓錨鉚貿麽沒鎂門悶們扪焖懑钔錳夢眯謎彌覓冪芈谧猕祢綿緬渑腼黾廟缈缪滅憫閩闵缗鳴銘謬谟蓦馍殁镆謀畝钼呐鈉納難撓腦惱鬧铙讷餒內擬膩铌鲵攆辇鲶釀鳥鳥袅聶齧鑷鎳陧蘖聶颟蹑檸獰甯擰濘苎咛聍鈕紐膿濃農侬膿驽钕諾傩瘧歐鷗毆嘔漚讴怄歐盤蹒龐抛疱賠辔噴鵬批罴铍騙谝骈飄缥頻貧嫔蘋憑評潑頗钋撲鋪樸譜镤镨棲臍齊騎豈啓氣棄訖薪骐绮桤碛颀颃鳍牽釺鉛遷簽謙錢鉗潛淺譴塹佥荨悭骞缱椠钤槍嗆牆薔強搶牆樯戗炝锖锵镪羟跄鍬橋喬僑翹竅诮谯荞缲硗跷竊惬锲箧欽親寢浸輕氫傾頃請慶揿鲭瓊窮茕蛱巯赇虮鳅趨區軀驅齲诎區阒觑鸲顴權勸诠绻辁铨卻鵲確阕阙悫讓饒擾繞荛娆桡熱韌認紉饪轫榮絨嵘蝾缛铷颦軟銳蚬閏潤灑薩飒鰓賽傘毵糁喪騷掃缫澀啬铯穑殺刹紗铩鲨篩曬酾刪閃陝贍繕讪姗骟钐鳝墒傷賞垧殇觞燒紹賒攝懾設厍滠畲紳審嬸腎滲诜谂渖聲繩勝師獅濕詩時蝕實識駛勢適釋飾視試益埘莳弑轼贳铈鲥壽獸绶樞輸書贖屬術樹豎數摅纾帥闩雙誰稅順說碩爍铄絲飼厮驷缌锶鸶聳慫頌訟誦擻數馊飕锼蘇訴肅谡稣雖隨綏歲谇孫損筍荪狲縮瑣鎖唢睃獺撻闼铊鳎台態钛鲐攤貪癱灘壇譚談歎昙坦锬顸湯燙傥湯铴镗濤縧討韬铽騰謄銻題體屜缇鹈阗條粜龆鲦貼鐵廳聽烴銅統恸頭钭禿圖钍團專頹蛻饨脫鴕馱駝橢箨鼍襪娲腽彎灣頑萬纨绾網辋韋違圍爲濰維葦偉僞緯謂衛诿帏闱僞涠玮韪炜鲔溫聞紋穩問阌甕撾蝸渦窩臥莴龌嗚鎢烏誣無蕪吳塢霧務誤邬庑怃妩骛鹉鹜錫犧襲習銑戲細饩阋玺觋蝦轄峽俠狹廈嚇硖鮮纖賢銜閑顯險現獻縣餡羨憲線苋莶藓岘猃閑鹇痫蚝籼跹廂鑲鄉詳響項鄉饷骧缃飨蕭囂銷曉嘯曉潇骁绡枭箫協挾攜脅諧寫瀉謝亵撷泄缬鋅釁興陉荥凶洶鏽繡馐鸺虛噓須許敘緒續诩顼軒懸選癬絢谖铉镟學谑泶鳕勳詢尋馴訓訊遜埙尋鲟壓鴉鴨啞亞訝垭娅桠氩閹煙鹽嚴岩顔閻豔厭硯彥諺驗厣赝俨兖谳恹闫酽魇餍鼹鴦楊揚瘍陽癢養樣炀瑤搖堯遙窯謠藥轺鹞鳐爺頁業葉靥谒邺晔烨醫銥頤遺儀蟻藝億憶義詣議誼譯異繹诒呓峄饴怿驿缢轶贻钇镒镱瘗舣蔭陰銀飲隱铟瘾櫻嬰鷹應纓瑩螢營熒蠅贏穎茔莺萦蓥撄嘤滢潆櫻鹦瘿颏罂喲擁傭癰踴詠镛優憂郵鈾猶誘莸铕鱿輿魚漁娛與嶼語獄譽預馭伛俣谀谕蓣嵛饫阈妪于觎欤钰鹆鹬龉鴛淵轅園員圓緣遠橼鸢鼋約躍鑰粵悅閱钺鄖勻隕運蘊醞暈韻郓芸恽愠纭韫隕氲雜災載攢暫贊攢趱錾贓髒驵鑿棗責擇則澤赜啧帻箦賊谮贈綜缯軋鍘閘柵詐齋債氈盞斬輾嶄棧戰綻谵張漲帳賬脹趙诏钊蟄轍鍺這谪辄鹧貞針偵診鎮陣貞缜桢轸赈祯鸩掙睜猙爭幀症鄭證诤峥钲铮筝織職執紙摯擲幟質滯骘栉栀職轾贽鸷蛳絷踬踯觯鍾終種腫衆锺謅軸皺晝驟纣绉豬諸誅燭矚囑貯鑄駐伫槠铢專磚轉賺轉馔颞樁莊裝妝壯狀錐贅墜綴骓缒諄准著濁诼镯茲資漬谘缁辎赀眦锱龇鲻蹤總縱偬鄒诹驺鲰詛組镞鑽缵躜鳟翺並蔔沈醜澱叠鬥範幹臯矽櫃後夥稭傑訣誇裏淩麽黴撚淒扡聖屍擡塗窪喂汙鍁鹹蠍彜湧遊籲禦願嶽雲竈紮劄築于志注凋讠谫郄勐凼坂垅垴埯埝苘買荮莜莼菰藁揸吒吣咔咝咴噘霹嚯幞岙嵴彷徼瑪狍馀馇馓馕愣憷懔丬敘豔溷婪潴澹甯纟绔绱珉枧桊桉槔橥轱轷赍肷胨飚葫煅熘愍淼砜磙眍钚钷铘吊锃锍锎锏锘锝锪锫锿镅镎镢镥镩察稆鹋鹛鹱疬疴痖癯裥襁耢颥螨麴鲅鲆鲇鲞鲴鲺鲼鳊鳋鳘鳙鞒鞴齄丟並亂亙亞伋伕佇佈佔佪併來侖侶侷俁係俠倀倆倉個們倖倣倫偉側偵偺偽傑傖傘備傢傭傯傳傴債傷傾僂僅僇僉僑僕僥僨僱價儀儂億儅儈儉儐儔儕儘償優儲儷儸儺儻儼兇兌兒兗內兩冊冑冪凈凍凜凱別刪剄則剋剎剛剝剮剴創剷劃劇劉劊劌劍劑劻勁動勗務勛勝勞勢勣勦勱勵勸勻匭匯匱區協卹卻厙厭厲厴參叢吋吳吶呂呎咼員唄唸問啞啟啣喚喪喫喬單喲嗆嗇嗎嗚嗩嗶嘆嘍嘔嘖嘗嘜嘩嘮嘯嘰嘵嘸噁噓噠噥噦噯噲噴噸噹嚀嚇嚌嚕嚙嚥嚦嚨嚮嚳嚴嚶囀囁囂囅囈囉囌囑囪圇國圍園圓圖團坰埡執堅堊堝堯報場堿塊塋塏塒塗塢塤塵塹墊墑墜墮墳墻墾壇壎壓壘壙壚壞壟壢壩壯壺壽夠夢夾奐奧奩奪奮妝妳姍姦姪娛婁婦婭媧媯媼媽嫗嫵嫻嬈嬋嬌嬙嬝嬡嬤嬪嬰嬸孃孌孫學孿宮寢實寧審寫寬寵寶將專尋對導尷屆屜屝屢層屨屬岡岧峴島峽崍崗崙崠崢崳嵐嵒嶁嶄嶇嶗嶠嶧嶸嶺嶼嶽巋巑巒巔巖巰巹帥師帳帶幀幃幗幘幟幣幫幬幹幾庂庫廁廂廄廈廚廝廟廠廡廢廣廩廬廱廳弒弔弳張強彆彈彊彌彎彙彥彫彿徑從徠復徬徹恆恥悅悵悶悽惡惱惲惻愛愜愨愴愷愾慄慇態慍慘慚慟慣慪慫慮慳慶慼憂憊憐憑憒憚憤憫憮憲憶懇應懌懍懞懟懣懨懲懶懷懸懺懼懾戀戇戉戔戧戩戰戲戶扐扠扢扺抃抆抎抴拋挶挾捍捨捫捲掃掄掙掛採揀揚換揮揹搆損搖搗搟搶摑摜摟摯摳摶摻撈撐撓撚撟撢撣撥撫撲撳撻撾撿擁擄擇擊擋擔據擠擣擬擯擰擱擲擴擷擺擻擼擾攄攆攏攔攖攙攛攜攝攢攣攤攪攬攷敗敘敵數斂斃斕斬斷旂時晉晝晞暈暉暘暢暫暱暸曄曆曇曉曖曠曬書會朧朮杇東枙枴柵桿梔條梟棄棖棗棟棧棲椏楊楓楨業極榦榪榮榿槃構槍槓槧槨槳樁樂樅樑樓標樞樣樸樹樺橈橋機橢橫檁檉檔檜檢檣檯檳檸檻櫃櫓櫚櫛櫝櫞櫟櫥櫧櫨櫪櫬櫳櫸櫺櫻欄權欏欒欖欞欽歎歐歟歡歲歷歸歿殘殞殤殫殮殯殲殺殼毀毆毌毬毿氈氌氣氫氬氳氾汍汎汙決沒沖況洩洶浬浹涇涼淒淚淥淨淪淵淶淺渙減渦測渾湊湞湧湯溈準溝溫溼滄滅滌滎滬滯滲滷滸滾滿漁漚漢漣漬漲漸漿潁潑潔潛潟潤潯潰潷潿澀澆澇澗澠澤澩澮澱濁濃濕濘濛濟濤濫濰濱濺濼濾瀅瀆瀉瀋瀏瀕瀘瀝瀟瀠瀧瀨瀰瀲瀾灃灄灑灕灘灝灣灤災為烏烴無煉煒煙煢煥煩煬熒熗熱熾燁燄燈燉燐燒燙燜營燦燬燭燴燼燾爍爐爛爭爺爾牆牘牪牴牽犖犛犢犧狀狹狽猙猶猻獄獅獎獨獪獫獮獰獲獵獷獸獺獻獼玀玆玨珮現琺琿瑋瑣瑤瑩瑪瑯璉璣璦環璽瓊瓏瓔瓖瓚甌甕產甦畝畢畫畬異當疇疊疿痙痠痲痳痺瘋瘍瘓瘞瘡瘧瘺療癆癇癉癘癟癡癢癤癥癩癬癭癮癰癱癲發皚皰皸皺皻盜盞盡監盤盧盪眥眾睏睜睞睪瞇瞞瞭瞼矇矓矚矯砲硃硤硨硯碩碭確碼磚磣磧磯磽礎礙礦礪礫礬礱祅祇祐祕祿禍禎禦禪禮禰禱禿秈稅稈稜稟種稱穀穌積穎穡穢穩穫窩窪窮窯窶窺竄竅竇竊競笻筆筍筧箄箇箋箏節範築篋篠篤篩篳簀簍簑簞簡簣簫簷簽簾籃籌籐籜籟籠籤籥籩籪籬籮籲粵糝糞糢糧糰糲糴糶糾紀紂約紅紆紇紈紉紋納紐紓純紕紗紙級紛紜紡細紱紲紳紹紺紼紿絀終絃組絆絎結絕絛絞絡絢給絨統絲絳絹綁綃綆綈綏經綜綞綠綢綣綬維綰綱網綴綵綸綹綺綻綽綾綿緄緇緊緋緒緗緘緙線緝緞締緡緣緦編緩緬緯緱緲練緶緹緻縈縉縊縋縐縑縚縛縝縞縟縣縫縭縮縯縱縲縳縴縵縶縷縹總績繃繅繆繈繒織繕繚繞繡繢繩繪繫繭繯繰繳繹繼繽繾纈纊續纍纏纓纔纖纘纜缽罈罌罰罵罷羅羆羈羋羥羨義習翹耑耬聖聞聯聰聲聳聵聶職聹聽聾肅脅脈脛脣脧脩脫脹腎腡腦腫腳腸膃膚膠膩膽膾膿臉臍臏臘臚臟臠臥臨臺與興舉舊艙艣艤艦艫艱艷艸芐芻苧茍茲荊莊莖莢莧華菴萇萊萬萵葉葒著葦葯葷蒔蒞蒼蓀蓋蓮蓯蓽蔆蔔蔞蔣蔥蔦蔭蕁蕆蕎蕓蕕蕘蕢蕩蕪蕭蕷薈薊薌薑薔薟薦薧薩薺藍藎藝藥藪藶藷藹藺蘄蘆蘇蘊蘋蘗蘚蘞蘢蘭蘺蘿處虛虜號虧蛺蛻蜆蝕蝦蝸螄螞螢螻蟄蟈蟣蟬蟯蟲蟶蟻蠅蠆蠐蠑蠔蠟蠣蠱蠶蠻衊術衛衝衹袞裊裏補裝裡製複褲褳褸褻襖襝襠襤襪襬襯襲覈見規覓視覘覡覦親覬覯覲覷覺覽覿觀觔觴觶觸訂訃計訊訌討訐訓訕訖託記訛訝訟訢訣訥訪設許訴訶診註証詁詆詎詐詒詔評詘詛詞詠詡詢詣試詩詫詬詭詮詰話該詳詵詼詿誄誅誆誇誌認誑誒誕誘誚語誠誡誣誤誥誦誨說誰課誶誹誼調諂諄談諉請諍諏諑諒論諗諛諜諞諢諤諦諧諫諭諮諱諳諶諷諸諺諼諾謀謁謂謄謅謊謎謐謔謖謗謙謚講謝謠謨謫謬謳謹謾證譎譏譖識譙譚譜譟譫譯議譴護譽讀變讎讒讓讕讖讚讜讞豈豎豐豔豬貍貓貝貞負財貢貧貨販貪貫責貯貰貲貳貴貶買貸貺費貼貽貿賀賁賂賃賄賅資賈賊賑賒賓賕賚賜賞賠賡賢賣賤賦賧質賬賭賴賺賻購賽賾贄贅贈贊贍贏贐贓贖贗贛趕趙趨趲跡跼踐踡踫踴蹌蹕蹠蹣蹤蹺躉躊躋躍躑躒躓躕躚躡躥躦躪軀車軋軌軍軒軔軛軟軫軸軹軺軻軼軾較輅輇載輊輒輓輔輕輛輜輝輞輟輥輦輩輪輯輳輸輻輾輿轂轄轅轆轉轍轎轔轟轡轢轤辦辭辮辯農迆迴迺逕這連週進遊運過達違遙遜遞遠適遲遷選遺遼邁還邇邊邏邐郃郟郵鄆鄉鄒鄔鄖鄧鄭鄰鄲鄴鄶鄺酈醃醜醞醫醬釀釁釃釅釋釐釓釔釕釗釘釙針釣釤釦釧釩釬釵釷釹鈀鈁鈄鈉鈍鈐鈑鈔鈕鈞鈣鈥鈦鈧鈮鈰鈳鈴鈷鈸鈹鈺鈽鈾鈿鉀鉅鉆鉈鉉鉋鉍鉑鉗鉚鉛鉞鉤鉦鉬鉭鉸鉺鉻鉿銀銃銅銑銓銖銘銚銜銠銣銥銦銨銩銪銫銬銲銳銷銹銻銼鋁鋃鋅鋇鋌鋏鋒鋝鋟鋤鋦鋨鋪鋮鋯鋰鋱鋸鋼錁錄錆錈錐錒錕錘錙錚錛錟錠錢錦錨錫錮錯錳錶錸鍆鍇鍊鍋鍍鍔鍘鍛鍤鍥鍬鍰鍵鍶鍺鍾鎂鎊鎔鎖鎗鎘鎢鎣鎦鎧鎩鎪鎬鎮鎰鎳鎵鏃鏇鏈鏌鏍鏑鏗鏘鏜鏝鏞鏟鏡鏢鏤鏨鏵鏷鏹鏽鐃鐉鐋鐐鐒鐓鐔鐘鐙鐠鐨鐫鐮鐲鐳鐵鐸鐺鐽鐿鑄鑊鑌鑑鑒鑠鑣鑤鑭鑰鑲鑷鑼鑽鑾鑿長門閂閃閆閉開閌閎閏閑閒間閔閘閡閣閤閥閨閩閫閬閭閱閶閹閻閼閽閾閿闃闆闈闊闋闌闐闔闕闖關闞闡闢闥阨阯陘陜陝陣陰陳陸陽隄隉隊階隕際隨險隱隴隸隻雋雖雙雛雜雞離難雲電霑霤霧霽靂靄靈靚靜靦靨鞏鞦韁韃韆韉韋韌韓韙韜韞韻響頁頂頃項順頇須頊頌頎頏預頑頒頓頗領頜頡頤頦頭頰頷頸頹頻顆題額顎顏顓願顙顛類顢顥顧顫顯顰顱顳顴風颮颯颱颳颶颺颼飄飆飛飢飩飪飫飭飯飲飴飼飽飾餃餅餉養餌餑餒餓餘餚餛餞餡館餳餵餼餽餾餿饃饅饈饉饋饌饑饒饗饜饞馬馭馮馱馳馴駁駐駑駒駔駕駘駙駛駝駟駢駭駱駿騁騅騍騎騏騖騙騫騭騮騰騶騷騸騾驀驁驂驃驄驅驊驍驏驕驗驚驛驟驢驤驥驪骯髏髒體髕髖髮鬆鬍鬚鬢鬥鬧鬨鬩鬮鬱魎魘魚魯魴魷鮐鮑鮒鮚鮞鮪鮫鮭鮮鯀鯁鯇鯉鯊鯔鯖鯛鯡鯢鯤鯧鯨鯪鯫鯰鯽鰈鰉鰍鰒鰓鰣鰥鰨鰩鰭鰱鰲鰳鰷鰹鰻鰾鱈鱉鱒鱔鱖鱗鱘鱟鱧鱭鱷鱸鱺鳥鳧鳩鳳鳴鳶鴆鴇鴉鴕鴛鴝鴟鴣鴦鴨鴯鴰鴻鴿鵂鵑鵒鵓鵜鵝鵠鵡鵪鵬鵯鵲鶇鶉鶘鶚鶩鶯鶱鶴鶻鶼鶿鷂鷓鷗鷙鷚鷥鷦鷯鷲鷳鷴鷸鷹鷺鸕鸚鸛鸝鸞鹵鹹鹺鹼鹽麗麥麩麵麼黃黌點黨黲黴黷黽黿鼇鼉鼕鼴齊齋齏齒齔齙齜齟齠齡齣齦齧齪齬齲齷龍龐龔龕龜"

    lazy var cache = Cache<String, (fulls: [String], firsts: [String])>()

    lazy var pinyins: [String: [String]] = {
        let parent = Bundle(for: PinYin.self)
        let bundlePath = parent.path(forResource: "PinYin.bundle", ofType: nil) ?? ""
        let bundle = Bundle(path: bundlePath)
        let path = bundle?.path(forResource: "pinyin.plist", ofType: nil) ?? ""
        var _polyphones = (NSDictionary(contentsOfFile: path) as? [String: [String]]) ?? [:]
        return _polyphones
    }()

    lazy var hanzi2pinyins: [String: [String]] = {
        let parent = Bundle(for: PinYin.self)
        let bundlePath = parent.path(forResource: "PinYin.bundle", ofType: nil) ?? ""
        let bundle = Bundle(path: bundlePath)
        let path = bundle?.path(forResource: "hanzi2pinyin.plist", ofType: nil) ?? ""
        var _polyphones = (NSDictionary(contentsOfFile: path) as? [String: [String]]) ?? [:]
        return _polyphones
    }()

    lazy var gb2big5Map: [String: String] = {
        let count = gbCodes.count
        var map: [String: String] = [:]
        for i in 0 ..< count {
            let k = String(gbCodes[gbCodes.index(gbCodes.startIndex, offsetBy: i)])
            let v = String(big5Codes[big5Codes.index(big5Codes.startIndex, offsetBy: i)])
            map[k] = v
        }
        return map
    }()

    lazy var big52gbMap: [String: String] = {
        let count = gbCodes.count
        var map: [String: String] = [:]
        for i in 0 ..< count {
            let k = String(big5Codes[big5Codes.index(big5Codes.startIndex, offsetBy: i)])
            let v = String(gbCodes[gbCodes.index(gbCodes.startIndex, offsetBy: i)])
            map[k] = v
        }
        return map
    }()

    lazy var trimmingSet: CharacterSet = {
        var charset = CharacterSet()
        charset.formUnion(.whitespacesAndNewlines)
        charset.formUnion(.punctuationCharacters)
        return charset
    }()

    lazy var cleanSet: CharacterSet = {
        var charset = CharacterSet()
        charset.formUnion(.controlCharacters)
        charset.formUnion(.whitespacesAndNewlines)
        charset.formUnion(.nonBaseCharacters)
        charset.formUnion(.punctuationCharacters)
        charset.formUnion(.symbols)
        charset.formUnion(.illegalCharacters)
        return charset
    }()

    lazy var numberFormatter: NumberFormatter = {
        var formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}

public extension String {
    init(bytes: [UInt8]) {
        if let s = String(bytes: bytes, encoding: .ascii) {
            self = s
        } else {
            for i in 0 ..< 30 {
                let encoding = String.Encoding(rawValue: UInt(i))
                if let s = String(bytes: bytes, encoding: encoding) {
                    self = s
                    break
                }
            }
        }
        self = ""
    }

    /// 是否包含汉字
    var hasChinese: Bool {
        let regex = ".*[\\u4e00-\\u9fa5].*"
        let predicate = NSPredicate(format: "SELF MATCHES \(regex)")
        return predicate.evaluate(with: self)
    }

    var decoded: (bytes: [UInt8], encoding: String.Encoding) {
        if let bytes = cString(using: .utf8) {
            return (bytes.map { UInt8($0) }, .utf8)
        }
        for i in 0 ..< 30 {
            let encoding = String.Encoding(rawValue: UInt(i))
            if let bytes = cString(using: encoding) {
                return (bytes.map { UInt8($0) }, encoding)
            }
        }
        return ([], .ascii)
    }

    var simplified: String {
        var string = ""
        for i in 0 ..< count {
            let s = String(self[index(startIndex, offsetBy: i)])
            let v = PinYin.shared.big52gbMap[s]
            string.append(v ?? s)
        }
        return string
    }

    var traditional: String {
        var string = ""
        for i in 0 ..< count {
            let s = String(self[index(startIndex, offsetBy: i)])
            let v = PinYin.shared.gb2big5Map[s]
            string.append(v ?? s)
        }
        return string
    }

    /// 拼音字符串
    var pinyin: String {
        let source = NSMutableString(string: self) as CFMutableString
        CFStringTransform(source, nil, kCFStringTransformToLatin, false)
        var dest = (source as NSMutableString) as String
        dest = dest.folding(options: .diacriticInsensitive, locale: .current)
        return dest.replacingOccurrences(of: "'", with: "")
    }

    func pinyins(at index: Int) -> (fulls: [String], firsts: [String]) {
        let string = simplified as NSString
        let ch = string.character(at: index)
        let key = String(format: "%X", ch)
        let pinyins = PinYin.shared.hanzi2pinyins[key] ?? []
        let fulls = NSMutableOrderedSet()
        let firsts = NSMutableOrderedSet()
        for pinyin in pinyins {
            if pinyin.count < 1 { continue }
            fulls.add(pinyin[pinyin.startIndex ..< pinyin.index(pinyin.startIndex, offsetBy: pinyin.count - 1)])
            firsts.add(pinyin[pinyin.startIndex ..< pinyin.index(pinyin.startIndex, offsetBy: 1)])
        }
        return (fulls.array as! [String], firsts.array as! [String])
    }

    var pinyinsForMatch: (fulls: [String], firsts: [String]) {
        if let results = PinYin.shared.cache[self] {
            return results
        }

        let pinyins = self.pinyins(at: 0)
        let letter = String(self[index(startIndex, offsetBy: 1)])
        let headFulls = pinyins.fulls.count > 0 ? pinyins.fulls : [letter]
        let headFirsts = pinyins.firsts.count > 0 ? pinyins.firsts : [letter]
        guard count > 1 else {
            return (headFulls, headFirsts)
        }
        let sub = String(self[index(startIndex, offsetBy: 1) ..< endIndex])
        let subPinyins = sub.pinyinsForMatch
        var fulls: [String] = []
        var firsts: [String] = []
        for headfull in headFulls {
            for subfull in subPinyins.fulls {
                fulls.append(headfull + subfull)
            }
        }
        for headfirst in headFirsts {
            for subfirst in subPinyins.firsts {
                firsts.append(headfirst + subfirst)
            }
        }

        let results = (fulls, firsts)
        PinYin.shared.cache[self] = results
        return results
    }

    var pinyinMatrix: (fulls: [[String]], firsts: [[String]]) {
        let pinyins = self.pinyins(at: 0)
        let letter = String(self[index(startIndex, offsetBy: 1)])
        let headFulls = pinyins.fulls.count > 0 ? [pinyins.fulls] : [[letter]]
        let headFirsts = pinyins.firsts.count > 0 ? [pinyins.firsts] : [[letter]]
        guard count > 1 else {
            return (headFulls, headFirsts)
        }
        let sub = String(self[index(startIndex, offsetBy: 1) ..< endIndex])
        let subPinyins = sub.pinyinMatrix
        var fulls: [[String]] = []
        var firsts: [[String]] = []
        for headfull in headFulls {
            for subfull in subPinyins.fulls {
                fulls.append(headfull + subfull)
            }
        }
        for headfirst in headFirsts {
            for subfirst in subPinyins.firsts {
                firsts.append(headfirst + subfirst)
            }
        }

        return (fulls, firsts)
    }

    private static var tokenFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }

    var numberTokens: [String] {
        let num = String.tokenFormatter.number(from: self)
        if num != nil {
            let unformatted = num!.stringValue
            let formatted = String.tokenFormatter.string(from: num!)!
            return [unformatted, formatted]
        }
        return []
    }

    var clean: String {
        let array = components(separatedBy: PinYin.shared.cleanSet)
        return array.joined(separator: "")
    }

    private var headPinyins: [String] {
        let bytes = decoded.bytes
        guard bytes.count > 0 else { return [] }
        let s = String(bytes[0])
        guard let array = PinYin.shared.pinyins[s], array.count > 0 else {
            return []
        }
        var results: [String] = []
        for pinyin in array {
            let subbytes = pinyin.decoded.bytes
            if bytes.count < subbytes.count {
                continue
            }
            var eq = true
            for i in 0 ..< subbytes.count {
                if bytes[i] != subbytes[i] {
                    eq = false
                    break
                }
            }
            if eq {
                results.append(pinyin)
            }
        }
        return results
    }

    private var _splitedPinyins: [[String]] {
        var results: [[String]] = []
        let heads = headPinyins
        guard heads.count > 0 else { return [] }

        for head in heads {
            let tail = String(self[index(startIndex, offsetBy: head.count) ..< endIndex])
            let tails = tail._splitedPinyins
            for pinyins in tails {
                results.append([head] + pinyins)
            }
        }
        return results
    }

    var splitedPinyins: [[String]] {
        return simplified._splitedPinyins
    }

    /// 预加载拼音分词资源
    static func preloadingForPinyin() {
        _ = "中文".pinyinsForMatch
    }
}

public extension String {
    var trim: String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var strip: String {
        return replacingOccurrences(of: " +", with: " ", options: .regularExpression)
    }

    var quoted: String {
        return quote()
    }

    func quote(_ mark: Character? = "\"") -> String {
        guard mark != nil else {
            return self
        }
        let ch = mark!
        let fix = "\(ch)"
        if hasPrefix(fix) && hasSuffix(fix) {
            return self
        }
        let escaped = reduce("") { string, character in
            string + (character == ch ? "\(ch)\(ch)" : "\(character)")
        }
        return "\(ch)\(escaped)\(ch)"
    }

    func match(_ regex: String) -> Bool {
        let r = range(of: regex, options: [.regularExpression, .caseInsensitive])
        return r != nil
    }
}

public extension Dictionary {
    static func === (lhs: Dictionary, rhs: Dictionary) -> Bool {
        guard Set(lhs.keys) == Set(rhs.keys) else {
            return false
        }
        for key in lhs.keys {
            let lvalue = lhs[key]
            let rvalue = rhs[key]
            switch (lvalue, rvalue) {
            case let (lvalue as Bool, rvalue as Bool): guard lvalue == rvalue else { return false }
            case let (lvalue as Int, rvalue as Int): guard lvalue == rvalue else { return false }
            case let (lvalue as Int8, rvalue as Int8): guard lvalue == rvalue else { return false }
            case let (lvalue as Int16, rvalue as Int16): guard lvalue == rvalue else { return false }
            case let (lvalue as Int32, rvalue as Int32): guard lvalue == rvalue else { return false }
            case let (lvalue as Int64, rvalue as Int64): guard lvalue == rvalue else { return false }
            case let (lvalue as UInt, rvalue as UInt): guard lvalue == rvalue else { return false }
            case let (lvalue as UInt8, rvalue as UInt8): guard lvalue == rvalue else { return false }
            case let (lvalue as UInt16, rvalue as UInt16): guard lvalue == rvalue else { return false }
            case let (lvalue as UInt32, rvalue as UInt32): guard lvalue == rvalue else { return false }
            case let (lvalue as UInt64, rvalue as UInt64): guard lvalue == rvalue else { return false }
            case let (lvalue as Float, rvalue as Float): guard lvalue == rvalue else { return false }
            case let (lvalue as Double, rvalue as Double): guard lvalue == rvalue else { return false }
            case let (lvalue as String, rvalue as String): guard lvalue == rvalue else { return false }
            case let (lvalue as Data, rvalue as Data): guard lvalue == rvalue else { return false }
            case (_, _):
                return false
            }
        }
        return true
    }

    mutating func removeValues(forKeys: [Key]) {
        for key in forKeys {
            removeValue(forKey: key)
        }
    }
}

public extension Array where Element: Hashable {
    static func === (lhs: Array, rhs: Array) -> Bool {
        return Set(lhs) == Set(rhs)
    }
}

public extension Array where Element: Binding {
    var sqlJoined: String {
        return map { $0.sqlValue }.joined(separator: ",")
    }
}
