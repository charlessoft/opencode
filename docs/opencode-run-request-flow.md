# OpenCode `run` 请求链路

这篇文档聚焦一条最核心的使用路径：`opencode run`。

目标不是逐行解释代码，而是把一次请求从 CLI 入口、到 server、到 session、再到事件回流客户端的主链路讲清楚。

## 先给结论

`opencode run` 看起来像一个单独的命令行入口，但它背后并不是“把 prompt 直接扔给模型”这么简单。

它本质上走的是这样一条链路：

1. CLI 解析参数并初始化运行环境
2. 根据模式选择本地 in-process server、远程 attach server，或交互式 runtime
3. 通过 SDK 调用 session API
4. server 把请求交给 `SessionPrompt`
5. `SessionPrompt` 调用 provider、tool、permission、session、sync 等能力
6. 执行过程中持续发布事件
7. CLI 或 Web 客户端通过 `/event` 或 `/global/event` 订阅事件并刷新界面

这也是为什么这个仓库虽然 CLI 味道很重，但本质上已经是客户端/服务端架构。

## 1. 入口在 `packages/opencode/src/index.ts`

主 CLI 入口是：

- `packages/opencode/src/index.ts`

这里做了几件关键事：

- 初始化日志
- 设置进程级环境变量
- 检查并执行数据库迁移
- 注册所有 CLI 子命令

`run` 是其中最核心的一个命令，和它并列的还有 `serve`、`mcp`、`acp`、`session` 等。

这说明 `run` 只是整个运行时系统的一种使用方式，不是唯一入口。

## 2. `run` 命令负责分发运行模式

关键文件：

- `packages/opencode/src/cli/cmd/run.ts`

这个命令支持几种主要模式：

### 非交互模式

直接发送一次 prompt，订阅事件流，等 session 回到 idle 状态后退出。

### 本地交互模式

通过 `runInteractiveLocalMode` 启动本地交互运行时，不走外部 HTTP server，而是直接把请求打到 in-process server。

### attach 模式

通过 `--attach` 连接一个已经启动的 opencode server，然后把请求发给远端。

### 本地 HTTP SDK 模式

如果不是 attach，也不是本地交互模式，`run.ts` 会创建一个带自定义 `fetch` 的 SDK。这个 `fetch` 最终会直接调用：

- `Server.Default().app.fetch(request)`

也就是说，即使没有独立启动一个监听端口的 server，内部仍然是按 HTTP API 语义在走。

## 3. `run` 不是直接调模型，而是先调 SDK

在 `run.ts` 里，真正执行时会先创建 client，然后做这些事情：

- 创建或恢复 session
- 订阅事件流
- 调 `client.session.prompt(...)` 或 `client.session.command(...)`

这里很关键的一点是：CLI 自己并不直接进入模型调用，它先经过 SDK。

这使得 CLI、Web、Desktop 和其他程序都可以共用一套 session API。

## 4. SDK 负责把“目录上下文”带到请求里

相关文件：

- `packages/sdk/js/src/client.ts`

这个 SDK 做了一件很重要但容易忽略的事：它会把当前工作目录编码到请求里。

实现方式是：

- 优先在 header 里放 `x-opencode-directory`
- 对 `GET` / `HEAD` 请求再改写成 query 参数 `directory`

这说明 opencode 的很多请求不是全局无状态的，而是和“当前 workspace / directory”强绑定。

这也是为什么这个项目能支持：

- 本地目录上下文
- 远程 workspace
- 多项目切换

## 5. server 路由把请求交给 session handlers

当请求进入 server 之后，最关键的路由组之一是：

- `packages/opencode/src/server/routes/instance/httpapi/groups/session.ts`

这里定义了很多 session 相关 API，比如：

- `POST /session/:sessionID/message`
- `POST /session/:sessionID/prompt_async`
- `GET /session/:sessionID/message`
- `GET /session/status`

可以把它理解成“会话系统的 HTTP 外壳”。

具体处理逻辑在：

- `packages/opencode/src/server/routes/instance/httpapi/handlers/session.ts`

## 6. `prompt` 和 `prompt_async` 的区别

在 handler 里，`prompt` 和 `prompt_async` 都会进入：

- `SessionPrompt.Service`

但返回方式不同。

### `prompt`

`prompt` 会等待 `promptSvc.prompt(...)` 的结果，然后把消息结果以 streaming response 的形式返回。

更适合直接拿当前响应结果的调用方式。

### `prompt_async`

`prompt_async` 会把 `promptSvc.prompt(...)` fork 到后台执行，然后立刻返回 `204 No Content`。

如果后台执行失败，它会发布一条 `Session.Event.Error` 到总线里。

这也解释了为什么很多前端调试方式会组合使用：

- `POST /session/:id/prompt_async`
- `GET /global/event`

前者负责触发，后者负责观察。

## 7. 真正的业务核心在 `SessionPrompt`

关键文件：

- `packages/opencode/src/session/prompt.ts`

这是整个请求链里最重要的业务核心之一。

从依赖就能看出来它连接了非常多系统：

