# BIND 9 编译构建

基于 CentOS 7 / glibc 2.17 的 BIND 9 DNS 服务器构建工作流，确保编译产物可在老旧 Linux 系统上运行。

## 使用方法

在 GitHub Actions 中手动触发 `Build BIND` 工作流，输入 BIND 版本号即可：

1. 进入 Actions → Build BIND → Run workflow
2. 填写 `release_version`，例如 `9.18.48`
3. 按需勾选 `make_latest` / `prerelease`
4. 点击 Run workflow

构建完成后，产物和 Release 会自动生成。

## 构建环境

| 组件 | 版本/来源 |
|------|----------|
| 基础镜像 | `quay.io/pypa/manylinux2014` (CentOS 7) |
| 工具链 | devtoolset (GCC 9+) |
| glibc | 2.17 |
| OpenSSL | 1.0.2k |
| libuv | EPEL |
| protobuf / protobuf-c / fstrm | 源码编译（dnstap 支持） |

## 产物

```
bind-{version}-linux-glibc2.17-{arch}.tar.xz
bind-{version}-linux-glibc2.17-{arch}.tar.xz.sha256
```

解压后目录结构：

```
usr/local/bind/    -- BIND 可执行文件及库
etc/bind/          -- 配置文件
var/               -- 运行时数据目录
```

## 资源

- [BIND 9 文档](https://bind9.readthedocs.io/)
- [ISC 下载站](https://downloads.isc.org/isc/bind9/)
