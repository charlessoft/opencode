# OpenCode 工程导览

这是一份面向新同学的快速导览，目标是回答三个问题：

1. 这个仓库整体是做什么的
2. 主要代码分别在哪些包里
3. 如果要继续深入，应该从哪里开始读

## 一句话理解

这是一个基于 Bun 和 Turbo 的 monorepo，核心不是单一 CLI，而是一个 AI coding engine，加上多个客户端和一套云端控制台能力。

从结构上看，它更像：

- 一个核心引擎：负责 session、tool、provider、权限、同步、终端、插件等能力
- 多个客户端：CLI、Web、Desktop、TUI
- 一套平台能力：SDK、控制台、云函数、部署配置

## 仓库顶层结构

根目录下比较重要的目录有：

- `packages`：主要业务代码都在这里
- `docs`：项目文档
- `infra`：基础设施和部署相关定义
- `sdks`：一些 SDK 相关内容
- `script`：仓库级脚本

根目录脚本说明了几个常见开发入口：

- `bun run dev`：默认跑 `packages/opencode`
- `bun run dev:web`：跑 `packages/app`
- `bun run dev:desktop`：跑 `packages/desktop`
- `bun run dev:console`：跑 `packages/console/app`

另外，这个仓库明确禁止在根目录直接跑测试，测试和类型检查要按包执行。

## 核心包分工

### `packages/opencode`

这是整个工程最核心的包，可以把它理解成运行时引擎和服务层。

它负责的内容包括：

- CLI 命令入口
- 本地 server
- session 生命周期
- provider 和 model 选择
- tool 调度
- 权限系统
- MCP / ACP 支持
- 插件、LSP、终端、同步、存储

最值得优先读的文件：

- `packages/opencode/src/index.ts`
- `packages/opencode/src/cli/cmd/run.ts`
- `packages/opencode/src/server/server.ts`

### `packages/app`

这是主 Web 客户端，不是官网。它会连接 opencode server，并提供实际的会话界面、目录页、session 页、全局状态管理等。

关键文件：

- `packages/app/src/entry.tsx`
- `packages/app/src/app.tsx`

### `packages/desktop`

这是 Electron 桌面端，整体上更像是给 `packages/app` 套了一层桌面壳，并补充桌面平台能力。

### `packages/ui`

共享 UI 组件、主题、样式、上下文封装，供 `app`、`desktop`、`console` 这些前端包复用。

### `packages/core`

通用基础能力包，放跨包共享的底层逻辑，比如：

- 日志
- 安装信息
- 全局路径
- effect 相关封装
- 一些工具函数

### `packages/sdk/js`

JavaScript SDK。给外部程序或仓库内部其他模块调用 opencode server 能力用。

入口比较薄，核心是把 client/server 包装成统一使用方式。

### `packages/web`

这是官网 / 文档站相关内容，基于 Astro 和 Starlight。它不是主业务前端。

### `packages/console/*`

这是云控制台和后台相关的代码，职责偏平台和运营，包括：

- console 前端
- console core
- resource
- mail
- function

### `packages/function`

云端函数相关代码，主要服务于平台侧能力。

### `packages/llm`

模型协议和 provider 适配层。这里处理不同模型厂商和不同 API 协议之间的抽象。

## 主调用链怎么理解

可以先把系统看成这样一条链路：

1. 用户从 CLI、Web 或 Desktop 发起请求
2. 客户端最终调用 `packages/opencode` 暴露的 server / session 能力
3. session 层组织 prompt、message、tool、状态更新
4. provider 层把请求路由到具体模型厂商
5. 事件和状态通过同步系统、Bus、数据库落盘并广播
6. UI 再把这些状态渲染出来

## `packages/opencode` 内部值得关注的目录

如果你继续往下读，这几个目录很关键：

- `src/cli`：CLI 命令定义
- `src/server`：HTTP API、事件、路由、server 生命周期
- `src/session`：会话状态、prompt、message、summary、retry、revert
- `src/provider`：模型提供商接入和转换
- `src/tool`：工具定义和运行时
- `src/permission`：权限控制
- `src/storage`：本地存储和数据库
- `src/sync`：同步和事件溯源机制
- `src/mcp`：MCP 支持
- `src/acp`：ACP 支持
- `src/plugin`：插件系统
- `src/lsp`：LSP 相关能力
- `src/pty` / `src/shell`：终端和 shell 执行

## 几个关键入口的作用

### CLI 入口

`packages/opencode/src/index.ts` 是主 CLI 入口。这里用 `yargs` 注册了大量子命令，例如：

- `run`
- `serve`
- `mcp`
- `acp`
- `session`
- `agent`
- `providers`

