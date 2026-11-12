# Shadowrocket-Config

个人 Shadowrocket（小火箭）配置。手机通过 `update-url` 直接订阅本仓库 GitHub 上的 raw 文件，推送即生效。

**当前阶段：探索**：研究如何以最低性能开销，只去掉日常几个 App 的开屏和最烦的广告。见 `docs/EXPLORE.md`。

## 文件

| 路径 | 作用 |
|---|---|
| `Shadowrocket-Config.conf` | 唯一在用的配置：首页手动选节点、币安单独分流（主力机场日本/新加坡）、国内直连/国外代理、防 DNS/WebRTC 泄露、广告规则。手机订阅它。 |
| `default.conf` | 小火箭导出的默认配置，仅作参考，未纳入 git。 |
| `tools/fetch-yfamilys.sh` | 把 yfamilys.com 上全部模块和配置镜像到 `reference/yfamilys/`，可重复运行刷新。 |
| `tools/find-rules.sh` | 在镜像里按主机名/接口名检索规则，去重后按代价分组（Rule → Rewrite → Body → Script → MITM）。 |
| `reference/yfamilys/` | 第三方模块原文镜像，`INDEX.tsv` 是文件名到中文名的对照。已 gitignore，本地用。 |
| `docs/EXPLORE.md` | 探索过程与结论。 |

## 约定

- 配置文件分为 `[General]` / `[Proxy Group]` / `[Rule]` 三段，段内用 `# ---------- 标题 ----------` 分块。`[Rule]` 依次为：私有地址 → 去广告 → 指定节点分流 → 国内直连/国外代理。
- 策略组、策略名一律用英文，注释用中文。
- 节点不写进配置，来自机场订阅。手机上有三个机场订阅，只用主力机场。
  - **一般流量直接用内置策略 `PROXY`**（首页选中的节点），不设通用分组。用户习惯在首页点选节点，DNS 的 `#proxy` 也走这个节点。`PROXY` 是小火箭内置策略名（LOWERTOP 文档写作 `proxy`，大小写不敏感），不能用作组名。
  - **只有币安单独建组**：`Binance = select,Main,use=true,...` 是"订阅筛选"写法，只取备注为 `Main` 的订阅（首页 → 订阅 ⓘ → 备注），再按节点名正则筛出日本/新加坡（币安封美国 IP）。换主力机场只需改订阅备注，配置不动。需小火箭 2.2.91 (3405)+。组内的选择独立于首页，在"代理分组"里选一次即可；组改名或新建后会重置为第一个节点。
  - 首页节点列表想只显示主力机场的日本/新加坡/美国，在 App 里设置：其他订阅长按 → 隐藏；主力订阅 ⓘ → 过滤，填地区正则。这些是 App 本地设置，不在配置里。
  - **订阅链接不能写进配置**：仓库公开（手机靠 raw 链接匿名拉取），订阅链接含令牌，泄露后别人可以用你的流量。小火箭也没有 Clash 那种 proxy-provider，订阅只能在 App 里添加。
  - `policy-regex-filter` 放在参数最后，正则里不能有逗号；英文代号用 `(?<![A-Za-z])SG(?![A-Za-z])` 这种写法，避免误中其他单词。
  - 踩过的坑（2026-11-11）：曾设通用组 `NODE`（JP/SG/US 正则）承载全部代理流量，结果手机 YouTube 加载要 5 秒以上。原因是正则匹配了三个机场的节点，组内默认选到非主力机场的节点，而首页选的是主力节点，两处选择不一致。先改成只取 `Main` 订阅，再改成一般流量回到首页节点（`PROXY`），去掉 `NODE`，只保留 `Binance` 组。
- 币安规则（关键字 `binance` + 几个非 binance 字样的 API/CDN 后缀，取自 v2fly `geosite:binance`）必须在 `direct.txt` 之前，因为 direct.txt 含 `binancezh.*`。
- 去广告规则放在 `[Rule]` 的"单个 App 去广告补充"段，**必须在 Loyalsoldier `direct.txt` 之前**，否则会被主域名直连放行。
- 优先用 DOMAIN 级 REJECT（无 MITM）；需要 MITM 时只开精确主机，不用通配，不引入脚本。
- 不收录破解付费功能（伪造会员）的脚本。
