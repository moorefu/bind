# BIND 9 编译构建

在 CentOS 7 / glibc 2.17 环境下编译 BIND 9，产物可在老旧 Linux 系统上直接运行。

## 本地构建（推荐）

在 `manylinux2014` 容器中执行 `build-bind.sh`，无需手动配置环境：

```bash
# x86_64
docker run --rm \
  -v "$(pwd)":/workspace \
  -w /workspace \
  quay.io/pypa/manylinux2014_x86_64 \
  bash build-bind.sh 9.18.48

# aarch64
docker run --rm \
  -v "$(pwd)":/workspace \
  -w /workspace \
  quay.io/pypa/manylinux2014_aarch64 \
  bash build-bind.sh 9.18.48
```

构建完成后，当前目录生成：

```
bind-9.18.48-linux-glibc2.17-x86_64.tar.xz
bind-9.18.48-linux-glibc2.17-x86_64.tar.xz.sha256
```

重复构建时会命中缓存（`cache/` 目录），避免重复下载依赖源码。

## GitHub Actions

手动触发 `Build BIND` 工作流，输入版本号即可构建 x86_64 + aarch64 产物并发布 Release。

## 产物说明

产物为 `.tar.xz` 压缩包，解压后目录结构：

```
usr/local/bind/    -- 可执行文件（named, dig, rndc 等）及库
etc/bind/          -- 配置模板
```

### 部署

```bash
# 解压到目标机器
tar xJf bind-9.18.48-linux-glibc2.17-x86_64.tar.xz -C /

# 创建运行目录
mkdir -p /var/named /var/run/named

# 验证
/usr/local/bind/sbin/named -V
```

### 兼容性

| 要求 | 详情 |
|------|------|
| glibc | >= 2.17 |
| 架构 | x86_64 / aarch64 |
| 内核 | Linux 3.10+ |

无需安装额外运行依赖（OpenSSL、protobuf 等已静态链接或内置于 `/usr/local/bind/lib`）。

## 构建环境

| 组件 | 来源 |
|------|------|
| 基础镜像 | `quay.io/pypa/manylinux2014` (CentOS 7, glibc 2.17) |
| 工具链 | devtoolset-10 (GCC 10) |
| OpenSSL | 1.1.1w（源码编译） |
| protobuf / protobuf-c / fstrm | 源码编译（`--enable-dnstap`） |
| libuv / libcap / libxml2 / json-c | EPEL |

## 特性

- **DNSSEC** — Ed25519 / Ed448 签名算法（OpenSSL 1.1.1w 提供）
- **dnstap** — DNS 流量捕获（fstrm + protobuf-c）
- **DNS over HTTPS** — 禁用（CentOS 7 缺 nghttp2）

## 资源

- [BIND 9 文档](https://bind9.readthedocs.io/)
- [ISC 下载站](https://downloads.isc.org/isc/bind9/)