它还会在启动时做一些全局初始化，比如日志、环境变量和数据库迁移。

### `run` 命令

`packages/opencode/src/cli/cmd/run.ts` 是最关键的一条使用路径。

它支持几种模式：

- 非交互模式
- 本地交互模式
- attach 到远程 server 的交互模式

也就是说，`opencode run` 并不只是“直接跑一个 prompt”，它本身就是连接会话系统、server 和 UI runtime 的主入口之一。

### server

`packages/opencode/src/server/server.ts` 负责创建和监听 HTTP API server。

这个文件可以看出几个重要事实：

- 系统存在明确的服务端抽象
- server 支持独立监听端口
- 会初始化 projectors
- 会暴露 OpenAPI
- WebSocket 和生命周期管理也是 server 的职责之一

这也说明整个项目并不是“一个单进程 CLI 应用”，而是明显朝着客户端/服务端架构设计的。

## 前端侧怎么接入引擎

### `packages/app/src/entry.tsx`

这个入口主要做几件事：

- 判断默认 server 地址
- 处理认证 token
- 注入平台能力
- 渲染 `AppInterface`

从这里可以看出，Web 前端本质上是一个连接 opencode server 的客户端。

### `packages/app/src/app.tsx`

这里更像主界面装配层，负责：

- 全局 provider
- 路由
- 健康检查
- session 页面上下文
- SDK 和同步能力注入

可以把它理解成 Web 客户端的主壳。

## 同步系统的设计重点

`packages/opencode/src/sync/README.md` 很值得读。

这里描述了一套“单写者”的事件溯源同步方案，核心目标是：

- 允许一个设备写入
- 允许多个设备同步和回放 session 数据
- 尽量兼容现有 `Bus` 事件系统

这块设计说明了为什么项目里既有传统事件总线，也有更偏 event sourcing 的抽象。

如果你后面要看：

- 多端同步
- session 回放
- 数据投影
- 历史重建

这一块会非常重要。

## ACP / MCP / 插件

这个项目不是只做“发 prompt 给模型”，而是在认真构建 agent runtime。

从目录上就能看出来它已经把这些能力独立成模块：

- `src/mcp`
- `src/acp`
- `src/plugin`
- `src/tool`
- `src/permission`

其中 `src/acp/README.md` 已经把 ACP 实现的职责拆得很清楚，包括：

- agent 接口实现
- client 能力实现
- session 映射
- server 生命周期

这部分对理解“OpenCode 想和外部 agent 生态怎么接轨”很有帮助。

## 云端和部署层

如果你关心平台侧能力，可以继续看：

- `packages/console/*`
- `packages/function`
- `sst.config.ts`
- `infra/*`

`sst.config.ts` 说明这个仓库有一套基于 SST 的云端部署能力，并且目标平台是 Cloudflare。

这意味着仓库不仅有本地 agent/runtime，也有一整套线上控制台、资源和平台配置能力。

## 容易误判的几个点

### `packages/web` 不是主 Web 客户端

主业务 Web 客户端是 `packages/app`。

### 这不是纯 CLI 工具

虽然入口很强 CLI 导向，但本质上已经是客户端/服务端架构。

### `opencode run` 不一定依赖外部远程服务

它既可以 attach 到已有 server，也可以走本地 in-process server。

### 仓库已经有明显的平台化倾向

不仅有本地运行时，还有 SDK、控制台、云函数、部署配置和协议层扩展。

## 建议的阅读顺序

如果目标是快速建立全局认知，建议这样读：

1. `package.json`
2. `packages/opencode/src/index.ts`
3. `packages/opencode/src/cli/cmd/run.ts`
4. `packages/opencode/src/server/server.ts`
5. `packages/opencode/src/session`
6. `packages/opencode/src/provider`
7. `packages/app/src/entry.tsx`
8. `packages/app/src/app.tsx`
9. `packages/opencode/src/sync/README.md`
10. `packages/opencode/src/acp/README.md`

如果目标是直接准备改功能，我建议优先顺着你要改的入口走，而不是一口气读完整个仓库。

## 适合继续深挖的方向

读完这份导览后，通常会分成几条继续深入的路径：

- CLI 请求是怎么进入 session 和 tool runtime 的
- provider 是怎么做多模型适配的
- sync 事件是怎么落库和回放的
- Web 客户端怎么订阅和展示 server 状态
- ACP / MCP / plugin 是怎么接进主流程的

如果后面需要，我可以继续补一篇更细的文档，例如：

- `opencode-run-request-flow.md`
- `opencode-session-and-sync.md`
- `opencode-packages-map.md`
