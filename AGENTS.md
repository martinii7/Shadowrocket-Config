# Shadowrocket-Config

个人 Shadowrocket（小火箭）配置。手机通过 `update-url` 直接订阅本仓库 GitHub 上的 raw 文件，推送即生效。

**当前阶段：探索**：研究如何以最低性能开销，只去掉日常几个 App 的开屏和最烦的广告。见 `docs/EXPLORE.md`。

## 文件

| 路径 | 作用 |
|---|---|
| `Shadowrocket-Config.conf` | 唯一在用的配置：策略组手动选节点（仅日本/新加坡/美国）、币安单独分流、国内直连/国外代理、防 DNS/WebRTC 泄露、广告规则。手机订阅它。 |
| `default.conf` | 小火箭导出的默认配置，仅作参考，未纳入 git。 |
| `tools/fetch-yfamilys.sh` | 把 yfamilys.com 上全部模块和配置镜像到 `reference/yfamilys/`，可重复运行刷新。 |
| `tools/find-rules.sh` | 在镜像里按主机名/接口名检索规则，去重后按代价分组（Rule → Rewrite → Body → Script → MITM）。 |
| `reference/yfamilys/` | 第三方模块原文镜像，`INDEX.tsv` 是文件名到中文名的对照。已 gitignore，本地用。 |
| `docs/EXPLORE.md` | 探索过程与结论。 |

## 约定

- 配置文件分为 `[General]` / `[Proxy Group]` / `[Rule]` 三段，段内用 `# ---------- 标题 ----------` 分块。`[Rule]` 依次为：私有地址 → 去广告 → 指定节点分流 → 国内直连/国外代理。
- 策略组、策略名一律用英文，注释用中文。
- 节点不写进配置，来自机场订阅。手机上有三个机场订阅，只用主力机场。
  - 策略组用"订阅筛选"写法 `NODE = select,Main,use=true,...`，只取备注为 `Main` 的订阅（首页 → 订阅 ⓘ → 备注），再按节点名正则筛地区：`NODE` 是日本/新加坡/美国，`Binance` 是日本/新加坡（币安封美国 IP）。规则里用组名。换主力机场只需改订阅备注，配置不动。需小火箭 2.2.91 (3405)+。
  - **订阅链接不能写进配置**：仓库公开（手机靠 raw 链接匿名拉取），订阅链接含令牌，泄露后别人可以用你的流量。小火箭也没有 Clash 那种 proxy-provider，订阅只能在 App 里添加。
  - 组名不能叫 `PROXY`：它是小火箭内置策略，指首页选中的节点（LOWERTOP 官方文档说明内置策略为 `proxy`，大小写不敏感）。
  - `policy-regex-filter` 放在参数最后，正则里不能有逗号；英文代号用 `(?<![A-Za-z])US(?![A-Za-z])` 这种写法，避免误中 RUS/AUS/Russia。
  - 走代理的流量用的是 `NODE` 组里选的节点，不是首页选中的节点。DNS 用 `#proxy=NODE` 也绑到 `NODE`。官方文档只举了节点名的例子，组名是否生效未确认；名字无效时会回退到首页节点。改组名或新建组后，组内选择会重置为列表第一个节点，要到"代理分组"里重新选。
  - 踩过的坑（2026-11-11）：改用 `NODE` 后，手机 YouTube 加载要 5 秒以上。原因是 `NODE` 按地区正则匹配了全部三个机场的节点，默认选到了非主力机场的节点，而首页选的是主力节点。这次改为只取 `Main` 订阅的节点。
- 币安规则（关键字 `binance` + 几个非 binance 字样的 API/CDN 后缀，取自 v2fly `geosite:binance`）必须在 `direct.txt` 之前，因为 direct.txt 含 `binancezh.*`。
- 去广告规则放在 `[Rule]` 的"单个 App 去广告补充"段，**必须在 Loyalsoldier `direct.txt` 之前**，否则会被主域名直连放行。
- 优先用 DOMAIN 级 REJECT（无 MITM）；需要 MITM 时只开精确主机，不用通配，不引入脚本。
- 不收录破解付费功能（伪造会员）的脚本。
