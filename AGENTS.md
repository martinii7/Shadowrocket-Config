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

- 节点不写进配置，来自机场订阅。`[Proxy Group]` 按节点名正则筛选：`节点选择` 只含日本/新加坡/美国，`币安` 只含日本/新加坡（币安封美国 IP）。规则里用组名，不再用 `PROXY`。
  - `policy-regex-filter` 放在参数最后，正则里不能有逗号；英文代号用 `(?<![A-Za-z])US(?![A-Za-z])` 这种写法，避免误中 RUS/AUS/Russia。
  - 首页选中的节点仍用于 `dns-server` 的 `#proxy` 查询，也要选在这三个地区。
- 币安规则（关键字 `binance` + 几个非 binance 字样的 API/CDN 后缀，取自 v2fly `geosite:binance`）必须在 `direct.txt` 之前，因为 direct.txt 含 `binancezh.*`。
- 去广告规则放在 `[Rule]` 的"单个 App 去广告补充"段，**必须在 Loyalsoldier `direct.txt` 之前**，否则会被主域名直连放行。
- 优先用 DOMAIN 级 REJECT（无 MITM）；需要 MITM 时只开精确主机，不用通配，不引入脚本。
- 不收录破解付费功能（伪造会员）的脚本。
