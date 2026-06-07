#!/bin/bash
# 将 VLCKit dSYM 复制到 Archive 中，解决 App Store 上传缺少 dSYM 的问题
# dSYM 文件位于 Share/VLCKit/dSYMs/<platform>/

set -e

if [ "${ACTION}" != "install" ]; then
    echo "[VLCKit dSYM] 跳过：非 Archive 构建"
    exit 0
fi

echo "[VLCKit dSYM] Archive 构建，平台: ${PLATFORM_NAME}"

DSYM_SRC="${PROJECT_DIR}/../Share/VLCKit/dSYMs/${PLATFORM_NAME}/VLCKit.framework.dSYM"

if [ ! -d "${DSYM_SRC}" ]; then
    echo "[VLCKit dSYM] 错误: dSYM 未找到于 ${DSYM_SRC}"
    exit 1
fi

echo "[VLCKit dSYM] 源: ${DSYM_SRC}"
echo "[VLCKit dSYM] 目标: ${DWARF_DSYM_FOLDER_PATH}/"

cp -R "${DSYM_SRC}" "${DWARF_DSYM_FOLDER_PATH}/"

echo "[VLCKit dSYM] 复制成功"
