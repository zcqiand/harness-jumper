# ===== harness-jumper — Web 静态容器（agent 家族 web 段 5310；容器内 :80，host 双层）=====
# 多阶段：debian-slim Godot headless 导出 Web 产物 → nginx:alpine 静态服务。
# 纯前端应用：零后端、零 secret（成绩册全在浏览器 user:// 即浏览器侧存储），
# 无 /api/ 反代、无 env-file——家族 deploy 脚本的 web-only 变体（harness-2048/snake/maze 同款）。
# 与 maze（React）差异仅在构建段：node/vite 换 Godot headless --export-release "Web"。
ARG GODOT_VERSION=4.7-stable

# ---------- Stage 1: exporter（Godot headless 导出） ----------
FROM debian:bookworm-slim AS exporter
ARG GODOT_VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates wget unzip \
    && rm -rf /var/lib/apt/lists/*

# Godot 版本钉 version-lock.json（godot: 4.7-stable）；镜像层缓存住 editor+模板，
# 日常重构建只走 COPY . . 之后的导出层。
WORKDIR /godot

# 编辑器本体（linux x86_64 zip 内即一个可执行文件）
RUN wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" \
    && unzip -q "Godot_v${GODOT_VERSION}_linux.x86_64.zip" \
    && rm "Godot_v${GODOT_VERSION}_linux.x86_64.zip"

# 导出模板 tpz（全量 ~1GB）：只解包 templates/web_* 成员（unzip 指定成员通配），
# 落 Godot 约定路径 /root/.local/share/godot/export_templates/<版本目录>/。
# 目录名必须是编辑器自报版本形状（4.7-stable → 4.7.stable），否则导出报 no template。
RUN wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz" \
    && mkdir -p /tmp/tpz \
    && unzip -q -d /tmp/tpz "Godot_v${GODOT_VERSION}_export_templates.tpz" "templates/web_*" \
    && mkdir -p "/root/.local/share/godot/export_templates/$(echo ${GODOT_VERSION} | sed 's/-/./')" \
    && mv /tmp/tpz/templates/web_* "/root/.local/share/godot/export_templates/$(echo ${GODOT_VERSION} | sed 's/-/./')/" \
    && rm -rf /tmp/tpz "Godot_v${GODOT_VERSION}_export_templates.tpz"

# 项目导出：--export-release "Web" 与 export_presets.cfg 的 preset name 恰名对齐；
# headless 导出自带资源导入环节，产物 = index.html/js/wasm/pck + audio worklet 等一整套。
WORKDIR /project
COPY . .
# Godot 导出不自建目标目录（首航 44464379591 指纹：Target folder does not exist）——先 mkdir
RUN mkdir -p /project/build-web \
  && /godot/Godot_v${GODOT_VERSION}_linux.x86_64 --headless --path /project --export-release "Web" /project/build-web/index.html

# ---------- Stage 2: runtime ----------
FROM nginx:alpine AS runtime

# 容器 nginx.conf：静态服务 + Godot WASM 跨域隔离头（COOP/COEP，共享 ArrayBuffer 必需）
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=exporter /project/build-web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1

CMD ["nginx", "-g", "daemon off;"]
