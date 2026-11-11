# 探索记录

## 起点（2026-11-10）

想法：手机端只订阅 GitHub 上这一个配置文件。需要去广告时，把 [yfamilys.com/shadowrocket](https://yfamilys.com/shadowrocket) 上的模块内容融合进配置；融合不了的再自建模块，也放 GitHub 上远程更新。

## 第一轮：彩云天气

**模块内容**（[caiyun.module](https://yfamilys.com/module/caiyun.module)）：
- `[Script]`：改写 `biz.(caiyunapp|cyapi).(com|cn)/v2/user*` 的响应，伪造 Pro 会员。广告消失只是"成了会员"的副作用。脚本所在仓库 `WeiRen0/Scripts` 已 404，失效。
- `[MITM] *.caiyunapp.com, *.cyapi.com, *.cyapi.cn, *.caiyunapp.cn`：只服务于上面的脚本。
- `[URL Rewrite] ^https://ad.caiyunapp.com/ _ reject`：唯一真正的去广告规则。

**发现**：
- 这条 Rewrite 匹配整个主机，等价于 `DOMAIN,ad.caiyunapp.com,REJECT`，不需要 MITM。
- 它原本根本不生效：Loyalsoldier `direct.txt` 里有 `.caiyunapp.com`，`ad.caiyunapp.com` 被直连放行。AWAvenue 里有 `ad.cyapi.cn`，没有 `ad.caiyunapp.com`。
- blackmatrix7 Advertising 里还有 `cdn-1rtb.caiyunapp.com/creative/`（RTB 广告素材 CDN）。

**结论**：在 `direct.txt` 之前加两条 DOMAIN REJECT（commit c5d4d44）。不要会员脚本（破解付费功能，且已失效）。
如果仍有首页活动图标，可选的 MITM 规则是 `api.caiyunapp.com/v1/activity`、`wrapper.cyapi.cn/v1/activity`（来自 fmz200）。

## 第二轮：性能与"精准挑规则"

### 我的假设

部分规则是哈希匹配（快），部分是字符串/正则匹配（每次请求都要跑一遍）。用"去开屏广告融合版"后掉电明显变快，说明大量匹配耗电。所以只挑日常 App 的开屏和最烦的广告，尽量少写规则。

### 查到的数据

用 `tools/fetch-yfamilys.sh` 把站点 454 个模块 + 2 个配置镜像到 `reference/yfamilys/`，统计几个融合模块：

| 模块 | URL Rewrite | Script | Body Rewrite | MITM 主机数 |
|---|---|---|---|---|
| adlite 轻量版 | 453 | 27 | 2 | 448 |
| startingad 融合版 | 570 | 168 | 3 | 539（48 个通配 `*.`）|
| adultra | 894 | 167 | 3 | 709（含 `gw.alicdn.com`、`heic.alicdn.com`）|
| adultraplus | 2187 | 373 | 35 | 1273 |

### 想法因此修正：开销排序

Shadowrocket 闭源，以下是基于机制的推断，不是官方文档。

1. **MITM 主机数（最大头）**：列进 MITM 的主机，所有 HTTPS 流量都要在手机上解密再加密，还要为每个主机签证书，HTTP/2 和 QUIC 优化也会失效。融合版对 500~1300 个主机做这件事，其中 `gw.alicdn.com` 是淘宝全部商品图，`*.iqiyi.com` 含视频流。这是持续的 CPU 消耗。
2. **Script / Body Rewrite**：要缓冲整个响应体，再跑 JavaScriptCore 或 jq，每次命中都很贵。远程脚本还要定期下载。
3. **URL Rewrite 正则条数**：以 `^https?://具体主机` 开头的正则在前几个字符就会失配，几百条也是微秒级。真正慢的是 `.*`、`[a-z]+\.` 这类开头不固定的写法。
4. **`[Rule]` 里的 DOMAIN / DOMAIN-SUFFIX / DOMAIN-SET**：哈希或后缀树查找，几乎与条数无关。DOMAIN-KEYWORD、URL-REGEX、PROCESS 等仍是逐条线性匹配。

所以"条数多"本身不是主要问题。耗电主要来自 **MITM 范围大 + 脚本多**，假设的方向对，但重点要移到 MITM 上。

### 规则选择的原则（初稿）

按代价从低到高，能用低一级就不用高一级：
1. **整个主机只发广告** → `[Rule]` 里 `DOMAIN,host,REJECT`，放在 `direct.txt` 之前。无 MITM。
2. **广告接口和正常内容同一主机** → `[URL Rewrite]` 精确到接口路径的 `reject` / `reject-dict`，并且只对这一个主机开 MITM，不用 `*.` 通配。
3. **只能改响应体才能去掉** → 尽量放弃；确实很烦再考虑，单独记账。
4. 每个 App 的 MITM 主机控制在 1~2 个，总数心里有数。

### 怎么从一堆淘宝相关行里找到"那一条"

关键认识：
- **`acs.m.taobao.com` / `guide-acs.m.taobao.com` 是阿里系共用的 MTOP 网关**，大麦、飞猪、淘票票、盒马、一淘、菜鸟、闲鱼都走它。grep "taobao" 命中的大多是别的 App 的规则。
- **接口名前缀才说明归属**：`mtop.taobao.wireless.home.*` 是淘宝首页；`mtop.taobao.idle.*` 是闲鱼（不是淘宝）；`mtop.damai` 是大麦，`mtop.fliggy` 是飞猪，`mtop.film` 是淘票票，`mtop.wdk` 是盒马，`mtop.etao` / `mtop.alimama.etao` 是一淘，`mtop.cainiao` 是菜鸟。
- 阿里系 App 默认走私有长连接协议（ACCS/SPDY），由 AMDC（`amdc.m.taobao.com/amdc/mobileDispatch`，明文 HTTP）调度。融合版里墨鱼的 `amdc.js` 会把调度响应搞坏，迫使 App 退回普通 HTTPS，MITM 规则才能看到请求。脚本只对 UA 含 AMap、Cainiao、闲鱼、飞猪、天猫、大麦等的请求生效，名单里没有淘宝本身。

方法（三步）：
1. **本地检索**：`bash tools/find-rules.sh '<主机或接口前缀>' [--splash]`。它会去重，按代价分组（Rule → Rewrite → Body → Script → MITM 主机），并标出来源模块。先按接口前缀筛出属于目标 App 的行。
2. **挑最小集合**：优先选能用 DOMAIN 拒绝的；否则选接口名带 splash/startup/launch/welcome 的那一条 Rewrite，只对它的主机开 MITM。
3. **手机上实测**：开 Shadowrocket 的请求记录，冷启动 App，看开屏期间实际请求了哪些 URL。规则生效后，记录里该请求应显示被拒绝。开屏素材常有本地缓存，生效后可能还要再出现一两次。

### 淘宝开屏的候选

- 主规则：`^https?:\/\/guide-acs\.m\.taobao\.com\/gw\/mtop\.taobao\.wireless\.home\.splash\.awesome\.get reject-dict`
  - adlite、startingad、adultra、adultraplus 四个融合版都有，最稳定。
- MITM：只需 `guide-acs.m.taobao.com` 一个。
- 可选：`mtop.taobao.(volvo.secondfloor.getconfig|wireless.home.newface.awesome.get)`，首页"二楼"和新版首页运营位，只有 adultraplus 有。
- 不采纳：`gw.alicdn.com/imgextra/...` 按图片尺寸拦截的规则（需要解密全部商品图）；`myBlockAds.js` 脚本版。

## 未解决的问题

- **MITM 证书在配置远程更新后是否保留**：CA 存在配置文件 `[MITM]` 的 ca-p12 里，没查到可靠说法，需要在手机上验证一次。这决定 MITM 规则放主配置还是单独模块。
- **淘宝的 guide-acs 请求是否走 HTTPS**：如果走私有协议，MITM 看不到，需要额外处理 AMDC。需要实测。
- **Shadowrocket 内部匹配实现**：以上开销排序是推断，没有官方依据。
- **模块自动更新**：据 GMOogway 文档，2025-12 起新版小火箭支持自动更新模块；手动入口是"配置 → 模块 → 更新模块"。

## 来源

- [yfamilys 小火箭模块站](https://yfamilys.com/shadowrocket)（本地镜像见 `reference/yfamilys/`）
- [fmz200/wool_scripts](https://github.com/fmz200/wool_scripts)：彩云 activity 规则、淘宝域名清单
- [blackmatrix7/ios_rule_script Advertising](https://github.com/blackmatrix7/ios_rule_script)：`cdn-1rtb.caiyunapp.com`
- [ddgksf2013 amdc.js](https://github.com/ddgksf2013/Scripts)：AMDC 降级机制
- [GMOogway/shadowrocket-rules 模块更新说明](https://github.com/GMOogway/shadowrocket-rules/blob/master/docs/02.shadowrocket_update_modules.md)
- [Surge 手册 MITM](https://manual.nssurge.com/http/mitm.html)：MITM / CA 机制对照
