# Docs Index

这个目录放的是仓库级补充文档，重点偏本地调试、工程结构和请求链路理解。

## 文档列表

### [OpenCode 工程导览](./opencode-architecture-overview.md)

面向新同学的仓库总览，介绍：

- 仓库整体定位
- 核心包分工
- 主调用链
- 建议阅读顺序

### [OpenCode `run` 请求链路](./opencode-run-request-flow.md)

聚焦 `opencode run` 这条主路径，说明：

- CLI 是如何进入 session 流程的
- SDK 和 server 如何衔接
- `prompt_async` 和 SSE 事件如何配合
- 为什么这个系统本质上是客户端/服务端架构

### [OpenCode SSE Test](./opencode-sse-test.md)

本地 SSE 调试说明文档，配套页面：

- [opencode-sse-test.html](./opencode-sse-test.html)

适合用于手动验证：

- `/global/event`
- session 创建
- `prompt_async`
- 消息流和事件流

## 建议阅读顺序

如果你第一次接触这个仓库，建议按下面顺序看：

1. [OpenCode 工程导览](./opencode-architecture-overview.md)
2. [OpenCode `run` 请求链路](./opencode-run-request-flow.md)
3. [OpenCode SSE Test](./opencode-sse-test.md)



bun run --cwd packages/opencode src/index.ts serve --hostname 0.0.0.0 --port 4096


D:\workspace\foxit\opencode>bun run dev:web

http://localhost:3000/RDpcd29ya3NwYWNlXGZveGl0XGFpX3NraWxsc1xoZnRfZG9jdW1lbnQ/session