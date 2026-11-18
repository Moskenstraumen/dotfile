# 实验记录索引

本文件是三机同步的飞书研究记录索引与写作规则（根目录：[Research](https://wvixbzgc0u7.feishu.cn/wiki/JUDDwn3a1iwiXSkp9LMcL9Ysned)），仅保存规范、分类入口、模板与任务文档链接，不承载实验结果或未来计划。

## Algo

- [飞书目录](https://wvixbzgc0u7.feishu.cn/wiki/E7Dcw1RpDisdnikydR6ceD1mnKd)
- [实验记录模版](https://wvixbzgc0u7.feishu.cn/wiki/LoOowLIQDiUbcZkfeYRcqg3knTb)
- [OPSD](https://wvixbzgc0u7.feishu.cn/wiki/U6erwT7hsiwpy4kXth5c2A7OnYf)
- [MOPD](https://wvixbzgc0u7.feishu.cn/wiki/FOOGwCrRdiyDn6ksF6tcWUHjnUf)
- [RL](https://wvixbzgc0u7.feishu.cn/wiki/K0PWwrhM4iwt8Bk5LuGcxS1Lnsc)

## Data

- [飞书目录](https://wvixbzgc0u7.feishu.cn/wiki/Q6ZNwYs72iOQuJk5i9NcnuhdnDh)
- [实验记录模版](https://wvixbzgc0u7.feishu.cn/wiki/SKp6ww49giVhCakxsrecTgfKn8b)

## Eval

- [飞书目录](https://wvixbzgc0u7.feishu.cn/wiki/Jj6mw9qxNibi54kYanLcAPhAnTh)
- [实验记录模版](https://wvixbzgc0u7.feishu.cn/wiki/OuE6wyQMCiAA3DkwJiecp4UvnAd)

## Infra

- [飞书目录](https://wvixbzgc0u7.feishu.cn/wiki/Tucxw8ApYiiTUskfSRZcRaATnDc)
- [实验记录模版](https://wvixbzgc0u7.feishu.cn/wiki/KKPgwZthuiPmDJkQjiEconW3n4f)
- [阿里云训练 -> Stepmind部署SOP](https://wvixbzgc0u7.feishu.cn/wiki/LWaLwIryXiLEDsknG3ncA6rcnib)

## 记录规则

- 调查结论、实验进度、上下文与结果统一记录在飞书文档，每份任务文档的链接必须维护在本文件的所属分类下；不得将文档报告或其草稿写入本地或远端主机磁盘（CLI 调用所需的瞬时临时载荷须在当次操作完成后立即删除，正常训练日志、数据与 checkpoint 不受此限），也不写入 AGENTS.md。
- 飞书读取与写入均显式使用 `--as bot`；权限失败时停止，不回退到其他身份。
- 先读取所属分类中标题严格为“实验记录模版”的模板；每个 task setting 仅维护一份任务文档，跨队列、跨日期复用，仅在枚举确认不存在时创建并回填本文件索引。
- 按实际执行证据核实实验日期，最新已核实日期在前；不得从 run 标签或文档修改时间推断，未知项明确标为“未知”。
- 每个实验条目包含 Motivation、Recipe、Conclusion、Training dynamics；只记录已发生的事实与调查证据，不写未来计划或建议，包含实际配置、结果、图表，并具体列明缺失的测量项。
- 代码字段填写对应实现或配置的 commit。无法核实的项明确标注。不描述提交前后的过程。
- 每份记录独立引用 run、job、代码、数据和 checkpoint 的一手证据，不引用旧实验报告；保留真实标识符，标题使用纯文本，不加装饰分隔符，正文避免斜杠列表，URL 与路径标识符保持原样。记录正文、表头和图注不使用‘原始’一词。
- 仅局部 patch 目标条目及直接摘要，不整篇覆盖；发布后用 `--as bot` 重新读取并核验已发布内容，维护本文件的规范索引链接。