- `Session`
- `SessionStatus`
- `Provider`
- `LLM`
- `ToolRegistry`
- `Permission`
- `Plugin`
- `MCP`
- `LSP`
- `SyncEvent`
- `Bus`

也就是说，一次 `run` 请求最终会在这里汇聚成真正的 agent runtime。

## 8. `SessionPrompt` 在做什么

虽然这个文件很大，但从职责上可以简化理解成几件事：

### 组织输入

把用户输入、文件附件、agent 信息、模型信息整理成 prompt 输入结构。

### 解析命令和模板

如果是 slash command 或内建 command，会先展开模板，再决定实际交给哪个 agent 和 model。

### 准备工具和上下文

在执行 prompt 前，把 tool、permission、plugin、MCP、LSP 等能力准备好。

### 调用模型

通过 provider / LLM 层把请求发到具体模型提供商。

### 更新 session 和消息

把 prompt、assistant 回复、tool 调用状态等内容写回 session。

### 发布状态和事件

通过 `Bus`、`SyncEvent`、`SessionStatus` 这些机制把变化广播出去。

## 9. 客户端如何知道执行进度

事件订阅的关键实现位于：

- `packages/opencode/src/server/routes/instance/httpapi/event.ts`

这里会从 `Bus.subscribeAll()` 拉取全量事件流，然后以 SSE 的形式输出。

几个关键点：

- server 建立连接时先发 `server.connected`
- 运行过程中会持续转发业务事件
- 每隔一段时间会发 `server.heartbeat`
- 连接断开时会停止流

在公开路由层里，`/event` 和 `/global/event` 都会被识别为事件流入口。

## 10. `run` 命令主要消费哪些事件

在 `run.ts` 里，事件循环最关注这些事件：

- `message.part.updated`
- `session.status`
- `session.error`
- `permission.asked`

它们分别承担这些职责：

### `message.part.updated`

用于接收文本输出、reasoning、tool 执行结果等增量状态。

### `session.status`

用于判断 session 是否回到 `idle`。非交互模式通常就是等到这个信号再退出。

### `session.error`

用于把后台错误反馈给当前调用方。

### `permission.asked`

用于处理权限请求。在默认非交互模式下，如果没有显式放开权限，会自动拒绝。

## 11. 为什么 `run` 仍然是“服务化”的

虽然用户看到的是一条 CLI 命令，但从实现上看，它其实已经具备典型的服务化特征：

- 有明确的 session API
- 有 HTTP route 分组
- 有独立 server `listen`
- 有 SDK client/server 封装
- 有 SSE 事件流
- 有 workspace 路由和目录上下文
- 有同步和事件投影机制

所以更准确的理解方式应该是：

`opencode run` 是这个 runtime 的一个客户端入口，而不是整个系统本身。

## 12. 一次典型的非交互执行流程

可以把一次 `opencode run "帮我改这个文件"` 简化成下面这条时序：

1. CLI 启动并解析参数
2. 根据本地模式或 attach 模式创建 SDK
3. 创建或恢复 session
4. 订阅事件流
5. 调用 `client.session.prompt(...)`
6. server 路由把请求交给 `SessionPrompt.prompt(...)`
7. `SessionPrompt` 组织上下文、工具、provider 和模型调用
8. 过程中不断发布 `message.part.updated` 等事件
9. CLI 一边消费事件一边输出文本、tool 状态和权限提示
10. session 状态变为 `idle`
11. CLI 结束本次执行

## 13. 一次典型的异步 Web 调试流程

如果是浏览器端或手动调试页面，常见流程会变成：

1. 先连 `/global/event`
2. 创建 session
3. 调 `POST /session/:id/prompt_async`
4. 等待 SSE 返回 `message.part.updated`
5. 再调用 `/session/:id/message` 拉取完整消息

这也是 `docs/opencode-sse-test.md` 那个测试页在做的事情。

## 14. 看这条链路时最值得继续深挖的文件

如果你准备继续往下读，建议按这个顺序：

1. `packages/opencode/src/index.ts`
2. `packages/opencode/src/cli/cmd/run.ts`
3. `packages/sdk/js/src/client.ts`
4. `packages/opencode/src/server/routes/instance/httpapi/groups/session.ts`
5. `packages/opencode/src/server/routes/instance/httpapi/handlers/session.ts`
6. `packages/opencode/src/server/routes/instance/httpapi/event.ts`
7. `packages/opencode/src/session/prompt.ts`

## 15. 这条链路帮我们建立的几个认知

读完 `run` 这条主路径，通常会得到几个比较稳的判断：

- 这是一个 session 驱动的系统，不是单次 prompt 脚本
- CLI、Web、Desktop 都在复用同一套能力
- HTTP API 和事件流是内部统一边界
- `SessionPrompt` 是核心业务编排层
- `Bus`、`SyncEvent`、`SessionStatus` 一起承担状态传播
- 这个项目已经明显走向平台化 agent runtime，而不是简单命令行工具

如果后面需要，我还可以继续补更细的专题文档，比如：

- `SessionPrompt` 内部结构拆解
- `prompt_async + SSE` 调试手册
- session / message / sync 事件关系图
